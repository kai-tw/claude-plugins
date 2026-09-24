# Rules for writing rules

Applies to writing or changing any skill, agent or rules file in this repo. The reader is
always a fresh-context agent: it sees only what the file says now, not why you changed it,
and never the previous version.

- **English only.** The repo is public: every file, commit message and PR is in English.
  Chinese stays only where it is the content — mother-tongue's `locales/zh-TW/`, Chinese
  test data, and trigger phrases that match a Chinese-speaking user's prompt.
- **Fewest lines, fewest words.** One rule says one thing; never two sentences where one
  will do. Keep a WHY only when the rule would otherwise be reasonably broken, and fold it
  into a clause of the same sentence, not a paragraph of its own.
- **Delete cleanly.** When a mechanism, an agent or an old behaviour goes, every reference
  to it goes too. No "X is retired" or "it used to be Y, now it is Z" residue — a fresh
  reader cannot tell which version to believe. History lives in git.
- **One behaviour, one version.** When the same behaviour is written in several places
  (launcher / role skill / rules), numbers and conditions must match word for word;
  changing one means changing all, or first merge them into one place and point the rest
  at its path.
- **A rule is what can be checked.** A rule an onlooker cannot check is a preference —
  delete it or rewrite it as a checkable criterion.
