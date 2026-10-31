# Usage data — the project's analytics events in BigQuery

Load when the founder asks what users do (which feature is used, adoption,
retention), or when a design hinges on how often a case happens and neither the
code nor Scout can show it.

The adapter's `analytics:` names the GCP project the Firebase / GA4 daily export
lands in (Firebase → Project settings → Integrations → BigQuery). `asst-analytics`
reads it: `events` for every event's counts, `params <event>` for its parameter
values, `sql` for anything else. Every query is capped at 1 GB billed.

- What the app sends is in the code: the event names and parameters its analytics
  layer defines. What arrives is `asst-analytics events`. Compare the two first: an
  event the code sends that never arrives, or a parameter value the code can't
  produce, is a bug to file, not low adoption.
- Traffic is low: read 28- and 90-day windows (`--days 90`), never 7 alone, and
  say how many users each number rests on.
- Firebase's own events (`first_open`, `session_start`, `screen_view`,
  `user_engagement`, `app_remove`, …) are context, not features.
- Signals worth a row: a shipped feature's events at zero or falling over 90 days;
  a step of a flow most users who start it never reach; a parameter value the
  code can't produce.
- Numbers point a direction and never decide: each finding the founder should act
  on becomes one Backlog row, `asst-board create <slug> Name=… Status=Backlog
  Stage="Product Plan" --body <file>` (on Notion with `"Pages=<page>,…"`), its body
  holding the numbers, the window, the query and the fork it raises.
