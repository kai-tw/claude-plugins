# Mutation after the merge — a queue and routine processors

Mutation testing is too slow to hold a PR, so it doesn't gate one. When a PR
merges, a workflow adds the files it changed to the project's mutation queue
and starts routine sessions that work through it.

- **The queue** is the `mutation-queue` branch on origin, with no history in
  common with the default branch and never merged into it: `pending/<path>` is
  waiting, `running/<path>` is claimed, and each lists the PRs that changed that
  file. A file several PRs changed before it ran is one job. Open the branch on
  GitHub to see what's waiting. `asst-mutation-queue status` prints the same.
  A ruleset that requires PRs on every branch blocks it; exclude it.
- **A processor** is one routine session running `asst-mutation-job` until the
  queue is empty. Each run claims a file, grades it, reports, and drops it. A
  pass is a comment on every PR queued for the file; a score under 80, or a run
  that scored nothing, is one issue naming them all — that issue is the debt
  task. Mutants live only in the session's worktree and are never committed.
- **A lost session doesn't lose its work.** The first claim pins the file to
  the default branch's tip, and the run saves its journal (each finished
  mutant) to `journal/<path>` every 5 minutes. A file with no save for 30
  minutes goes back to `pending/`, and the next claim resumes it at the same
  commit, from the same journal. If newer PRs queued the file meanwhile, it
  starts over on the new tip instead. A file whose journal didn't grow over 3
  claims in a row is given up as a `STUCK` issue. Only Dart resumes this way:
  Stryker saves its progress only when stopped cleanly.

## Set up once per project

1. **The adapter's `mutation:`** is a `plan-mutation` command, e.g.
   `plan-mutation --select-by-coverage -- flutter test`. `asst-mutation-job` adds
   `--keep-dir` and `--files <file>` to it.
2. **The adapter's `worktree_init:`**, when the build makes anything git
   ignores: each job runs in a clean worktree, not in the environment's clone,
   so `pub get`, generated code (`build_runner`, `gen-l10n`) and built assets
   are made there by this command, e.g.
   `flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
   What it generates under `lib/` must come out the same on every run of one
   commit, or a resumed run starts over.
3. **A cloud environment** whose setup script installs the toolchain (Flutter,
   and Node if the init builds assets), with the project's settings enabling
   `assistant` and `flutter-toolkit`.
4. **A routine** at claude.ai/code/routines on the project repo, in that
   environment, model Haiku, with two triggers: an API trigger, and an hourly
   schedule. Its runs stay in the routine's own history, out of the session
   list. Save this as its prompt:

   ```
   You process the mutation queue. Nothing else is yours to do.
   Run `asst-mutation-job` with the Bash tool's `run_in_background: true` and
   end the turn; you are woken when it exits. For each `post:` line in its
   output, post the body below that line: `post: comment <pr…>` as a comment
   on each of those PRs, `post: issue <title>` as one new issue with that
   title. Then run it again, until it prints `queue empty`; then stop.
   Never commit, push or ask about anything in this checkout: the asst-*
   commands write the queue themselves, and a file the environment changed
   stays as it is.
   ```
5. **Two repo secrets**: `CLOUD_FIRE_URL` (the routine's `/fire` URL) and
   `CLOUD_FIRE_TOKEN` (its token, shown once when generated).
6. **The workflow**, as `.github/workflows/mutation.yml`. It runs the queue
   script from this plugin's repo, and starts one processor per pending file,
   up to 10 — a routine takes 30 fires an hour. Its file filter is
   `plan-mutation`'s: `lib/**.dart` minus generated files, and JS/TS under a
   package's `src/` or `lib/` minus declarations and tests. Without Actions,
   run `asst-mutation-queue add <pr> <file…>` from any clone after the merge
   instead; the hourly run picks it up, and steps 5–6 aren't needed.

   ```yaml
   name: mutation
   on:
     push:
       branches: [main]
   permissions:
     contents: write
     pull-requests: read
   concurrency: mutation-queue
   jobs:
     queue:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 0
         - name: Queue the changed files and start processors
           env:
             GH_TOKEN: ${{ github.token }}
             CLOUD_FIRE_URL: ${{ secrets.CLOUD_FIRE_URL }}
             CLOUD_FIRE_TOKEN: ${{ secrets.CLOUD_FIRE_TOKEN }}
             BEFORE: ${{ github.event.before }}
             SHA: ${{ github.sha }}
           run: |
             set -euo pipefail
             pr=$(gh api "repos/$GITHUB_REPOSITORY/commits/$SHA/pulls" --jq '.[0].number // empty')
             [ -n "$pr" ] || { echo "no PR merged $SHA — nothing to queue"; exit 0; }
             files=$(git diff --name-only --diff-filter=AM "$BEFORE" "$SHA" \
               | grep -E '^lib/.*\.dart$|(^|/)(src|lib)/.*\.(js|jsx|ts|tsx|mjs|cjs|mts|cts)$' \
               | grep -vE '\.(g|freezed|config|gen)\.dart$|^lib/generated/|\.d\.[mc]?ts$|\.(test|spec)\.[^/]*$|(^|/)(__tests__|node_modules)/' || true)
             [ -n "$files" ] || { echo "PR #$pr changed no file to mutate"; exit 0; }
             git clone --quiet --depth 1 https://github.com/kai-tw/claude-plugins "$RUNNER_TEMP/plugins"
             q="$RUNNER_TEMP/plugins/plugins/assistant/bin/asst-mutation-queue"
             # shellcheck disable=SC2086 # one argument per file
             "$q" add "$pr" $files
             n=$("$q" status | sed -nE 's/^queue: ([0-9]+) pending.*/\1/p')
             for _ in $(seq "$(( n < 10 ? n : 10 ))"); do
               curl -fsS -X POST "$CLOUD_FIRE_URL" \
                 -H "Authorization: Bearer $CLOUD_FIRE_TOKEN" \
                 -H "anthropic-version: 2023-06-01" \
                 -H "Content-Type: application/json" -d '{}' >/dev/null
             done
             echo "queued $(echo "$files" | wc -l) file(s) from PR #$pr; started $(( n < 10 ? n : 10 )) processor(s)"
   ```

## Reading the results

- An `ERROR` issue scored nothing — the environment, the adapter or the run
  itself, not the tests. Fix the cause, then queue the file again with
  `asst-mutation-queue add <pr> <file>`.
- A `FAIL` issue lists the survivors; fix it as a debt task and close the issue
  from that task's PR.
- A `STUCK` issue is a file no session finished a single mutant of, three
  times in a row. Split the file, or run `plan-mutation` on it somewhere a
  session lives longer.
