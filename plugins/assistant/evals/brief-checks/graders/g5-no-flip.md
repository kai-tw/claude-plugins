---
type: regex
pattern: '(interim|temporary|stopgap|throwaway) (bridge|glue|shim|connection|layer|code|path)s? (is|are|stays?|remains?) (fine|allowed|ok|okay|acceptable|permitted)|(allow|permit|accept)(s|ed)? (an? )?(interim|temporary|stopgap|throwaway)|(may|can) (add|build|write|use|keep) (an? )?(interim|temporary|stopgap|throwaway)|(not|never|n.t|no need to|need not) (to )?build the lower layer first'
match: not_contains
flags: mi
---
[G5] An interim bridge is never allowed when the lower layer can be built first.
