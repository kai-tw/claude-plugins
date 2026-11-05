# Screen review — the page and the strings the user approves

Read at step 4, once the builder's `ui` report is filed.

## Before the user sees it

Open every image and read every string in every locale, beside the existing screen
that does the same job. What breaks a rule or a lesson goes back to the builder, and
every open question it reports that changes what the user sees is a `Needs you`.

## Publishing the page

Publish the page `asst-screens` built (its path is on the report's `screens:` line)
with the `Artifact` tool, passing each call in `artifact.json` beside the page as it
stands; a call after the first adds the first one's `url`. Give the user its link,
never the file or its path, which open as source. Never publish a page of your own, and never stitch the images into one: a
page-wide or combined image is scaled down until it can't be read. A re-render
republishes the same path, so the link stays. Without the `Artifact` tool, the screen
review is a blocker: say so instead of sending the file.

## Strings

The screen review carries every string the task adds or changes, its value listed per
locale; a tone-sensitive one carries the options from the builder's `strings:` block.
The user picks and approves each locale in the same pass; their own wording is always
an answer, and becomes the value as written. **Strings are approved here and nowhere
else**: after the delivery summary they are copied into tests and mockups, and
changing one word means changing dozens of assertion lines. A string first created in
the integration phase comes back from the builder as a strings-only supplement to the
screen review, not a re-render.

Once the user answers, record every key and locale with `asst-strings record <slug>`
before integration starts. The draft is the value the builder wrote, the outcome what
the user did with it: those pairs are what the next draft is written from, and the
rate they add up to says whether drafts are getting closer.
