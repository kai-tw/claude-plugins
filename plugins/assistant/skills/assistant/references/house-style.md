# House style for strings — derived from what already shipped

Read before the first task that adds a string in a project with user-visible strings
and no string glossary.

Rules written from scratch don't make text native; the strings the user already
approved do. Derive the house style from the shipped strings (the project's locale files
on the default branch, never a task's own): group them by UI role (button, title,
caption, toast, dialog body, empty state), and for each role measure length, set
phrases and which of two competing words wins, with counts. Show it to the user; only
what they approve goes into a glossary file under the project config's `rules:`, since a
count isn't a preference.
