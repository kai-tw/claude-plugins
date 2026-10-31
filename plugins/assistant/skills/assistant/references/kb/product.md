# KB module `product` — how each feature behaves, decided with the founder

Load at: ① brief (step 3) · Close (step 8) · a founder's request for a page.

The adapter's `kb_pages:` entry `product = <where>` says where the pages live:
- **Notion** (`board: notion`): page titles — the product page under
  `notion_root`, the child holding a page per feature, then the child holding a
  page per shared design (a screen or interaction rule several features use).
  Find them by title in `ntn api v1/blocks/<id>/children`; record no page id.
- **A directory in the repo** (e.g. `docs/product/`): `features/<feature>.md`
  and `shared/<design>.md`, changed on the task's own branch, so a page merges
  with the code that follows it.

A project with no shared designs leaves that part out (the third title, or
`shared/`); a behaviour two features share is then written on the first one's
page, and the other links to it.

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

## At ①

- Read the pages of every feature and shared design the task touches before
  writing the brief; its mechanism lines quote or link them (`brief.md`).
- Once the founder answers, write each decided mechanism onto its page before
  Build starts. A feature with no page gets one holding only what this task
  decided, its intro saying so. On Notion, the page's last section also names the
  task row as code that doesn't match yet, until the PR merges.

## At Close

On Notion, delete the task's line from the last section of each page ① wrote.

## On the founder's request

One page at a time, written from the code.
- Read the default branch; the page says it was read from the code and not
  reproduced on a device.
- Each place the app differs from the page goes in its last section. All of one
  page's differences go into one row, `asst-board create … Status=Backlog
  Stage="Product Plan" --body <file>`: where it was found, what the app does now,
  the ruling, a to-do list. The page links to that row.
- On Notion, upload with `ntn pages edit <id> < page.md`, then read the blocks back
  (scribe); in a directory, commit it on a branch like any other doc change.
