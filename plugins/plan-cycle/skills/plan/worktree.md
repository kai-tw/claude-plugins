# Worktree isolation — the file-writing boundary

> 任何會寫 repo 檔案的節點都在隔離的 checkout 裡跑（Iron Law 9）。
> 本檔是建立、base 捕捉、sub-agent 陷阱與拆除的完整程序。

#### Worktree isolation (the file-writing boundary)

Concurrent `/plan` sessions share one repo. To keep their edits from colliding,
every code-bearing cycle runs its **file-writing phases in an isolated checkout**.
Only the PM phase is Notion-only and stays in the main tree.

**Which shape of isolation depends on where the session runs**, because that
premise is what changes:

| | isolation | how |
| --- | --- | --- |
| local (`CLAUDE_CODE_REMOTE` unset) | a **worktree** | `EnterWorktree`, steps 1–4 below |
| cloud (`CLAUDE_CODE_REMOTE` set) | a **branch** | step 1 + 1a, then `git checkout -b <the same name>` |

A cloud session's container cloned the repo for itself — no other session can
write into it, so the collision this exists to prevent cannot happen and a
worktree buys nothing. **Everything else is unchanged**: the same base preflight,
the same captured `$BASE`, the same branch name, the same push-per-phase, the
same PR, the same teardown. Only step 2 differs, and step 3's init still runs
(a fresh container needs the project's codegen exactly as a fresh worktree does).

The push gate reads the same marker, so an unpushed cloud branch is caught too —
and it matters more there, since the container's disk goes away with the session.

Create the worktree **immediately before the first phase that writes repo files**
— **the designer phase** when UI is in scope, since it ships the presentation
widgets (`designer` §Phase 5); otherwise `translator` if i18n is in scope (it
writes ARB), else the `code` phase. The engineer-plan phase then runs inside the
worktree — harmless, it only writes Notion.

1. **Precondition.** Ensure the session is on an up-to-date base branch:
   `git fetch && git merge --ff-only @{u}` on whatever branch is the intended PR
   base (with `worktree.baseRef: head` + a session on `main`, that is `main`).
   That only pulls origin→local; it does **not** catch the local base being
   **ahead** of origin (founder's unpushed WIP): also run
   `git rev-list --count origin/main..main`; if >0 those commits ride into your
   branch and the squash-merge folds them into your commit (PR #59) — base the
   worktree off `origin/main` and TELL the user, never auto `git reset --hard`
   (deny-listed). Full reconcile protocol: `git-ops` skill §Worktree base preflight.
1a. **Capture the base** (the worktree's creation base *is* the PR base — single
    source of truth), keyed on the `worktree.baseRef` setting, **before**
    `EnterWorktree`:
    - `head`  → `BASE=$(git rev-parse --abbrev-ref HEAD)`
    - `fresh` → `BASE=$(basename "$(git symbolic-ref refs/remotes/origin/HEAD)")`
    Abort if `BASE` is empty or `HEAD` (detached) — never open a PR against a
    detached base. Carry `$BASE` to close-out alongside the branch name.
2. **Create the isolated checkout.** `name = wt/$BASE/<area>/<slug>` — the `wt/`
   namespace, the captured `$BASE`, the `lib/features/` Area, the kebab task
   slug. Truncate `<slug>` if the whole name would exceed 64 chars. The name is
   the same either way, because the PR, the ledger's `branch`, and the teardown
   all key on it.
   - **Local:** `EnterWorktree` (NOT `git worktree add` — only `EnterWorktree`
     applies `.worktreeinclude`).
   - **Cloud:** `git checkout -b <name>` in the container's own clone. No
     `EnterWorktree`, and therefore no `.worktreeinclude` copy — step 3's init
     is the only thing that makes the tree build, so it is not optional here.
3. **Init:** run the project's worktree-init step if it defines one — a project
   needing codegen, a dependency install, or an asset build in a fresh worktree
   documents that in `.claude/rules/`. `.worktreeinclude` has already copied the
   gitignored build artifacts the project lists there; the init step covers what
   copying alone cannot.
4. **Read the real branch name** with `git branch --show-current` — carry it for
   the close-out push/PR; never assume it equals the worktree name.

All repo-writing phases (translator ARB, code, QA) + their gates + the engineer
commit gate run **on the isolated checkout**. Locally that means staying in the
worktree — do not `ExitWorktree` until close-out; in the cloud it means staying
on the branch, so do not `git checkout` the base until close-out either.

**Sub-agents dispatched from inside a worktree** do NOT inherit its cwd — they
grep the MAIN tree, so worktree-only edits (uncommitted code, just-written ARB
keys) look absent unless you pass each spawned agent the worktree's absolute path
and tell it to `cd` there first. (A cloud session has one checkout and no second
tree to grep, so this trap is local-only.) A code-writing sub-agent commits on its own
unless the prompt forbids it ("do NOT run git commit / git add; leave changes in
the working tree and report the diff"). Full protocol: `git-ops` skill
§Sub-agent dispatch hygiene.

