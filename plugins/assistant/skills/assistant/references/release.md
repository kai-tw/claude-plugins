# Release — shipping `base_branch` to production

Read when the user asks what a release would carry, or says to release. Only on git
projects whose config sets `base_branch:`.

There is no release PR: the default branch is fast-forwarded to `base_branch`'s head
by the repo's `release.yml`, which then deploys production. When the user asks what a
release would carry, run `asst-pr release <label> <checkout> --dry-run` and show them
its list. When they say to release, run it without `--dry-run`: it starts `release.yml`
on the commit it lists (which needs `run-name: Release ${{ inputs.sha }}` so the run
can be found) and prints the run's id. Its `next:` line names the one look to schedule
at that run (`--run <id>`); tell the user the outcome that look prints, and do what its
own `next:` line says.
