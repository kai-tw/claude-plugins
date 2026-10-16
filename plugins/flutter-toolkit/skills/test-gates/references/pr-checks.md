# PR checks — line coverage that blocks, mutation that comments

Two checks on every PR, on a self-hosted runner:

- **Line coverage blocks.** `plan-coverage --diff <PR base>` fails the job
  when a line the PR changed isn't executed by any test. Make the job a
  required check where the plan allows it.
- **Mutation comments, after Google's practice.** `plan-mutation --diff <PR
  base> --review <file>` mutates only the lines the PR changed, one mutant a
  line, and `plan-mutation-review` posts each survivor a test reaches as a
  review comment at its line. It never fails the PR: a survivor is a question
  for the reviewer — "would a test notice if this `<` were `<=`?" — not a
  verdict. Survivors no test reaches are left to line coverage.

## The runner

A self-hosted runner with the label `flutter`, on a machine with the
toolchain and `gh`, registered once per repo into its own directory under
`~/actions-runners/` (repo Settings → Actions → Runners → New self-hosted
runner, adding `--labels flutter` to `config.sh`).

Keep each repo's runner up in its own terminal tab with
`~/actions-runners/<dir>/run.sh`. While it's down, a PR's jobs wait queued on
GitHub. An idle runner takes about 60 MB of memory and no CPU. `plan-coverage`
and `plan-mutation` take this machine's test slots like any other run, so CI and
local sessions share the memory budget. Only use it on a private repo: a
public repo's workflows can be made to run a stranger's code on it.

## The workflow

As `.github/workflows/pr-checks.yml`. Replace the `Prepare` step with what
your build needs in a clean checkout, and the test command with the
narrowest one that still covers the code PRs change. Each mutant runs that
command once, so on a large suite add `--select-by-coverage` to the mutation
step, and keep `--max-minutes` under the job's timeout: a run that won't fit
stops and comments nothing.

```yaml
name: pr-checks
on:
  pull_request:
permissions:
  contents: read
  pull-requests: write
concurrency:
  group: pr-checks-${{ github.event.pull_request.number }}
  cancel-in-progress: true
jobs:
  coverage:
    runs-on: [self-hosted, flutter]
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - name: Tools
        run: |
          git clone --quiet --depth 1 https://github.com/kai-tw/claude-plugins "$RUNNER_TEMP/plugins"
          echo "$RUNNER_TEMP/plugins/plugins/flutter-toolkit/bin" >> "$GITHUB_PATH"
      - name: Prepare
        run: flutter pub get && dart run build_runner build --delete-conflicting-outputs
      - name: Line coverage
        run: plan-coverage --diff "origin/$GITHUB_BASE_REF" -- flutter test
  mutation:
    needs: coverage
    runs-on: [self-hosted, flutter]
    timeout-minutes: 120
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - name: Tools
        run: |
          git clone --quiet --depth 1 https://github.com/kai-tw/claude-plugins "$RUNNER_TEMP/plugins"
          echo "$RUNNER_TEMP/plugins/plugins/flutter-toolkit/bin" >> "$GITHUB_PATH"
      - name: Prepare
        run: flutter pub get && dart run build_runner build --delete-conflicting-outputs
      - name: Mutants on changed lines
        continue-on-error: true
        run: plan-mutation --diff "origin/$GITHUB_BASE_REF" --review "$RUNNER_TEMP/review.json" --max-minutes 90 -- flutter test
      - name: Comment survivors
        env:
          GH_TOKEN: ${{ github.token }}
        run: plan-mutation-review "${{ github.event.pull_request.number }}" "$RUNNER_TEMP/review.json"
```

The checkout is the PR's head, not GitHub's merge commit, so the lines
`plan-mutation` reports are the lines the review comments land on. A push to
the PR cancels the run still going for the previous one; a survivor already
commented on at the same line isn't posted again.

Mutation runs only once coverage passes. Don't add `if: always()` to it: a PR
that fails coverage changes anyway, and an `always()` step keeps running after
the workflow is cancelled.
