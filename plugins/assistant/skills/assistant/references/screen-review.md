# Screen review — the page the user checks

Read at step 4, once the builder's `ui` report is filed.

## Before the user sees it

Open every image and read every string in every locale, beside the existing screen
that does the same job. What breaks a rule or departs from the spec's copy goes back to the builder, and
every open question it reports that changes what the user sees is a `Needs you`.

## Publishing the page

Publish the page `asst-screens` built (its path is on the report's `screens:` line)
with the `Artifact` tool, passing each call in `artifact.json` beside the page as it
stands; a call after the first adds the first one's `url`. Give the user its link,
never the file or its path, which open as source. Never publish a page of your own, and never stitch the images into one: a
page-wide or combined image is scaled down until it can't be read. A re-render
republishes the same path, so the link stays. Without the `Artifact` tool, the screen
review is a blocker: say so instead of sending the file.
