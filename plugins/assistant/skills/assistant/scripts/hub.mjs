// hub — share one `gh webhook forward` among every process on this machine that
// waits on the same repo and event set. GitHub allows one forwarder per repo and
// event set (measured: a second gets HTTP 422 "Hook already exists"), so the first
// member to join becomes the leader: it runs the forwarder and appends each event,
// reduced by `pick`, to events.jsonl; the others read that file. When the leader
// stops, another member takes over. onConnected fires when a forwarder connects —
// the member's own or a new leader's — and once when a member joins a hub that
// already has a leader, so a member that reads state then misses nothing that
// happened before it was listening.
//
// Used by pr-watch.mjs (asst-pr watch) and this repo's after-merge.mjs.
// State: ${XDG_CACHE_HOME:-~/.cache}/gh-webhook-hub/<owner>__<repo>/<events>/
// (leader.pid · events.jsonl); repoDir(repo) is its parent, for callers' own locks.

import { spawn } from 'node:child_process';
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, statSync, unlinkSync, watch, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

export const repoDir = (repo) => {
  const d = join(process.env.XDG_CACHE_HOME || join(homedir(), '.cache'), 'gh-webhook-hub', repo.replace('/', '__'));
  mkdirSync(d, { recursive: true });
  return d;
};
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
export const owner = (f) => { try { return Number(readFileSync(f, 'utf8')); } catch { return 0; } };
// Exclusive create; a file left by a dead process is taken over once.
export function claim(f) {
  for (let i = 0; i < 2; i++) {
    try { writeFileSync(f, String(process.pid), { flag: 'wx' }); return true; } catch (e) { if (e.code !== 'EEXIST') throw e; }
    const pid = owner(f);
    if (pid && alive(pid)) return false;
    try { unlinkSync(f); } catch {}
  }
  return false;
}
export const release = (f) => { if (owner(f) === process.pid) try { unlinkSync(f); } catch {} };

// gh-webhook prints `Error: …` and then its usage text, so the error is what comes
// before `Usage:`, not the last lines.
function forwarderError(err) {
  const lines = err.split('\n').map((l) => l.trim()).filter(Boolean);
  const end = lines.findIndex((l) => /^Usage:/.test(l));
  const head = end === -1 ? lines.slice(-2) : lines.slice(0, end);
  return head.join(' ') || 'it exited';
}

export function joinHub({ repo, events, pick, onEvent, onConnected, onFail }) {
  const dir = join(repoDir(repo), events.replace(/,/g, '+'));
  mkdirSync(dir, { recursive: true });
  const leaderFile = join(dir, 'leader.pid');
  const eventsFile = join(dir, 'events.jsonl');
  const note = (ev) => appendFileSync(eventsFile, JSON.stringify(ev) + '\n');
  let fwd = null;
  let stopped = false;

  function lead() {
    fwd = spawn('gh', ['webhook', 'forward', `--events=${events}`, `--repo=${repo}`], {
      detached: true, stdio: ['ignore', 'pipe', 'pipe'],
    });
    let err = '';
    fwd.stderr.on('data', (d) => {
      const was = /^Forwarding/m.test(err);
      err += d;
      if (!was && /^Forwarding/m.test(err)) { note({ hub: 'connected' }); onConnected(); }
    });
    createInterface({ input: fwd.stdout }).on('line', (line) => {
      let ev; try { ev = JSON.parse(line); } catch { return; }
      const p = pick(ev);
      if (!p) return;
      note(p);
      onEvent(p);
    });
    fwd.on('exit', () => {
      fwd = null;
      if (stopped) return;
      onFail(/Hook already exists/.test(err)
        ? `a webhook forwarder for ${events} already exists on ${repo} that nothing here owns — another machine, or one a killed forwarder left behind (gh api repos/${repo}/hooks lists it)`
        : `webhook forwarder failed: ${forwarderError(err)}`);
    });
  }
  const tryLead = () => { if (!stopped && !fwd && claim(leaderFile)) lead(); };

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
      if (ev.hub === 'connected') onConnected(); else onEvent(ev);
    }
  }
  const watcher = watch(dir, () => { if (stopped) return; readNew(); if (!existsSync(leaderFile)) tryLead(); });
  // A leader killed outright leaves its file behind and fires no event: check it now and then.
  const timer = setInterval(() => { if (!fwd && !alive(owner(leaderFile))) tryLead(); }, 15000);

  // A member that exits without stop() still takes its forwarder down: the
  // forwarder deletes its hook on SIGTERM, even after this process is gone.
  process.once('exit', () => {
    if (fwd) try { process.kill(-fwd.pid, 'SIGTERM'); } catch {}
    release(leaderFile);
  });

  tryLead();
  if (!fwd) setImmediate(onConnected); // after the caller holds the handle this returns

  return {
    async stop() {
      stopped = true;
      watcher.close();
      clearInterval(timer);
      if (fwd) {
        // Wait for the forwarder to delete its hook, or the next leader gets 422.
        const gone = new Promise((r) => fwd.once('exit', r));
        try { process.kill(-fwd.pid, 'SIGTERM'); } catch {}
        await Promise.race([gone, new Promise((r) => setTimeout(r, 5000))]);
      }
      release(leaderFile);
    },
  };
}
