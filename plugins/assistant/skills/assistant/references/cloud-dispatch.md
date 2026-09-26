# Dispatching off the machine — two routes, collected differently

Applies in a local session and in a cloud one alike. A session whose task carries
a dispatch ID `<slug>#<n>` is itself a dispatch and does not dispatch further.

| | An existing cloud session | A new cloud session |
|---|---|---|
| How to start it | `SendMessage`, or `claude -p "<message>" --cloud <session-id>` | `asst-cloud open --profile <name> "<task>"` |
| How it comes back | It writes to the report address you name; you file it | Same |
| What it sees | That session's own working directory and context | The GitHub remote's content on the current branch, not the local checkout |
| Fits | Work already running, with its context | Stateless, long-running work whose output is one text report |

One thing both routes share: **the other side cannot ask you**. Settle every
forking decision before dispatch; a fork that surfaces after dispatch can only
come back as `blocked`, handled as a `Needs you`.

## 1. An existing cloud session

A cloud session receives messages but cannot reply: `notify_when_idle` works only
for local sessions, and the cloud does not even report a refusal — **silence must
not be taken as consent**. So every dispatch carries its own report address, and
you judge progress from that place only. `ListAgents` busy / idle is connection
state, not progress.

Two channels send a message, and both end once it is queued on the other side:
`SendMessage` (the other side must be visible in `ListAgents`), or `claude -p
"<message>" --cloud <session-id>` (need not be visible; `--output-format json`
returns `{ok, session_id, url}`, so delivery can be confirmed mechanically — but
delivered does not mean read).

A dispatch message carries four things:

