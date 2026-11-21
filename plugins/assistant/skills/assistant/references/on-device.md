# On-device tests

Read before you run a project's on-device tests.

- Before a run, confirm the device is unlocked and set to never sleep: a locked screen hangs the tests, or fails them without an error.
- First find out what the command does to the installed app and its data: an integration test may uninstall the app and clear its data. Ask before running on the user's own phone, as a `Needs you`; the platform waits, named, until the user answers.
- Before a run, state how long it is expected to take. Past that time, report it, and first check whether the run is stuck; never treat it as just slow.
- After the run, restore every state it changed: paid features first, then settings and test accounts. Confirm by reading the actual state, not the exit code.
- Create the data the tests need yourself, with fixtures or a seed; never ask the user to prepare it.
- An agent running tests never triggers a paid request, such as a real purchase or a paid API.
- "Tested on device" means operating the real app on the device; a widget test does not count.
- A full disk can produce a build that reports success but is the old version. Before calling what the device shows a defect, run `df`.
