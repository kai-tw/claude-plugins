# Release — shipping `base_branch` to production

Read when the user asks what a release would carry, or says to release. Only on git
projects whose config sets `base_branch:`.

There is no release PR: the default branch is fast-forwarded to `base_branch`'s head
by the repo's `release.yml`, which then deploys production. When the user asks what a
release would carry, run `asst-pr release <label> <checkout> --dry-run` and show them
its list. When they say to release, run it without `--dry-run` and with
`run_in_background: true`: it starts `release.yml` on the commit it lists (which needs
`run-name: Release ${{ inputs.sha }}` so the run can be found), waits for that run,
and its exit wakes the session. Tell the user the outcome it prints, and do what its
`next:` line says.