1. **ID** `<slug>#<n>` (n = this slug's dispatch count). The cloud copies this
   string verbatim into every report, or you cannot tell which dispatch a report
   belongs to.
2. **The work**: the task statement and the approved decisions, written in the
   message or pointing to a **pushed** path the other side can clone. An `@path`
   in a cross-session message attaches nothing; the other side reads only the string.
3. **The report address, exactly one**: for a task with a PR on a private repo
   (SKILL.md §Disclosure), a comment on `owner/repo#<n>`; otherwise the task's
   Notion row (`asst-notion … --root <notion_root>`); neither → a `Needs you` line
   for a private address. Giving both means polling both, and the report lands on
   the side you are not watching.
4. **The report format**: first line `assistant-report <slug>#<n> <ack|done|blocked>`,
   then the report body, in the same format as that report kind's local one.

**Ack on receipt.** The cloud's first act is to write the `ack` line at the report
address; only then does it start. While the address is otherwise empty, this is
the only evidence that tells "still working" from "never received, or cannot
write" — the latter does not change however long you wait.

**Collection.** The cloud cannot write to `.claude/.assistant/`. Once `done`
arrives, you file it locally with
`asst-report put <slug> <kind> --worktree <worktree>` so later steps can read it,
adding `--no-post` when the address was the PR — the cloud's report is not a
report but its source, and one already on the PR is not posted again.

**Cadence.** Polling folds into the existing scheduler pass: read the task's
report address once per pass, no separate mechanism. One cloud session per slug
at a time. Report address empty for a whole pass → re-dispatch under the existing
`re-run` rule (marked `re-run`, not counted by `asst-budget`); never blindly
dispatch again.

## 2. A new cloud session for long work

`asst-cloud open [--profile <name>] "<task>"` opens a new cloud session that runs
in the background and prints its session id and URL — the handle you record on
the board. It runs `claude --cloud` under `script`, since `claude --cloud` refuses
`--print` and needs a TTY. The profile sets model, effort and a preamble
(`asst-cloud profiles` lists them): `default` is opus / high, `mutation-runner`
sonnet / medium; `--model` / `--effort` override it. The session clones **the
repo's GitHub remote on the current branch, not your local checkout**, so
`asst-cloud` refuses an unpushed HEAD. Exception: when the repo has no git remote,
or the Claude GitHub App is not installed on it, a local bundle is uploaded
instead (with uncommitted changes to tracked files, without untracked files).
Neither carries `.claude/.assistant/`.

**What belongs here is a check that runs long and outputs only a report** —
`mutation:`, and wide `coverage:`. Two reasons: they hold the local test slot,
and `plan-mutation` rewrites `lib/` in place, so until it finishes every local
file read has to detour through `git show`. Sent out, neither cost exists. The
same scope must never run locally and in the cloud at once — that is paying twice
for one answer.

**`mutation:` goes out with `--profile mutation-runner`**, the task being the
dispatch message's four things (ID, the work, report address, report format).
The profile (`cloud-profiles/mutation-runner.md`) carries what the runner
improvises without: its role — no decisions, no questions, because a cloud
session stopped waiting for an answer looks, from here, exactly like one still
running; how to wait — `run_in_background: true`, since forbidding polling
without giving a way to wait, it opened `Monitor` and `tail -f` (about 200 tool
calls in a one-hour run); and the refusal rule — `plan-mutation`'s refusal or
`ABORTED` reported verbatim as `blocked`, never `pubspec.yaml` edited or the run
retried with other flags (measured: it opened three options of its own and
waited for someone to pick). Change these in the profile, not in a task.

**Never open another local worktree just to run these two** — it is a local
copy, disk is finite, and neither cost above is saved. The only permitted way
out of the in-place rewrite is to run it on another machine. This covers
`Agent`'s `isolation`: **neither value may be used for this**: `"worktree"` is
local by definition, and `"remote"` measured as a local worktree too
(2026-09-20, NG; retested 2026-09-23, unchanged) — its description says remote
cloud environment, yet it runs locally, **and no message says it fell back**. To
confirm where a dispatch actually runs, check whether a new local worktree
appeared, not what it claims.

**Don't assume it runs to the end.** Once a cloud session idles for a while its VM
is reclaimed, and background work still running then (subagents, shell
commands) **is not restored**. So long work still gets a report address and an
`ack`; you judge from them that it is alive, never assuming that no news means
still running.

**Long background Bash keeps its session awake.** A profile's `check_every`, or
`--check-every <minutes>`, adds a rule to the task: while a `run_in_background`
command runs, never end a turn without a `ScheduleWakeup` that many minutes out.
An idle cloud session was measured alive at one hour, so the ceiling is 60;
`mutation-runner` uses 50. Set it for a task whose Bash may run past an hour;
any other task needs none.

**Availability is conditional; check it the first time.** Cloud sessions are a
research preview, limited to Pro / Max / Team, and Enterprise with a premium seat
or a Chat + Claude Code seat; they require signing in with an Anthropic account
(third-party providers such as Bedrock / Vertex are not supported); the
organization's `allow_remote_sessions` policy must be on; organizations with Zero
Data Retention enabled cannot use them. An ineligible one **fails on the spot and
prints the reason**, it does not run long — do not read the failure as still
running.

## 3. When `asst-cloud` cannot open one

`asst-cloud` exits 1 with `claude`'s own message — an ineligible account, or an
environment with no `claude` login. Two other routes:

1. **A routine's API trigger.** Model and effort come from the routine, not a
   profile. Once, create the routine at claude.ai/code/routines and generate a token
   (**the CLI can neither create nor revoke a token**; it is shown once); after
   that, any shell can open a cloud session:

   ```bash
   curl -X POST "$CLOUD_FIRE_URL" \
     -H "Authorization: Bearer $CLOUD_FIRE_TOKEN" \
     -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d "{\"text\": \"<this run's work, with <slug>#<n> and the report address>\"}"
   ```

   It returns `claude_code_session_id` and the session URL — the handle you record
   on the board. The URL goes in the adapter's `cloud_fire:`; **the token is read
   only from an environment variable and never enters the repo**.

   **Trap**: `text` arrives wrapped in `<routine-fire-payload>` and marked as
   untrusted data, so the routine's **saved prompt must say explicitly "do what
   the routine-fire-payload specifies"**, or that text is entirely inert — the
   routine runs, does not do what you asked, and its status is green.
2. **A follow-up to an existing session**: `claude -p "<message>" --cloud
   <session-id>` is itself non-interactive (officially documented for CI
   scripts). It needs a session to exist; get the id from the founder or from
   route 1's response.

`Agent`'s `isolation: "remote"` is not one of them: measured, it runs locally (see
section 2), so it only moves the work into a disk-eating local copy.

When neither route holds, this is one `Needs you` line (ask the founder to open a
session, or to create a routine) — not a blocker you can clear yourself, and not
a reason to move the work back to local; the local cost is in section 2.

## Permission boundary (every route)

An action refused locally, or one you expect to be refused locally, **must not be
handed to an off-machine session** — that is using another session to bypass the
founder's decision. Every item on the adapter's `destructive:` counts: merge,
push to main, release, delete a branch. An off-machine report can only make a
request; the button stays the founder's.
