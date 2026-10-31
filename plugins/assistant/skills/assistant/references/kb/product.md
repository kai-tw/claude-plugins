# KB module `product` — how each feature behaves, decided with the founder

Load at: ① brief (step 3) · a founder's request for a page.

The pages are titled in the founder's language:
- **Notion** (`board: notion`): rows of KB Pages whose `Module` is the product
  module, and whose `Kind` is feature (a page per feature) or shared design (a page
  per screen or interaction rule several features use). Find them with
  `asst-notion query kb-pages Module=<product module>`; record no page id. A new
  page is a new row: `asst-notion create` with `"db":"kb-pages"`, its Module and
  Kind, and the page as `bodyFile`.
- **File board**: `<kb>/product/features/<feature>.md` and
  `<kb>/product/shared/<design>.md`, changed on the task's own branch, so a page
  merges with the code that follows it.

A project with no shared designs leaves that part out; a behaviour two features
share is then written on the first one's page, and the other links to it.

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
- On Notion, these sections are linked views filtered on Pages contains this page:
  Releases (the Release Log, feature pages only), Related decisions (the Decision
  Log) and the last section (the TaskList). A new page gets them (`ntn api v1/views
  -X POST` with `create_database`). In the page's Markdown each is one
  `<database url=…>` line: keep them when rewriting the page, and never pass
  `--allow-deleting-content`, which deletes them.
- A Release Log row names the pages its highlights change (`Pages`), so a feature
  page's Releases lists the versions that changed it.

Feature page: intro · Checked against · Entry points · Mechanism · States and
screens · Edge cases · Settings and defaults · Data · Permissions and billing ·
Relations to other features · Releases · Related decisions · Known issues and to-dos.

Shared-design page: intro · Status (`current`, or `kept, not used for new work`) ·
Checked against · Screen rules · Details · Features using this design · Where the
app doesn't follow the rule.

## At ①

- Read the pages of every feature and shared design the task touches before
  writing the brief; its mechanism lines quote or link them (`brief.md`).
- Once the founder answers, write each decided mechanism onto its page before
  Build starts. A feature with no page gets one holding only what this task
  decided, its intro saying so. Each fork filed with `asst-board decide` names those
  pages on its `**Pages**:` line, by their exact titles, so the page's Related
  decisions show it; a new page is created first, or `decide` stops on its title.
  On Notion, the task row names the same pages (`asst-board set <slug>
  "Pages=<title>,…"`), so it shows in each page's last section as code that
  doesn't match yet, until it is trashed at Close.

## On the founder's request

One page at a time, written from the code.
- Read the default branch; the page says it was read from the code and not
  reproduced on a device.
- Each place the app differs from the page goes in its last section. All of one
  page's differences go into one row, `asst-board create … Status=Backlog
  Stage="Product Plan" --body <file>`: where it was found, what the app does now,
  the ruling, a to-do list. On Notion the row carries `"Pages=<this page>"`, so it
  shows in the page's last section; in a directory the page links to it.
- On Notion, upload with `ntn pages edit <id> < page.md` (the Related decisions
  line kept), then read the blocks back
  (scribe); in a directory, commit it on a branch like any other doc change.
