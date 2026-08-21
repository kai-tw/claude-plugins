---
category: report
source: founder
date: 2026-08-21
title: ended the turn on announcing the next step instead of taking it
---

Measured across three cycles: 24 / 97 / 68 human turns, of which 6 / 11 / 10
carried no information at all —「請繼續」「接著跑」「開始吧」. Twenty-seven
turns spent pushing.

Reading what preceded each one, the stopping points share no boundary. They are
a plan revision, wiring a seam, a DI swap, a commit. What they share is the
SHAPE of the last sentence:

    下一步是寫 Rev 14 ——⋯
    我接著把這條 seam 實際接起來⋯
    renderer 側完成。現在接 Dart 側。
    Now the swap itself. Writing the DI registration first.
    接下來是真正的置換，我會一路做完再回報

The last one promised not to stop, and stopped in the same turn — verified: no
tool call follows it, the next entry is the user's.

So the cause is not a boundary the flow will not cross. Announcing the next step
reads as a finished unit of communication, and the turn ends there. Saying it
gets mistaken for delivering it.

Rule this points at: **a turn may not end on "next is X".** Either take X and
report, or say what is missing and who must supply it. An announcement is not a
deliverable.

Silent in the usual way — nothing errors, it just costs another round-trip, and
the cost lands entirely on the reader.
