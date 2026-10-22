#!/usr/bin/env node
// pr-watch — wait for CI on one PR's head commit to finish, then exit with the
// verdict of `asst-pr checks`. `asst-pr watch` is the entry point; start it with
// run_in_background: true, and its exit wakes the session.
//
// One watcher per PR, any number of PRs at once. GitHub allows one
// `gh webhook forward` per repo and event set (a second one gets HTTP 422 "Hook
// already exists"), so the watchers of one repo share it: the first to start
// becomes the leader, runs the forwarder and appends each event's commit to
// events.jsonl; the others read that file. When the leader's PR finishes, it
// stops the forwarder and another watcher takes over. Each watcher reads CI once
// when its forwarder connects or a new leader does, so nothing that finished in
// between is missed.
//
// State lives in ${XDG_CACHE_HOME:-~/.cache}/asst-pr/<owner>__<repo>/:
// leader.pid · watch-<pr>.pid · events.jsonl.
//
// Usage: node pr-watch.mjs <owner/repo> <pr> <head-sha> <timeout-minutes> <check command…>
// Exit: the check command's own 0 passed · 1 failed · 2 unreadable · 3 still
// running at the timeout; also 2 when the PR is already watched or the forwarder
// can't start.

import { spawn, spawnSync } from 'node:child_process';
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, statSync, unlinkSync, watch, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const [repo, pr, sha, timeoutMin, ...check] = process.argv.slice(2);
if (!repo || !/^\d+$/.test(pr ?? '') || !sha || !(Number(timeoutMin) > 0) || !check.length) {
  console.error('Usage: pr-watch.mjs <owner/repo> <pr> <head-sha> <timeout-minutes> <check command…>');
  process.exit(2);
}
const dir = join(process.env.XDG_CACHE_HOME || join(homedir(), '.cache'), 'asst-pr', repo.replace('/', '__'));
mkdirSync(dir, { recursive: true });
const leaderFile = join(dir, 'leader.pid');
const mineFile = join(dir, `watch-${pr}.pid`);
const eventsFile = join(dir, 'events.jsonl');

const alive = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
const owner = (f) => { try { return Number(readFileSync(f, 'utf8')); } catch { return 0; } };
// Exclusive create; a file left by a dead process is taken over once.
function claim(f) {
  for (let i = 0; i < 2; i++) {
    try { writeFileSync(f, String(process.pid), { flag: 'wx' }); return true; } catch (e) { if (e.code !== 'EEXIST') throw e; }
    const pid = owner(f);
    if (pid && alive(pid)) return false;
    try { unlinkSync(f); } catch {}
  }
  return false;
}

if (!claim(mineFile)) {
  console.error(`asst-pr: #${pr} is already watched (pid ${owner(mineFile)}) — one watcher per PR`);
  process.exit(2);
}

let fwd = null;
let done = false;
async function finish(code, out = '') {
  if (done) return;
  done = true;
  if (out) process.stdout.write(out);
  if (fwd) {
    // Wait for the forwarder to delete its hook before handing over, or the next leader gets 422.
    const gone = new Promise((r) => fwd.once('exit', r));
    try { process.kill(-fwd.pid, 'SIGTERM'); } catch {}
    await Promise.race([gone, new Promise((r) => setTimeout(r, 5000))]);
  }
  if (owner(leaderFile) === process.pid) try { unlinkSync(leaderFile); } catch {}
  try { unlinkSync(mineFile); } catch {}
  process.exit(code);
}
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => finish(130));

// One look at CI. 3 = still running; anything else ends the watch.
function look() {
  if (done) return 0;
  const r = spawnSync(check[0], check.slice(1), { encoding: 'utf8' });
  if (r.status !== 3) finish(r.status ?? 2, (r.stdout || '') + (r.stderr || ''));
  return r.status;
}
// GitHub sends a suite's completed event before its API shows it (measured: the
// event a second after the suite finished, and the read still said running),
// and no later event comes for that commit. So a read that still says running
// after an event is repeated a few times.
const LAGS = [2000, 10000, 30000];
let again;
function onEvent() {
  clearTimeout(again);
  let i = 0;
  const go = () => { if (look() === 3 && i < LAGS.length) again = setTimeout(go, LAGS[i++]); };
  go();
}

const note = (ev) => appendFileSync(eventsFile, JSON.stringify(ev) + '\n');

function lead() {
  fwd = spawn('gh', ['webhook', 'forward', '--events=check_suite,status', `--repo=${repo}`], {
    detached: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let err = '';
  fwd.stderr.on('data', (d) => {
    const was = /^Forwarding/m.test(err);
    err += d;
    if (!was && /^Forwarding/m.test(err)) { note({ connected: process.pid }); look(); }
  });
  createInterface({ input: fwd.stdout }).on('line', (line) => {
    let ev; try { ev = JSON.parse(line); } catch { return; }
    const at = ev.check_suite?.head_sha || ev.sha;
    if (!at) return;
    note({ sha: at });
    if (at === sha) onEvent();
  });
  fwd.on('exit', () => {
    fwd = null;
    if (done) return;
    const why = /Hook already exists/.test(err)
      ? `a webhook forwarder for check_suite,status already exists on ${repo} that no watcher here owns — another machine, or one a killed forwarder left behind (gh api repos/${repo}/hooks lists it)`
      : err.trim().split('\n').slice(-2).join(' ') || 'it exited';
    finish(2, `asst-pr: CI watch stopped — webhook forwarder failed: ${why}\n`);
  });
}

// Become leader if nobody is; otherwise follow events.jsonl and take over when the leader goes.
function tryLead() { if (!done && !fwd && claim(leaderFile)) lead(); }

if (!existsSync(eventsFile)) writeFileSync(eventsFile, '');
let offset = statSync(eventsFile).size;
function readNew() {
  let size; try { size = statSync(eventsFile).size; } catch { return; }
  if (size < offset) offset = 0;
  if (size === offset) return;
  const buf = Buffer.alloc(size - offset);
  const fd = openSync(eventsFile, 'r'); readSync(fd, buf, 0, buf.length, offset); closeSync(fd);
  offset = size;
  if (fwd) return; // the leader handles its own events as they arrive
  for (const line of buf.toString('utf8').split('\n')) {
    let ev; try { ev = JSON.parse(line); } catch { continue; }
    if (ev.connected || ev.sha === sha) { onEvent(); return; }
  }
}
watch(dir, () => { readNew(); if (!existsSync(leaderFile)) tryLead(); });
// A leader killed outright leaves its file behind and fires no event: check it now and then.
setInterval(() => { if (!fwd && !alive(owner(leaderFile))) tryLead(); }, 15000);

tryLead();
if (!fwd) look(); // a follower's leader is already connected: read CI once now
setTimeout(() => finish(3, `asst-pr: CI still running on #${pr} after ${timeoutMin} min — watch again, or check the run\n`), Number(timeoutMin) * 60000);
