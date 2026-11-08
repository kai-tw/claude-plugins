// Tests for release.mjs. The script finds its repo root from its own file path,
// so each test copies it into a throwaway repo with a bare repo as `origin`.
// Nothing here touches a real remote or any install: evals are a stub that fails.
//
// Run: node --test .claude/skills/plugin-release/scripts/release.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();

// A repo with plugin "demo" at 1.0.0, tagged demo--v1.0.0, pushed to a bare origin.
function fixture() {
  const dir = mkdtempSync(join(tmpdir(), 'release-test-'));
  const repo = join(dir, 'repo');
  const remote = join(dir, 'remote.git');
  mkdirSync(repo);
  git(dir, 'init', '--bare', '-q', remote);
  git(repo, 'init', '-q', '-b', 'main');
  git(repo, 'config', 'user.email', 't@example.com');
  git(repo, 'config', 'user.name', 'T');
  git(repo, 'remote', 'add', 'origin', remote);

  const put = (rel, text) => {
    mkdirSync(dirname(join(repo, rel)), { recursive: true });
    writeFileSync(join(repo, rel), text);
  };
  put('.claude-plugin/marketplace.json', JSON.stringify({ name: 'm', plugins: [{ name: 'demo', source: './plugins/demo' }] }));
  put('plugins/demo/.claude-plugin/plugin.json', JSON.stringify({ name: 'demo', version: '1.0.0' }, null, 2) + '\n');
  put('plugins/demo/skill.md', 'one\n');
  put('README.md', 'one\n');
  put('.github/scripts/run-evals.mjs', 'console.error("stub evals");\nprocess.exit(1);\n');
  const scripts = join(repo, '.claude/skills/plugin-release/scripts');
  mkdirSync(scripts, { recursive: true });
  for (const f of ['release.mjs', 'consumers.mjs']) cpSync(join(here, f), join(scripts, f));

  git(repo, 'add', '-A');
  git(repo, 'commit', '-q', '-m', 'init');
  git(repo, 'tag', 'demo--v1.0.0');
  git(repo, 'push', '-q', 'origin', 'main');
  return { dir, repo, remote, put };
}

const release = (repo, ...args) =>
  spawnSync('node', [join(repo, '.claude/skills/plugin-release/scripts/release.mjs'), 'demo', 'patch', ...args], {
    cwd: repo,
    encoding: 'utf8',
  });

const commitAll = (repo, msg) => {
  git(repo, 'add', '-A');
  git(repo, 'commit', '-q', '-m', msg);
};

test('[S1] --commit with nothing changed under the plugin since its tag exits non-zero and leaves everything alone', () => {
  const { dir, repo, remote, put } = fixture();
  try {
    put('README.md', 'two\n'); // a change, but outside plugins/demo/
    commitAll(repo, 'docs');
    const manifest = () => readFileSync(join(repo, 'plugins/demo/.claude-plugin/plugin.json'), 'utf8');
    const before = { manifest: manifest(), head: git(repo, 'rev-parse', 'HEAD'), remote: git(remote, 'show-ref') };

    const r = release(repo, '--commit');

    assert.notEqual(r.status, 0);
    assert.match(r.stdout + r.stderr, /nothing (has )?changed/i);
    assert.doesNotMatch(r.stdout, /\[0\] evals/);
    assert.equal(manifest(), before.manifest);
    assert.equal(git(repo, 'rev-parse', 'HEAD'), before.head);
    assert.equal(git(repo, 'status', '--porcelain'), '');
    assert.equal(git(remote, 'show-ref'), before.remote);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('[S2] --commit with a change under the plugin since its tag gets past the change check to the evals', () => {
  const { dir, repo, remote, put } = fixture();
  try {
    put('plugins/demo/skill.md', 'two\n');
    commitAll(repo, 'change skill');
    const remoteBefore = git(remote, 'show-ref');

    const r = release(repo, '--commit');

    assert.match(r.stdout, /plugins\/demo\/skill\.md/);
    assert.match(r.stdout, /\[0\] evals for demo/); // reached the evals; the stub then fails them
    assert.doesNotMatch(r.stdout + r.stderr, /nothing (has )?changed/i);
    assert.equal(git(remote, 'show-ref'), remoteBefore);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('[S3] the dry run still lists what changed since the tag', () => {
  const { dir, repo, put } = fixture();
  try {
    let r = release(repo);
    assert.equal(r.status, 0);
    assert.match(r.stdout, /changed since demo--v1\.0\.0:/);

    put('plugins/demo/skill.md', 'two\n');
    commitAll(repo, 'change skill');
    r = release(repo);
    assert.equal(r.status, 0);
    assert.match(r.stdout, /plugins\/demo\/skill\.md/);
    assert.match(r.stdout, /DRY RUN/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
