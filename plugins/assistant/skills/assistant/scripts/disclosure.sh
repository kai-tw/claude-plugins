#!/usr/bin/env bash
# disclosure_leaks <dir> <base> [text] — what pushing <dir>'s commits since <base>,
# with [text] as the PR body, would publish from outside its repo: one
# `<where>: <term>` line each, nothing when clean or when the repo is private.
# Sourced by asst-pr, after github.sh. Caught: a private or internal repo of this
# owner or of the gh user, named in full, or bare when the name holds `-_.` or a
# capital · a home-directory path · a `#<n>`
# that is no issue or PR of this repo (another repo's, written bare). A private
# identifier that names no repo is not caught here; SKILL.md §Disclosure covers it.
disclosure_leaks() {
  local wt=$1 base=$2 body=${3:-} nwo names msgs added
  gh_private "$wt" && return 0
  nwo=$(cd "$wt" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
  if [ -n "$nwo" ]; then
    names=$(for v in private internal; do
      gh repo list "${nwo%/*}" --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner'
      gh repo list --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner'
    done 2>/dev/null | sort -u)
  fi
  msgs=$(git -C "$wt" log --format=%B "$base..HEAD" 2>/dev/null)
  added=$(git -C "$wt" diff "$base...HEAD" 2>/dev/null | grep '^+' | grep -v '^+++' | cut -c2-)

  scan() {
    local where=$1 text=$2 r
    [ -n "$text" ] || return 0
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      if grep -qiF -- "$r" <<<"$text"; then echo "$where: $r"
      # Bare only when the name cannot be a plain word: a repo called `images`
      # would refuse every diff that says images.
      elif [[ ${r#*/} =~ [-_.A-Z] ]] && grep -qwF -- "${r#*/}" <<<"$text"; then echo "$where: ${r#*/}"
      fi
    done <<<"$names"
    grep -oE '(/Users|/home)/[^/[:space:]]+/[^[:space:]`)"]*' <<<"$text" | sort -u | sed "s|^|$where: |"
  }
  refs() {
    local where=$1 text=$2 n
    [ -n "$nwo" ] && [ -n "$text" ] || return 0
    grep -oE '(^|[^[:alnum:]_/&])#[0-9]+' <<<"$text" | grep -oE '[0-9]+' | sort -un | while read -r n; do
      gh api "repos/$nwo/issues/$n" --silent 2>/dev/null || echo "$where: #$n is no issue or PR of $nwo"
    done
  }
  scan "commit message" "$msgs"; refs "commit message" "$msgs"
  scan "diff" "$added"
  scan "PR body" "$body"; refs "PR body" "$body"
}
