# Product pages — how each feature behaves, decided with the founder

The adapter's `product:` names three page titles: the product page under
`notion_root`, then its two children — one holds a page per feature, the other a
page per shared design (a screen or interaction rule several features use). Find
them by title in `ntn api v1/blocks/<id>/children`; record no page id. With
`product: none` the filed brief is the only record of a mechanism.

## What a page holds

- How the feature behaves, in detail, in product language: what the user sees and
  does. No file path, class name or line number on the page, and no list of the
  lines read is kept anywhere.
- A behaviour several features share is written once, on its shared-design page;
  feature pages link to it instead of restating it.
- Links are complete and go both ways: a shared-design page lists every feature
  that uses it, and each of those feature pages links back. A page not written
  yet is named in plain text and linked once it exists.
- Headings are the ones the sibling pages already use, word for word; the first
  page of a kind translates the lists below into the founder's language.
- A founder ruling is a line of its own: `Founder ruling (<date>): …`.
- `Checked against: <repo> <branch> @ <sha> (<date>)` names the commit the whole
  page was last read against.

Feature page: intro · Checked against · Entry points · Mechanism · States and
screens · Edge cases · Settings and defaults · Data · Permissions and billing ·
Relations to other features · Related decisions · Known issues and to-dos.

Shared-design page: intro · Status (`current`, or `kept, not used for new work`) ·
Checked against · Screen rules · Details · Features using this design · Where the
app doesn't follow the rule.

## When a page changes

Within a task, only when a mechanism is decided (SKILL.md §The flow step 3). A
feature with no page gets one holding only what this task decided, its intro
saying so. Until the PR merges, the page's last section names the task row as
code that doesn't match yet; Close deletes that line.

## Writing a page from the code

Only on the founder's request, one page at a time.
- Read the default branch; the page says it was read from the code and not
  reproduced on a device.
- Each place the app differs from the page goes in its last section. All of one
  page's differences go into one row, `asst-board create … Status=Backlog
  Stage="Product Plan" --body <file>`: where it was found, what the app does now,
  the ruling, a to-do list. The page links to that row.
- Upload with `ntn pages edit <id> < page.md`, then read the blocks back (scribe).
