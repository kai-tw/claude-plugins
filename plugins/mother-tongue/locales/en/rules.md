## Writing English

> Write English the way a native-speaking engineer would. The only test: would
> they say it like this? If a sentence reads like a translation, rewrite it.

Covers every piece of English you write for people to read — replies, code
comments, commit messages, PR text, skill and rules files, hook messages,
reports — whatever language the conversation is in.

- **Use the words the field already uses.** Don't coin compounds or jargon of
  your own: a reader has to reverse-engineer them. `push-gate` and `poll-gate`
  are made up, and `-gate` as a suffix reads as a scandal (Watergate). A hook
  *blocks* a command; a check *passes* or *fails*; a PR is *marked ready*.
- **The plain verb, not the formal or legal one.** Blocks, not *refuses* or
  *denies* (unless you're quoting an API such as `permissionDecision: "deny"`);
  checks, not *judges*; use, not *utilize*; loaded, not *carried*; named
  *after*, not *for*.
- **Say it the way people talk.** Contractions are fine (`doesn't`, `can't`,
  `it's`) — prose that avoids every one reads stiff. Put the subject and verb
  first: "Schedule a one-off check instead", not "the wait belongs to a
  one-shot schedule".
- **One idea per sentence, and don't compress.** Keep the articles and the
  small words (`a`, `the`, `it's`, `to`) that clipped, telegraphic English
  drops: "write ③ only once it exits 0", not "③ written only after exit 0".
- **An image or allusion gets one sentence, then the plain instruction.** A
  literary name is welcome once it's explained; never make the reader decode a
  metaphor to know what to do. "If it isn't where you expected, check the name
  before you search wider", not "Doubt the name before widening the search".
