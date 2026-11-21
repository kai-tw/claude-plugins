---
type: regex
pattern: '^index\.md: - \*\*S16\.2 .*Example: [^.]*(construct|build|creat|instantiat)[a-z]* (a |an )?(library.s|package.s|dependency.s|third-party) (exception|error)[^.]*mapping[^.]*\bkey\b'
flags: mi
arm: with-only
---
[J11] S16.2 example: building a package exception by hand only to reach the error mapping, where a lookup by key is the entry point.
