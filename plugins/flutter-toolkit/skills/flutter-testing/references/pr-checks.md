# PR checks — line coverage and mutation, both blocking

Two checks on every PR, on a self-hosted runner. Make both jobs required
checks where the plan allows it.

- **Line coverage.** `plan-coverage --diff <PR base>` fails the job when a
  line the PR changed isn't executed by any test.
- **Mutation, scoped after Google's practice.** `dart run dart_mutants --diff
  <PR base> --test-command "flutter test"` mutates only the lines the PR
  changed, one mutant a line, and the job fails while any mutant survives on
  one of them; the survivors are in the engine's report in the job log.
  `--test-command` is required. A JS/TS package runs `npx stryker run` with
  `thresholds.break: 100` in its Stryker config, so any survivor fails the
  check, and needs no step in the workflow below. `dart_mutants` is a
  `dev_dependency` of the project and checks its version against github.com, so
  the runner needs network access to it.

## The runner

A self-hosted runner with the label `flutter`, on a machine with the
toolchain, registered once per repo into its own directory under
`~/actions-runners/` (repo Settings → Actions → Runners → New self-hosted
runner, adding `--labels flutter` to `config.sh`).

Keep each repo's runner up in its own terminal tab with
`~/actions-runners/<dir>/run.sh`. While it's down, a PR's jobs wait queued on
GitHub. An idle runner takes about 60 MB of memory and no CPU. `plan-coverage`
takes this machine's test slots like any other run, so CI and local sessions
share the same concurrency limit; `dart_mutants` keeps its own slots. A local session gives up after 120
seconds without a slot, because the Bash tool stops a call at 10 minutes; CI has
no such limit, so the workflow sets `PLAN_TEST_WAIT` to wait an hour instead of
failing a check that measured nothing. Only use it on a private repo: a
public repo's workflows can be made to run a stranger's code on it.

## The workflow

As `.github/workflows/pr-checks.yml`. Replace the `Prepare` step with what
your build needs in a clean checkout, and the test command with the
narrowest one that still covers the code PRs change. The mutation job's
`timeout-minutes` is the only cap on a run.

```yaml
name: pr-checks
on:
  pull_request:
permissions:
  contents: read
concurrency:
  group: pr-checks-${{ github.event.pull_request.number }}
  cancel-in-progress: true
jobs:
  coverage:
    runs-on: [self-hosted, flutter]
    env:
      PLAN_TEST_WAIT: 3600
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
      - name: Prepare
        run: flutter pub get && dart run build_runner build --delete-conflicting-outputs
      - name: Mutants on changed lines
        run: dart run dart_mutants --diff "origin/$GITHUB_BASE_REF" --test-command "flutter test" --workers auto
```

The checkout is the PR's head, not GitHub's merge commit, so the lines the
engine reports are the lines of the PR's diff. A push to the PR cancels the run
still going for the previous one.

Mutation runs only once coverage passes. Don't add `if: always()` to it: a PR
that fails coverage changes anyway, and an `always()` step keeps running after
the workflow is cancelled.
