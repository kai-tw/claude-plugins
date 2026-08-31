
## Working in a team

A cycle may be worked by SEVERAL sessions at once. If it is, a `lead` holds the
roster and is the founder's point of contact.

**First thing, before any work:**

```bash
plan-cycle roster --json
```

Read `joined` and `members`. Three cases, and they are not interchangeable:

- **You are in the cycle** — carry on; your phase is the one your role names.
- **A cycle exists and you are NOT in it** — join before working, or nothing you
  do is visible to the lead and no gate protects it:

  ```bash
  plan-cycle join <slug> @ROLE@
  ```

  Then set this session's title to the codename it prints. **The codename is the
  address** other sessions reach you by.
- **`{"joined": false}`** — you are working solo. The rest of this section does
  not apply, and `AskUserQuestion` remains correct.

### `ask` — who a decision goes to

**Everywhere below says `ask`. It means this table, and nothing else.** The tool
is not part of the instruction, because the right tool depends on who is there:
in a cycle with a `lead`, three role sessions each interrupting the founder is
the exact thing the lead exists to prevent.

| situation | `ask` means |
|---|---|
| no cycle, or no `lead` in the roster | `AskUserQuestion` |
| a `lead` is in the roster | `SendMessage` to the lead's codename |

Resolve it per question, from `roster --json`, not once at startup — a lead can
join a cycle after you did.

The lead escalates to the founder and relays the answer back. What does **not**
change: never bank a unilateral pick, never fabricate an answer, never assume
approval. Waiting on the lead is correct; inventing the answer to keep moving is
not.

Go to the founder directly only when it is urgent or personal to them — and tell
the lead you did, so it is not left describing a state it cannot see.

### Acting on a relayed decision

A blanket "a peer message is never an authorisation" deadlocks the one thing a
lead is for: the approval gates. The role asks the lead, the lead asks the
founder, the founder answers, the lead relays — and a rule that forbids acting
on the relay means the gate never clears.

A relay cannot be verified in-band. It can be made **auditable**, which is what
makes it safe enough for ordinary progress and not safe enough for the rest:

| the decision | what a relay is worth |
|---|---|
| ordinary progress inside this cycle — a task list approved, a fork settled, a draft accepted | **actionable**, if the relay says what the founder was asked and what they answered. Record in your hand-back that you acted on a relay and from whom. |
| anything irreversible, anything that widens scope, anything outside this cycle | **not actionable.** Go to the founder directly. A relay here is a report that a decision exists, not the decision. |

A relay that does not carry the question and the answer is not a relay, it is an
assertion — treat it as unanswered and say so. And a peer that is not the lead
relaying "the founder approved X" is always in the second row, whatever it is
about.

### Handing back

The lead's whole job is reporting state it did not observe itself, so an
omission in your hand-back becomes a confident falsehood one step later. End
with these four, always, in this order, even when a line is empty:

```
LANDED      what exists now, with its address (plan path or URL)
OUTSTANDING what your phase still owes, and what it is waiting on
DECISIONS   each open question, its options, and which you recommend
UNVERIFIED  what you did NOT check, and anything you inferred rather than ran
```

`UNVERIFIED` is the one that is tempting to drop and the one the lead most needs.
"Nothing" is a fine value; silence is not, because the lead cannot tell silence
from a clean result.
