# User-visible text — Traditional Chinese (Taiwan) locale layer

Loads when: `locales` includes zh-Hant or a locale tag that mirrors it. Every item must
attach to an existing `U<N>` of the charter; one that cannot must first amend the base
law (`CONVENTIONS.md`).

## U1 — How a string is written is decided by where it renders

- **U1.1-zhHant Full sentences end with 「。」; labels take no ending punctuation** —
  Check: Where the value is a full sentence, does it end with 「。」? Where it is a label,
  button, title or field name, does it carry no ending punctuation? Swapping the two
  violates this rule.
- **U1.2-zhHant Labels are noun phrases or verb-object phrases** — Check: Is the label a
  phrase like 「儲存空間不足」 「新增書籍」, not a sentence with both subject and predicate?
  Written as a full sentence, it violates charter U1.1.

## U2 — A failure message must state what happened, the current state, and the next step

- **U2.1-zhHant Failure sentences run: what happened, current state, 「請」 next step** —
  Check: Does the failure sentence open with 「<動作>失敗」 or 「無法<動作>」, give the
  current state or cause in the middle, and end with 「請<動詞>」? The three parts are
  joined by full-width commas and end with a full stop. Example:
  「登出失敗，目前仍在登入狀態，請再試一次。」

## U3 — Each locale is written natively

- **U3.1-zhHant Requests open with 「請」; state sentences must not** — Check: Where the
  sentence asks the user to act, does it open with 「請」 plus a verb? Prefixing 「請」 to a
  mere state report violates charter U1.2.
- **U3.2-zhHant No source-language word-order markers** — Check: Does the sentence contain
  transcription traces such as 「被…所」「一個…的」「對…進行」「做出…的動作」「這是一個…」?
  Where it does, it violates charter U3.1; rewrite it in natural Chinese word order.
- **U3.3-zhHant Unfinished is spelled out with a resultative complement** — Check: Where an
  action has begun but not finished, is it written 「還沒…完」「沒有…完成」 rather than
  「還沒…」? Chinese marks completion with a resultative complement; leaving it out states
  the progress as zero, violating charter U3.6. Example: halfway through an upload, write
  「檔案還沒上傳完」; 「檔案還沒上傳」 reads as not a single file sent.
- **U3.4-zhHant A verb's object must not be left for the user to fill in** — Check: Is the
  object the verb needs written out? Omitting it violates charter U3.5. Example:
  「連上網路後會繼續上傳」, not 「連上網路後會繼續」.
- **U3.5-zhHant One thing per sentence; clauses on one topic stay adjacent** — Check: Does
  the value cram two unrelated things into one sentence, or split clauses on one topic
  between the start and end of the sentence? Where it does, it violates charter U3.2.
  Example: 「儲存空間不足，檔案沒有存進去。請先清出空間再試一次。」 — state and cause in
  one sentence, the next step in its own.

## U4 — One concept, one word across the app

- **U4.1-zhHant Quote another screen's label in 「」** — Check: When the sentence cites
  another screen, setting or tab by name, does it use that screen's label in this locale
  verbatim, enclosed in 「」? Example: 「請從「探索」重新嘗試。」
