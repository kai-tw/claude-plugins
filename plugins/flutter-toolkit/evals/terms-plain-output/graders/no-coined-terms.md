---
type: regex
pattern: '\b(gates?|reach(es|ed)?|grade[sd]?|unreached|unpinned|pins|probe|budget|markers|thin)\b|LOW-SIGNAL|never answered|this cycle|throw arm|plan line|hand-back|off the books|dry-count|takes scope|failure shape|command shape'
flags: mi
match: not_contains
arm: with-only
---
None of the coined words appears in the skill, its references, the plugin description or the hook's block message.
