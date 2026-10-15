# Mutation after the merge — one Actions job per changed file

Mutation testing is too slow to hold a PR, so it doesn't gate one. When a PR
merges, a workflow on a self-hosted runner runs `asst-mutation-job` once per
file the PR changed, each in a job of its own.

- **A pass** is a comment on the PR. **A score under 80**, or **a run that
  scored nothing**, is an issue — that issue is the debt task. Mutants live
  only in the job's worktree and are never committed.
- **An interrupted job resumes.** Each file's journal (every finished mutant,
  and from dart_mutants 0.7.0 the coverage pass test file by test file) stays
  on the runner until the
  file is scored, so running the job again picks up where it stopped. A job
  fails only when it was cut off before it could report; a second workflow
  re-runs failed jobs every hour, up to 3 attempts.
- **A file several PRs changed** runs once per PR.

## Set up once per project

1. **The adapter's `mutation:`** is a `plan-mutation` command, e.g.
   `plan-mutation --select-by-coverage -- flutter test`. `asst-mutation-job` adds
   `--keep-dir` and `--files <file>` to it.
2. **The adapter's `worktree_init:`**, when the build makes anything git
   ignores: each job runs in a clean worktree, so `pub get`, generated code
   (`build_runner`, `gen-l10n`) and built assets are made there by this
   command, e.g.
   `flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
   What it generates under `lib/` must come out the same on every run of one
   commit, or a resumed job starts over.
3. **A self-hosted runner** with the label `mutation`, on a machine that has
   the toolchain (Flutter; Node if the init builds assets) and `gh`. Register
   it under the repo's Settings → Actions → Runners → New self-hosted runner,
   adding `--labels mutation` to `config.sh`, then install it as a service with
   `./svc.sh install && ./svc.sh start` so it runs without a terminal. The
   service doesn't read your shell profile: from a shell where `flutter` works,
   run `echo "$PATH" > .path` in the runner's directory, then
   `./svc.sh stop && ./svc.sh start`. A runner takes one job at a time, so a
   PR's files run one after another; register more runners to run them side
   by side. Only use it on a private repo: a public repo's workflows can be
   made to run a stranger's code on it.
4. **The workflows**, as `.github/workflows/mutation.yml` and
   `.github/workflows/mutation-retry.yml`. They take `asst-mutation-job` and
   `plan-mutation` from this plugin's repo. The file filter is
   `plan-mutation`'s: `lib/**.dart` minus generated files, and JS/TS under a
   package's `src/` or `lib/` minus declarations and tests.

   ```yaml
   name: mutation
   on:
     push:
       branches: [main]
   permissions:
     contents: read
     pull-requests: write
     issues: write
   jobs:
     files:
       runs-on: [self-hosted, mutation]
       outputs:
         pr: ${{ steps.list.outputs.pr }}
         files: ${{ steps.list.outputs.files }}
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 2
         - id: list
           env:
             GH_TOKEN: ${{ github.token }}
           run: |
             set -euo pipefail
             pr=$(gh api "repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" --jq '.[0].number // empty')
             files=$(git diff --name-only --diff-filter=AM "$GITHUB_SHA^" "$GITHUB_SHA" \
               | grep -E '^lib/.*\.dart$|(^|/)(src|lib)/.*\.(js|jsx|ts|tsx|mjs|cjs|mts|cts)$' \
               | grep -vE '\.(g|freezed|config|gen)\.dart$|^lib/generated/|\.d\.[mc]?ts$|\.(test|spec)\.[^/]*$|(^|/)(__tests__|node_modules)/' || true)
             echo "pr=$pr" >> "$GITHUB_OUTPUT"
             echo "files=$(printf '%s\n' "$files" | jq -Rnc '[inputs | select(length > 0)]')" >> "$GITHUB_OUTPUT"
     mutate:
       needs: files
       if: needs.files.outputs.pr != '' && needs.files.outputs.files != '[]'
       runs-on: [self-hosted, mutation]
       timeout-minutes: 720
       strategy:
         fail-fast: false
         matrix:
           file: ${{ fromJSON(needs.files.outputs.files) }}
       steps:
         - uses: actions/checkout@v4
         - env:
             GH_TOKEN: ${{ github.token }}
             PR: ${{ needs.files.outputs.pr }}
             FILE: ${{ matrix.file }}
           run: |
             set -euo pipefail
             git clone --quiet --depth 1 https://github.com/kai-tw/claude-plugins "$RUNNER_TEMP/plugins"
             export PATH="$RUNNER_TEMP/plugins/plugins/assistant/bin:$RUNNER_TEMP/plugins/plugins/flutter-toolkit/bin:$PATH"
             asst-mutation-job "$PR" "$GITHUB_SHA" "$FILE"
   ```

   ```yaml
   name: mutation-retry
   on:
     schedule:
       - cron: '17 * * * *'
   permissions:
     actions: write
   jobs:
     retry:
       runs-on: [self-hosted, mutation]
       steps:
         - env:
             GH_TOKEN: ${{ github.token }}
           run: |
             gh run list -R "$GITHUB_REPOSITORY" --workflow mutation.yml --status failure \
               --limit 20 --json databaseId,attempt --jq '.[] | select(.attempt < 3) | .databaseId' \
               | while read -r id; do gh run rerun "$id" -R "$GITHUB_REPOSITORY" --failed; done
   ```

## Reading the results

- An `ERROR` issue scored nothing — the environment, `worktree_init`, the
  adapter or the run itself, not the tests. Its journal is kept: fix the
  cause, then re-run that file's job from the Actions page to resume.
- A `FAIL` issue lists the survivors; fix it as a debt task and close the issue
  from that task's PR.
- A run that is still failing after 3 attempts was cut off every time — the
  runner went offline or the job hit its time limit. Re-run it by hand once the
  runner is back.
