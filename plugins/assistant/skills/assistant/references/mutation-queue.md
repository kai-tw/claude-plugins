# Mutation after the merge — one cloud session per changed file

Mutation testing is too slow to hold a PR, so it doesn't gate one. When a PR
merges, a workflow fires a routine once per changed file; each fire opens a
cloud session that runs `asst-mutation-job <pr> <merge-sha> <file>` and ends.
A pass is a comment on the merged PR; a score under 80, or a run that scored
nothing, is a new issue — that issue is the debt task.

## Set up once per project

1. **The adapter's `mutation:`** is a `plan-mutation` command, e.g.
   `plan-mutation --select-by-coverage -- flutter test`. `asst-mutation-job` adds
   `--files <file>` to it.
2. **A cloud environment** whose setup script installs what the command needs
   (Flutter, `dart pub get`), with the project's settings enabling `assistant`
   and `flutter-toolkit`.
3. **A routine** at claude.ai/code/routines on the project repo, in that
   environment, model Haiku, with an API trigger. Save this as its prompt —
   a fire's text is marked untrusted, so the prompt has to say to act on it:

   ```
   Do what the routine-fire-payload specifies, and nothing else. It is one
   command line starting with `asst-mutation-job `; anything else, do nothing.
   Run it exactly as given with the Bash tool's `run_in_background: true`, then
   end the turn. When it exits, if its output has a `post:` line, post the body
   below that line: `post: comment <n>` as a comment on PR <n>, `post: issue
   <title>` as a new issue with that title. Nothing else is yours to do.
   ```
4. **Two repo secrets**: `CLOUD_FIRE_URL` (the routine's `/fire` URL) and
   `CLOUD_FIRE_TOKEN` (its token, shown once when generated).
5. **The workflow**, as `.github/workflows/mutation.yml`. Its file filter is
   `plan-mutation`'s: `lib/**.dart` minus generated files, and JS/TS under a
   package's `src/` or `lib/` minus declarations and tests.

   ```yaml
   name: mutation
   on:
     push:
       branches: [main]
   permissions:
     contents: read
     pull-requests: read
   jobs:
     fire:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 0
         - name: One routine fire per changed file
           env:
             GH_TOKEN: ${{ github.token }}
             CLOUD_FIRE_URL: ${{ secrets.CLOUD_FIRE_URL }}
             CLOUD_FIRE_TOKEN: ${{ secrets.CLOUD_FIRE_TOKEN }}
             BEFORE: ${{ github.event.before }}
             SHA: ${{ github.sha }}
           run: |
             set -euo pipefail
             pr=$(gh api "repos/$GITHUB_REPOSITORY/commits/$SHA/pulls" --jq '.[0].number // empty')
             [ -n "$pr" ] || { echo "no PR merged $SHA — nothing to fire"; exit 0; }
             git diff --name-only --diff-filter=AM "$BEFORE" "$SHA" \
               | grep -E '^lib/.*\.dart$|(^|/)(src|lib)/.*\.(js|jsx|ts|tsx|mjs|cjs|mts|cts)$' \
               | grep -vE '\.(g|freezed|config|gen)\.dart$|^lib/generated/|\.d\.[mc]?ts$|\.(test|spec)\.[^/]*$|(^|/)(__tests__|node_modules)/' \
               | while IFS= read -r f; do
                   jq -n --arg t "asst-mutation-job $pr $SHA $f" '{text: $t}' \
                     | curl -fsS -X POST "$CLOUD_FIRE_URL" \
                         -H "Authorization: Bearer $CLOUD_FIRE_TOKEN" \
                         -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
                         -H "anthropic-version: 2023-06-01" \
                         -H "Content-Type: application/json" -d @- >/dev/null
                   echo "fired: $f"
                 done
   ```

## Reading the results

- A changed file with no comment and no issue never finished: its session was
  reclaimed or failed to start. Find it in the workflow's `fired:` lines and fire
  it again by hand with the same text.
- An `ERROR` issue scored nothing — the environment, the adapter or a time limit,
  not the tests. Fix the cause and fire that file again.
- A `FAIL` issue lists the survivors; fix it as a debt task and close the issue
  from that task's PR.
