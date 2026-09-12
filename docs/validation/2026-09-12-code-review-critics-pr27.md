# Validation: two-stage code review (challenger → verifier) against CherishCRM-Flutter PR #27

Branch under test: `code-review-critics` in `kai-tw/claude-plugins`
(`plugins/plan-cycle/agents/code-reviewer.md` + `code-review-verifier.md` +
`plugins/plan-cycle/skills/review/references/evidence.md`), commit
`b9a186b626e8ca6cc8a8a64a1e1c89f8b47dd783`.

Target: `kai-tw/CherishCRM-Flutter` PR #27 ("Adopt ui_kit's
CommonBadge/CommonNavTile/info-error-loading family/CommonDeleteDialog"),
squash-merged as `62b833ae0b9a467262239c2e2d0edbcc5f0a67b8`, parent
`6493f9c4914072839d017ca2760af596febd137d`. The PR's diff (39 files,
+190/−517, matching the PR description exactly) was applied as uncommitted
changes on top of the parent commit (`git diff <parent> <merge> | git apply`),
in a fresh clone at `/tmp/.../scratchpad/cherish-pr27`, isolated from this
session's own CherishCRM-Flutter working tree.

Both stages ran as fresh `general-purpose` agents on `model: opus`, cwd-pinned
to that checkout, given the full agent-definition text (frontmatter stripped,
`${CLAUDE_PLUGIN_ROOT}` substituted) verbatim as their prompt, with "Do not
edit any file." prepended. The verifier's prompt appended the challenger's
raw output verbatim, with no summary or opinion added.

**`git status` in the CherishCRM checkout was identical (same 39-line
listing, same content hash) before stage 1, after stage 1, and after stage
2. Neither agent edited any file.**

---

## 1. Diff size and tier

39 files changed (+190/−517): 36 `lib/` files (5 deletions), `pubspec.yaml`,
`pubspec.lock`, `.claude/rules/design-system.md`.

The challenger classified it **Structural** — "new package dependency edge
`package:ui_kit` v1.0.6→v1.1.0 across 36 files, 5 shared widgets deleted, 4
delete-confirmation flows rewired, a rule file rewritten." This matches the
rubric's own Structural criterion ("spans multiple features/layers, or is
otherwise large") and is the right call — a Localized classification would
have licensed skipping abstraction calibration and layering, and two of the
four filed findings (C2, C4) are exactly those dimensions.

## 2. Challenger

**7 challenges raised** (C1–C7): 1 proposed CRITICAL, 4 proposed WARNING, 1
proposed WARNING-with-stated-doubt, 1 無法判定.

**§Detail coverage vs. the diff, checked by hand:** I diffed the challenger's
"Detail coverage" bullets against `git diff HEAD --stat` and the hunks within
each file. Coverage was extensive — it accounted for all 5 deleted files (with
a grep proving no dangling references), all ~26 mechanical
import-swap/rename-only files as one bundled bullet, both `_handleDelete`
`try`/`catch` removals (correctly distinguishing the one that's safe because
it still `await`s from the one that isn't — C1), the pre-existing
triple-`context.pop()` and the pre-existing post-cancel-snackbar bug (flagged
as pre-existing, correctly excluded from a diff finding), and the new
`ErrorHandler.logError` call sites under a privacy lens (P-CRM1.3, correctly
finding no new egress). It missed two things the verifier's independent
coverage check later caught (see below): four small `design-system.md`
attribution/bookkeeping hunks, and the new `tooltip: '刪除任務'` string in
`task_edit_screen.dart:62`. Both are genuinely low-stakes, but the rubric's
"every changed hunk or declaration" standard is absolute, so these are real
(minor) gaps, not false negatives on my part.

**`unverified:` markers:** none. Every challenge's evidence cites a specific
grep or file read the challenger ran this session — no claim was left
unverified. (One methodological problem, not marked `unverified:` because the
challenger didn't realize it: challenge **[C6]**'s evidence [E8] reads
`/home/user/CherishCRM-Flutter/dart_lints.yaml` — the **main session
directory**, a different, much later checkout of this same repo, not the
`/tmp/.../cherish-pr27` checkout it was told to review. The two repos are at
different points in history; the checkout under test has no `dart_lints.yaml`
at all. This is a real slip — reading an absolute path outside its assigned
cwd — and it went undetected by the challenger itself. It did not corrupt the
challenge's substance ([C6]'s premise survives on the correct evidence, see
§5), but it is exactly the kind of cross-context contamination this
validation exists to catch, and it is only visible because the verifier
re-ran the check from the correct location.)

## 3. Verifier

**Counts:** 7 raised → **4 filed** (C1 CRITICAL, C2/C3/C4 WARNING) · **2
成立但不處理** (C5, C6) · **0 駁回** · **1 無法判定** (C7).

**Did it re-run searches itself?** Yes, on every filed and 成立但不處理
challenge, with results quoted inline rather than trusted from the
challenger. Its own tool calls, cited in its output:
- `[E1]` re-run: `grep -rn "CommonDeleteDialog.show" lib/` → same 4 matches,
  independently re-checked each site's `await`/no-`await` status by reading
  the call sites itself.
- `[E2]` re-run: `grep -rn "AlertDialog" lib/` → same 6 matches, independently
  re-read `sync_screen.dart:154`'s `_confirmAdopt` to confirm it's a
  destructive confirmation.
- Re-read `tag_detail_notifier.dart:40-53` directly to confirm `deleteTag` is
  `Future<void>` with no internal catch.
- Re-read the deleted `lib/shared/dialogs/common_delete_dialog.dart` via
  `git show HEAD:` to confirm it centralized the copy/icon/log call (for C3).
- Re-fetched ui_kit's `common_delete_dialog.dart` and `common_info_widget.dart`
  from the pinned git-cache ref to confirm C1's dialog-catch behavior and
  C4's `dense`-dependent `titleStyle` (matches source exactly — see §5).
- For **[C6]**, ran `grep`/read against
  `packages/cherishcrm_lints/lib/src/rules/avoid_hardcoded_color.dart` **in
  the correct checkout** — catching that the challenger's [E8] had cited the
  wrong repository's `dart_lints.yaml` — and confirmed the rule still fires
  (it flags any `Colors.*` prefixed identifier under a path containing
  `/presentation/`, no area-based allowlist in this ruleset) on the same
  underlying fact via the correct source.
- For **[C7]**, ran `which dart flutter` (exit 1, confirmed no toolchain) and
  `git ls-files | grep -i dart_lints` (0 matches in this checkout), then
  corrected the challenger's framing: this checkout's lint package is
  `packages/cherishcrm_lints` (its own `CLAUDE.md:29` documents `flutter
  analyze`), not the `dart_lints` package the challenger's evidence pointed
  at from the other checkout.

**Severities changed:** none of the 4 filed findings had their severity
changed — the challenger's proposed CRITICAL/WARNING was kept as final in
every case (C1 CRITICAL, C2/C3/C4 WARNING). No downgrade or upgrade occurred.

**Coverage gaps reported:** 2 — four `design-system.md` doc hunks
(attribution/bookkeeping edits) and the new `tooltip: '刪除任務'` in
`task_edit_screen.dart:62`, both correctly assessed as low-risk and listed
"for completeness, not as suspicion" rather than escalated.

## 4. Missing rule files

Confirmed independently: this checkout's `.claude/rules/` contains only
`architecture.md`, `design-system.md`, `privacy.md`, `security.md`. There is
no `code-style.md`, `naming.md`, `presentation.md`, `data.md`, or
`error-handling.md` — all of which the challenger definition's built-in
"severity overrides" section (chunk-header comments, CQS return type, naming
contracts) cites by name.

**The challenger self-reported this rather than waiting for the verifier**,
in its own §Detail coverage:

> "Chunk-header / phase-comment and CQS overrides → not applied: `.claude/rules/` here contains only `architecture.md`, `design-system.md`, `privacy.md`, `security.md` (`ls .claude/rules/`). There is no `code-style.md`, `naming.md` or `presentation.md` in this repo, so per the brief («If a rule isn't in those files it isn't binding») those overrides have no rule text to bind against; root `CLAUDE.md` §Code Style states neither requirement. Noting it so the absence is visible rather than silently skipped."

Because the challenger never invoked those overrides as challenges, the
verifier had no missing-rule-file rejection to make on that specific ground —
there was nothing filed against a nonexistent rule to strike down. This is
arguably the correct outcome (no wasted challenge, no wasted verification
pass) but it does mean the "rule whose file is missing was never applied →
無效" mechanic in the verifier's own instructions was never exercised by this
run. The one place the mechanic's spirit *did* fire was **[C7]**'s 無法判定,
where the verifier explicitly caught the challenger citing the wrong
checkout's lint config (see §2, §3) — the closer real-world analog of "a
rule/config that doesn't exist here."

## 5. Spot check

**Filed findings (3, of 4) — verified against the code myself, independently of both agents:**

- **C1 (CRITICAL, missing `await`)** — Read `tag_edit_screen.dart:172-180`
  directly: `_handleDelete` calls
  `ref.read(tagDetailProvider(widget.tagId).notifier).deleteTag(widget.tagId);`
  with no `await`, immediately followed by the success snackbar and two
  `context.pop()`s. Read `tag_detail_notifier.dart:40-53`: `deleteTag` is
  `Future<void> deleteTag(String id) async { ... await repository.deleteTag(id); ref.invalidate(...); }`
  with no internal try/catch — confirmed a thrown exception propagates
  uncaught to nowhere, since the caller never awaits it. Read
  `customer_edit_screen.dart` and `task_edit_screen.dart`'s diffs: both
  `await` the equivalent call. **Verdict: correct, both premise and
  severity.**
- **C2 (WARNING, stale "no exceptions" doc claim)** — Ran
  `git diff HEAD -- .claude/rules/design-system.md` myself: the removed line
  reads "⚠️ 目前不是唯一機制：`sync_screen.dart:154` 與
  `task_edit_screen.dart` 各自手刻了一個裸 `AlertDialog`..." and the added
  line reads "...目前沒有已知例外。" Read `sync_screen.dart:135-177`
  directly: `_confirmAdopt` still builds a bare `AlertDialog` with 取消/確定上傳
  actions guarding the account-adoption upload. **Verdict: correct** — the
  rule text is now factually wrong about its own codebase.
- **C3 (WARNING, duplicated delete-dialog argument shape)** — Read all four
  call sites (`customer_edit_screen.dart`, `task_edit_screen.dart`,
  `tag_edit_screen.dart`, `edit_contact_log_screen.dart`): all four pass the
  identical `cancelLabel: '取消'`, `deleteLabel: '刪除'`,
  `deleteIcon: Icons.delete_forever_rounded`, an `onError` closure calling
  `ErrorHandler.logError`, and `errorMessageBuilder: ErrorHandler.getErrorMessage`.
  Fetched ui_kit's `common_delete_dialog.dart` source: `onError` and
  `errorMessageBuilder` are both nullable/optional, and the fallback is
  literally `_errorMessage = widget.errorMessageBuilder?.call(e) ?? e.toString();`
  — confirming a 5th call site that omits the builder would leak
  `e.toString()` into the dialog. **Verdict: correct.**

**"Rejected" challenges: there were zero 駁回 (0/7).** The task asked me to
spot-check 3 rejected challenges, but the verifier rejected none outright —
every challenge's premise held; only the action-worthiness (有理) test
sorted two of them into 成立但不處理 instead of filed. I substituted those
two for the requested "rejected" slot, since they're the closest analog (a
challenge that survives verification but doesn't make the report):

- **C5 (成立但不處理 — dense-variant doc gap)** — Confirmed the deleted
  warning line (「固定 80dp 置中圖示、滿版排版...不是行內或表單內的小型提示」)
  is gone from the diff, and `grep -rn "dense:" lib/` → 0 matches (no
  call site uses the new parameter, so no live risk from the doc gap yet).
  Read `home_screen.dart:56-90` and `tag_detail_screen.dart:27-45`: both
  wrap their bodies in an ancestor `SafeArea`, so the verifier's claim that
  the injected `SafeArea` is currently a no-op holds. **Verdict: the
  not-actioned ruling is correct** — a real doc gap, but not yet a live
  defect, and "not yet exercised" is a fair reason to route it to
  成立但不處理 rather than file it.
- **C6 (成立但不處理 — hardcoded `Colors.white`)** — Read
  `packages/cherishcrm_lints/lib/src/rules/avoid_hardcoded_color.dart` myself
  (the correct checkout's actual rule source, not the challenger's
  wrong-checkout citation): `visitPrefixedIdentifier` reports on any
  `Colors.*` identifier whenever `filePath.contains('/presentation/')`, no
  area/allowlist exception. `welcome_screen.dart` is under
  `.../presentation/screens/...`, so the rule does fire on the new
  `Colors.white` literal. Confirmed the verifier's own note that the diff is
  "net-neutral on the literal" (a `fontColor: Colors.white` was removed, a
  `copyWith(color: Colors.white)` was added) is accurate by reading the
  diff. **Verdict: the not-actioned ruling is correct** — this is exactly
  the kind of finding `code-reviewer.md §Rule surface` tells the challenger
  to defer to the mechanical lint gate rather than re-litigate by hand, and
  the verifier applied that instruction correctly instead of just accepting
  or rejecting the premise.

**No finding — filed, 成立但不處理, or the C7 無法判定 — was found to be
wrong in this spot check.**

## 6. The ground-truth `await`

**Raised** (C1, by the challenger) → **filed** (by the verifier) → **at
CRITICAL**, matching the challenger's proposed severity with no downgrade.
Both agents independently reached the same conclusion a real reviewer should:
this is a data-loss-shaped bug (a delete failure reported to the user as a
success, with no log and no stale-view invalidation), traced to the exact
sibling contrast (customer/task edit screens `await`, tag edit screen
doesn't) the PR description itself doesn't mention. Neither agent's prompt
was told this was the target — the challenger found it purely from reading
the diff.

## 7. Cost

| Stage | Wall time | Tokens | Tool calls |
|---|---|---|---|
| 1 — Challenger | 12m 21s (740,679 ms) | 207,428 | 37 |
| 2 — Verifier | 8m 34s (514,046 ms) | 179,382 | 42 |
| **Total** | **20m 55s** | **386,810** | **79** |

(Sequential, not parallel — the verifier's prompt depends on the
challenger's completed output. Both figures are the agent's own
self-reported `<usage>` block from this run; they do not include the
orchestration overhead of this validation session itself: cloning both
repos, applying the diff, reading the agent definitions, and the spot-check
in §5.)

## 8. Both agents' raw outputs, verbatim

### Stage 1 — Challenger

```
Diff reviewed. Here is my challenge list.

## Challenges: CherishCRM-Flutter

**Scope:** uncommitted changes (staged + unstaged) · **Files:** 39 (37 tracked `lib/` + `pubspec.yaml`/`pubspec.lock` + `.claude/rules/design-system.md`; 5 files deleted) · **Tier:** Structural (new package dependency edge `package:ui_kit` v1.0.6→v1.1.0 across 36 files, 5 shared widgets deleted, 4 delete-confirmation flows rewired, a rule file rewritten)

---

- **[C1]** `lib/features/tag/screens/tag_edit_screen.dart:173` · Kind 2 · proposed **CRITICAL**
  claim: `_handleDelete` calls `deleteTag(...)` **without `await`**, so it returns before the delete resolves. The `onError:`/`errorMessageBuilder:` this same diff wires onto the dialog at lines 70-72 can therefore never fire for this call site, and the user is shown `'刪除標籤成功'` for a delete that failed. The three sibling call sites added by the same diff all `await` ([E1]).
  basis (failure scenario): tap 刪除 in the AppBar → dialog → tap 刪除. `_CommonDeleteDialogState._onDelete` sets `_isLoading = true` and awaits `widget.onDelete()` ([E3]). `_handleDelete` fires `deleteTag` and drops the Future, then immediately shows the success SnackBar and pops twice; the dialog then pops a third time. When `repository.deleteTag(id)` later throws ([E5] — it is `Future<void>` and propagates), the rejection lands as an unhandled zone error: `onError` never runs so **nothing reaches Crashlytics**, `errorMessageBuilder` never runs so **no inline error is shown**, and the `ref.invalidate(tagListProvider/customerListProvider/...)` calls that follow the `await` in the notifier never execute — the user is told the tag is gone while it still exists and every dependent screen keeps a stale view. `architecture.md` A6.3 (「失敗路徑是否有 UI 回饋？只 log 不提示 → warning… 這是 CRM，使用者以為存檔成功而其實沒有，代價是客戶資料遺失」) — here not even the log survives.
  evidence: read `tag_edit_screen.dart:172-180` (the whole body is `+` lines in `git diff HEAD`); read `tag_detail_notifier.dart:40-53` [E5]; read ui_kit `CommonDeleteDialog` at the pinned ref [E3]. Pre-existing note: the missing `await` also existed pre-diff, but pre-diff the enclosing `try`/`catch` was the only claimed handler and the diff both deleted it and replaced it with dialog-side handling that this call shape defeats. `unawaited_futures` is **off** in `analysis_options.yaml` [E6], so no linter catches this.

  [E1] `grep -rn "CommonDeleteDialog.show" lib/` → 4 matches
    1. `lib/features/customer/presentation/screens/customer_edit_screen.dart:69` — `onDelete: _handleDelete`, which `await`s (`customer_edit_screen.dart:312-314`)
    2. `lib/features/task/presentation/screens/task_edit_screen/task_edit_screen.dart:63` — `onDelete: _handleDelete`, which `await`s (`task_edit_screen.dart:213`)
    3. `lib/features/tag/screens/tag_edit_screen.dart:62` — `onDelete: _handleDelete`, which does **not** `await` (`tag_edit_screen.dart:173`)
    4. `lib/features/contact_log/presentation/screens/edit_contact_log_screen.dart:172` — inline closure, `await`s (`:180-182`)

  [E3] ui_kit `packages/ui_kit/lib/src/dialogs/common_delete_dialog.dart` at resolved-ref `0d1821f36250ac8246c50849a3e8b277118bb790` (the ref `pubspec.lock` pins for `ui_kit-v1.1.0`), read via `git show` in `/root/.pub-cache/git/cache/kai-packages-d74df7cd3076cdf7b2ee0147265ec6817d4a2003`. `_onDelete`: `try { await widget.onDelete(); if (mounted) Navigator.of(context).pop(); } catch (e, s) { widget.onError?.call(e, s); if (mounted) setState(() { _isLoading = false; _errorMessage = widget.errorMessageBuilder?.call(e) ?? e.toString(); }); }`

  [E5] `lib/features/tag/notifiers/tag_detail_notifier.dart:40-53` — `Future<void> deleteTag(String id) async { … await repository.deleteTag(id); ref.invalidate(tagListProvider); … }` (no internal catch)

  [E6] `analysis_options.yaml:154` — `# - unawaited_futures # too many false positives` (commented out)

---

- **[C2]** `.claude/rules/design-system.md:113` and `:150-152` · Kind 2 · proposed **WARNING**
  claim: the rewritten rule asserts 「現在全專案的刪除確認**沒有例外**都走這裡」 (:113) and 「2026-08-06 遷移前僅存的例外（`task_edit_screen.dart`）已收掉，目前沒有已知例外」 (:152). The code refutes this: `lib/features/sync/presentation/screens/sync_screen.dart:154` still hand-rolls a bare `AlertDialog` for a destructive confirmation ([E2]), and **the pre-diff revision of this very rule named that exact `file:line`** as one of two known exceptions. The diff removed the sync_screen half of that sentence while keeping and strengthening the "no exceptions" conclusion.
  basis (failure scenario): the next `code-reviewer`/`ux-reviewer` grading a diff that touches `sync_screen.dart` reads 「目前沒有已知例外」, concludes the file is compliant, and passes a real violation of §互動慣例. The action it guards is the account-adoption upload — the dialog's own doc comment says 「上傳後無法從這個 app 取回或刪除」, i.e. the S-CRM4.9 account-boundary gate, so the row that loses its documented exception status is the most consequential one in the app. Rewriting a rule to a stronger conclusion without re-walking the instances it governed is the failure mode `security.md` S-CRM6.3 already paid for (「改判準之後要重跑它管的每一個既有結論」).
  evidence: `git diff HEAD -- .claude/rules/design-system.md` shows the removed line 「⚠️ 目前不是唯一機制：`sync_screen.dart:154` 與 `task_edit_screen.dart` 各自手刻了一個裸 `AlertDialog` 做同等級的確認」; read `sync_screen.dart:135-177` — `_confirmAdopt` builds `AlertDialog(title: Text('要把資料上傳到這個帳號嗎？'), … actions: TextButton('取消') / TextButton('確定上傳'))`.

  [E2] `grep -rn "AlertDialog" lib/ | grep -v ui_kit` → 6 matches
    1. `lib/shared/dialogs/common_color_picker_dialog.dart:48` — colour picker, not a destructive confirmation
    2. `lib/features/task/presentation/dialog/task_notification_picker_dialog.dart:48` — picker
    3. `lib/features/sync/presentation/screens/sync_screen.dart:154` — **destructive confirmation** (account adoption upload)
    4. `lib/features/contact_log/presentation/dialogs/post_contact_confirmation_dialog.dart:18` — non-destructive prompt
    5. `lib/features/contact_log/presentation/dialogs/task_selector_dialog.dart:43` — picker
    6. `lib/features/contact_log/presentation/screens/create_contact_log_screen.dart:158` — prompt

---

- **[C3]** `lib/features/customer/presentation/screens/customer_edit_screen.dart:69-79`, `lib/features/task/…/task_edit_screen.dart:63-74`, `lib/features/tag/screens/tag_edit_screen.dart:62-73`, `lib/features/contact_log/…/edit_contact_log_screen.dart:172-186` · Kind 2 · proposed **WARNING**
  claim: six arguments that are a project-wide invariant — `cancelLabel: '取消'`, `deleteLabel: '刪除'`, `deleteIcon: Icons.delete_forever_rounded`, `onError: → ErrorHandler.logError`, `errorMessageBuilder: ErrorHandler.getErrorMessage` — are now retyped verbatim at all four call sites ([E1]), enforced only by a Markdown sentence in `design-system.md:113` (「CherishCRM 慣例固定傳 `'取消'`／`'刪除'`」). DRY: the same shape is duplicated across four files today.
  basis (maintainability counterexample): the deleted `lib/shared/dialogs/common_delete_dialog.dart` owned the copy, the icon **and** the `ErrorHandler.logError` call in one place — one file to change, and no way to forget the log. After this diff a fifth delete site that omits `onError:` silently logs nothing at all on failure (ui_kit's `onError` is optional, [E3]), and a site that omits `errorMessageBuilder:` falls back to ui_kit's `e.toString()` default [E3] — which renders the raw exception text into the dialog for the user, a channel `ErrorHandler.getErrorMessage` deliberately closes in release builds (`error_handler.dart:24-26` returns the generic 「發生錯誤，請稍後再試一次。」 outside `kDebugMode`). Neither omission is caught by any type, any lint, or any test.
  evidence: [E1]; [E3]; read `lib/core/errors/error_handler.dart:17-27`; read the deleted `lib/shared/dialogs/common_delete_dialog.dart` from `git show HEAD:` (its `_onDelete` catch called `ErrorHandler.logError(e, stackTrace: s)` once, centrally). Possible false positive: this is the shape ui_kit's README §Text ownership intends (the package ships no copy), so the duplication may be a deliberate accepted cost of the shared-package split — but nothing in the repo records that trade, only the doc sentence.

---

- **[C4]** `lib/features/home/presentation/screens/welcome_screen/welcome_screen.dart:264-279` · Kind 2 · proposed **WARNING**
  claim: the white-on-scrim title is achieved by overriding `textTheme.titleMedium` in a scoped `Theme`. That works only because ui_kit's `CommonInfoWidget` happens to render its title with `textTheme.titleMedium` **in the non-dense branch only** ([E4]) — an internal choice of a git-pinned third-party package that nothing in this repo's types, tests or call signature encodes.
  basis (maintainability counterexample): (a) adding `dense: true` to that same widget — the variant this diff's own doc introduces at `design-system.md:108` — switches the title style to `textTheme.bodyMedium` ([E4]), so the override silently stops applying and dark text lands on a `Colors.black.withValues(alpha: 0.4)` scrim over a photo, i.e. unreadable, with no compile error and no test; (b) the same happens on any future `ui_kit` bump that re-roles the title. The in-code comment at `:262-265` documents *why* a `Theme` is used but not *which* text role the override has to name, so a reader has no signal that the two must stay in sync.
  evidence: read `welcome_screen.dart:255-283`; [E4].

  [E4] ui_kit `packages/ui_kit/lib/src/info/common_info_widget.dart` at ref `0d1821f…` — `final TextStyle? titleStyle = dense ? textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant) : textTheme.titleMedium;`

---

- **[C5]** `.claude/rules/design-system.md:108` · Kind 2 · proposed **WARNING** (doubt stated below)
  claim: the rewritten `CommonInfoWidget` row introduces `dense` as 「行內小尺寸變體，先前沒有」 but states no rule for choosing between the two, and it **deletes** the operative selection warning the pre-diff row carried: 「⚠️ **固定 80dp 置中圖示、滿版排版**——是給空/錯誤等**整頁或整區塊**狀態用的，不是行內或表單內的小型提示」. The row also omits three behaviour changes that hit all ten migrated call sites ([E7]): the icon shrank 80dp → 48dp, the title moved from `bodyLarge`/`colorScheme.outline` to `titleMedium`/default `onSurface`, and the non-dense variant now injects a `SafeArea` + 24px horizontal `Padding` that the deleted local widget never had ([E4], and `git show HEAD:lib/shared/widgets/common_info_widget.dart`).
  basis (maintainability counterexample): `design-system.md:8` states the file's contract as 「只記錄實際存在於程式碼裡的規範」 and it is the artifact `designer`/`ux-reviewer` grade against. With the "not for inline hints" line gone and no replacement, the next editor placing a placeholder inside a form row or a card has nothing in the doc telling them which variant that is; zero call sites pass `dense` today [E7], so the codebase offers no precedent either.
  doubt: no runtime break is demonstrated — every current call site is either full-page or already inside an ancestor `SafeArea` (`home_screen.dart:59` wraps the four tabs; `tag_detail_screen.dart:42` and `task_edit_screen.dart:82` wrap their bodies), so the injected `SafeArea` is a no-op at the sites I traced. This is a documentation-completeness challenge, not a defect claim, and I could not construct a failing render.
  evidence: `git diff HEAD -- .claude/rules/design-system.md`; [E4]; [E7]; read `home_screen.dart:56-90`, `tag_detail_screen.dart:27-45`, `task_edit_screen.dart:82`.

  [E7] `grep -rn "dense:" lib/` → 0 matches. `grep -rn "CommonInfoWidget(" lib/` → 10 matches: `customer_empty_widget.dart:15`, `kanban_column.dart:87`, `task_list_screen_list_view.dart:46`, `welcome_screen.dart:273`, `tag_picker_dialog.dart:67`, `tag_template_screen.dart:48`, `tag_list_screen.dart:38`, `tag_detail_screen.dart:89`, `tag_detail_screen.dart:134`, `contact_log_list_screen.dart:155`.

---

- **[C6]** `lib/features/home/presentation/screens/welcome_screen/welcome_screen.dart:270` · Kind 1 · proposed **WARNING** (doubt stated below)
  claim: the new `Theme` override adds a hardcoded `Colors.white` literal (`…textTheme.titleMedium?.copyWith(color: Colors.white)`). `design-system.md:36` states 「**永遠引用角色名，不得寫死 hex 或 `Colors.*`**」, and `dart_lints.yaml` runs `avoid_hardcoded_color` tree-wide — the `production` area (`paths: ["lib/**"]`) carries no `disable`, and only `theme_palette` (two theme files) and `test` opt out ([E8]).
  basis: `.claude/rules/design-system.md:36`; `dart_lints.yaml` §areas + the trailing comment 「`avoid_hardcoded_color` keeps其 default empty `pathMarkers`, so it runs over the whole tree」.
  doubt / possible false positive, stated plainly: (a) this is a **mechanical** rule the lint gate owns, and I could not run it — see [C7]; (b) the diff is close to net-neutral on literals here, removing `fontColor: Colors.white` and adding one in the `copyWith`, while `iconColor: Colors.white` on the same widget is untouched and pre-existing; (c) `design-system.md:36` itself records 「`Colors.*` 目前仍有 25 處既有違規」, so the rule is evidently not currently blocking. What makes it worth raising anyway rather than dropping: the same commit edits `design-system.md:108` to point at this exact file as the sanctioned pattern (「見 `welcome_screen.dart` 的用法」), which is a rule-boundary move rather than a code change and is the one route lint cannot see.
  evidence: read `welcome_screen.dart:262-279`; read `/home/user/CherishCRM-Flutter/dart_lints.yaml` in full [E8]; read `.claude/rules/design-system.md:36`.

  [E8] `dart_lints.yaml` areas that `disable: avoid_hardcoded_color` → 2 of 7
    1. `theme_palette` (`lib/shared/theme/app_default_theme.dart`, `lib/shared/theme/app_semantic_colors.dart`)
    2. `test` (`test/**`)
    — `production` (`lib/**`), `database_boundary`, `validators_toolbox`, `integration_test`, `design_mockups` do not.

---

- **[C7]** repo-wide · Kind 2 · **無法判定** (not a severity — reporting the gap)
  claim: I could not run the project's lint gate, so the entire mechanical bucket for this diff is unchecked by me. `which dart flutter` returns nothing in this environment [E9], and `dart_lints.yaml` is not present in this checkout at all — it exists only at `/home/user/CherishCRM-Flutter/dart_lints.yaml` and `git ls-files` in the checkout lists no such tracked path, so even with a toolchain the bare `dart run dart_lints` invocation CLAUDE.md mandates would not resolve its config here.
  what it does not settle: `avoid_hardcoded_color` on [C6]; `directives_ordering` / `prefer_const_constructors` / `always_specify_types` across the 36 files whose import blocks changed; `avoid_unsafe_log_interpolation` on the four new `ErrorHandler.logError` call sites; whether `dart run build_runner build` is still needed (no annotated source changed, but `home_screen_notifier.dart` did).
  who closes it: the author, by running `dart run dart_lints` (bare, no paths) from the repo root per CLAUDE.md 「The lint gate is `dart_lints`, never `flutter analyze`」, and CI.
  evidence: [E9]; `git ls-files | grep -i "dart_lints"` → 0 matches in this checkout.

  [E9] `which dart flutter` → empty; `dart run dart_lints` → `timeout: failed to run command 'dart': No such file or directory`

---

### Detail coverage

- `pubspec.yaml:53` (`ui_kit-v1.0.6` → `ui_kit-v1.1.0`) + `pubspec.lock` (`resolved-ref` `1dbfb5a…` → `0d1821f…`, `loading_animation_widget 1.3.0` added transitive) → no challenge: lock and manifest agree, the ref resolves to a real commit whose `pubspec.yaml` reads `version: 1.1.0`, and the new transitive dep is a direct dependency of that package version. Pinning a git dependency by tag is the repo's existing convention for all `kai-tw` packages.
- `lib/shared/widgets/common_info_widget.dart`, `common_nav_tile.dart`, `common_badge.dart`, `lib/shared/dialogs/common_info_dialog.dart`, `common_loading_dialog.dart` (all deleted) → no challenge: no dangling references remain. `grep -rn "common_info_widget|common_nav_tile|common_badge|common_info_dialog|common_loading_dialog|common_delete_dialog" lib/ test/ tool/` → 0 matches; `grep -rn "CommonInfoDialog|CommonLoadingDialog|CommonInfoWidget\.|CommonNavTileType" lib/ test/` → 0 matches.
- `CommonInfoWidget.error(message:)` → `CommonErrorWidget(content:)` at 16 sites (`customer_picker_dialog.dart:196`, `common_error_screen.dart:28`, `customer_list_screen.dart:90`, `customer_edit_screen.dart:101`, `customer_detail_screen.dart:323`, `task_list_screen_kanban.dart:59`, `task_list_screen_list_view.dart:94`, `task_detail_screen.dart:299`, `task_edit_screen.dart:148`, `home_screen.dart:77`, `welcome_screen.dart:288`, `tag_template_screen.dart:97`, `tag_detail_screen.dart:160`, `edit_contact_log_screen.dart:107`, `contact_log_detail_screen.dart:214`, `contact_log_list_screen.dart:187`) → C5 (doc), otherwise no challenge: every one passes `ErrorHandler.getErrorMessage(error)` or an equivalent literal, which is exactly what `design-system.md:109` requires, and `CommonErrorWidget` supplies the `error`-role icon colour itself [E4].
- `iconData:`/`message:` → `icon:`/`title:` at 10 `CommonInfoWidget` sites [E7] → C5, otherwise no challenge: mechanical rename, semantics preserved.
- `CommonNavTile(type: CommonNavTileType.internal, …)` → `CommonNavTile.internal(…)` at 6 sites (`profile_screen.dart:69,74,79,84`, `tag_list_screen.dart:59`, `tag_create_screen.dart:91`) → no challenge: the ui_kit named constructors take the identical parameter set including `iconBadgeType`, and the enum-to-constructor move removes an impossible-state axis rather than adding one.
- `profile_screen.dart:84` — `CommonNavTile.internal` on 匯出資料, which opens the OS share sheet rather than navigating → no challenge: pre-existing (the diff only changes the constructor form), and `design-system.md`'s "only promises navigation" caveat predates it.
- `home_screen_notifier.dart:2` / `home_screen_state.dart:2` — a `@riverpod` notifier and its Equatable state now import `package:ui_kit/ui_kit.dart` for `CommonBadgeType` → no challenge: pre-existing shape (both previously imported `shared/widgets/common_badge.dart`); `architecture.md` A3 scopes to `lib/shared/` importing entities/providers, not presentation state importing a UI enum.
- `common_info_tile.dart:2`, `common_square_icon_button.dart:2`, `customer_summary_tile.dart:3` — `lib/shared/` now imports `package:ui_kit` → no challenge: a downward edge to a leaf UI package, no entity or provider crosses it (`architecture.md` A3).
- `customer_edit_screen.dart:309` and `task_edit_screen.dart:212` — `CommonLoadingDialog.show(context)` removed from `_handleDelete` → no challenge, this is a fix: the old call opened a second modal on top of the confirm dialog (violating `design-system.md` §互動慣例 「一次只開一層 modal」) and never popped it. ui_kit's dialog now shows the in-flight spinner on the delete button itself [E3].
- `task_edit_screen.dart:212-221` — `_handleDelete` loses its `try`/`catch` and now lets the error reach the dialog → no challenge: it `await`s, so the ui_kit error path genuinely fires; the removed `catch (e, s)` was also an `avoid_bare_catch` instance, so this is a net improvement. (Contrast [C1], where the same removal is not backed by an `await`.)
- `task_edit_screen.dart:209-234` (deleted `_showConfirmDeletionDialog`) → no challenge: this was the technical debt `design-system.md` named, and it is genuinely gone.
- `edit_contact_log_screen.dart:188-191` — `if (context.mounted) { showSuccessSnackBar('聯絡記錄已刪除'); context.go('/home'); }` runs after `show()` resolves, i.e. also when the user pressed 取消 → no challenge **as a diff finding**: verified byte-identical pre-diff via `git show HEAD:…` (only the argument list changed). Flagging as pre-existing so it is not lost — it is the same false-success class as [C1].
- `tag_edit_screen.dart:177-178` — two `context.pop()` followed by ui_kit's own `Navigator.of(context).pop()` [E3] = three pops for one delete → no challenge: verified pre-diff via `git show HEAD:…`, the deleted local dialog also popped after `await widget.onDelete()`. Pre-existing, unchanged count.
- Four new `ErrorHandler.logError(error, stackTrace: stackTrace)` call sites (`edit_contact_log_screen.dart:184`, `customer_edit_screen.dart:76`, `tag_edit_screen.dart:71`, `task_edit_screen.dart:72`) → no challenge under `privacy.md` P-CRM1.3: net egress is unchanged, not new. The deleted `lib/shared/dialogs/common_delete_dialog.dart` already called `ErrorHandler.logError(e, stackTrace: s)` for the same failures, and `task_edit_screen`'s old catch did too — the log point moved from one shared place to four call sites (which is the [C3] concern), it did not appear. `error_handler.dart:62-70` builds its message from `getErrorMessage`, which returns a fixed literal outside `kDebugMode`, so P-CRM1.1 (string-literal message) still holds.
- `errorMessageBuilder: ErrorHandler.getErrorMessage` at all four sites → no challenge: the ui_kit default would render `e.toString()` into the dialog; every call site overrides it with the release-safe generic string. (The consequence of *omitting* it is [C3].)
- `.claude/rules/design-system.md:97-115` — new 「來自 `package:ui_kit`」 table incl. `CommonSuccessDialog` / `CommonProgressDialog` rows with zero callers in this repo → no challenge: a component catalogue documenting a shared package's surface is not over-abstraction in this codebase; no code was added for them.
- `.claude/rules/design-system.md:130` — new note that `CommonHeadlineText`/`CommonTitleText` are near-duplicates and out of scope → no challenge: an honest, scoped debt record, no code change attached.
- `welcome_screen.dart:262-265` — new explanatory comment → C4.
- `contact_log_detail_screen.dart`, `contact_log_list_screen.dart`, `customer_detail_screen.dart`, `customer_list_screen.dart`, `customer_list_app_bar.dart`, `customer_empty_widget.dart`, `task_list_app_bar.dart`, `task_list_screen_kanban.dart`, `task_list_screen_list_view.dart`, `kanban_column.dart`, `tag_picker_dialog.dart`, `tag_template_screen.dart`, `tag_list_screen.dart`, `tag_detail_screen.dart`, `common_error_screen.dart`, `customer_picker_dialog.dart` — import-swap + parameter-rename only → no challenge: each removes exactly the deleted local import and adds `package:ui_kit/ui_kit.dart` in alphabetical position among package imports; no behaviour beyond the widget substitution already covered above. (`directives_ordering` is the analyzer's call — see [C7].)
- Chunk-header / phase-comment and CQS overrides → not applied: `.claude/rules/` here contains only `architecture.md`, `design-system.md`, `privacy.md`, `security.md` (`ls .claude/rules/`). There is no `code-style.md`, `naming.md` or `presentation.md` in this repo, so per the brief («If a rule isn't in those files it isn't binding») those overrides have no rule text to bind against; root `CLAUDE.md` §Code Style states neither requirement. Noting it so the absence is visible rather than silently skipped.

coverage: time=pass（無演算法或迴圈變更，全為 widget 替換與參數改名） · space=pass · scalability=na（diff 未觸及任何集合處理或資料路徑） · extendability=finding（C3、C5） · coupling=finding（C4；新增的 edge 全是 `lib/features`、`lib/shared` → `package:ui_kit` 葉節點，方向合規） · correctness=finding（C1） · error-handling=finding（C1、C3） · testability=na（此 repo 無任何 widget-test seam 可延伸：`grep -rln "testWidgets" test/` → 0 命中，`test/widget/customer_card_test.dart` 為 1-byte 空檔；29 個測試檔全為 DAO／sync／core 單元測試） · startup=pass（`main.dart`、provider 初始化、`LogSystem.init` 皆未變動）
```

### Stage 2 — Verifier

```
## Code Review: CherishCRM-Flutter

**Scope:** uncommitted changes (staged + unstaged) · **Files reviewed:** 39 (37 tracked `lib/` incl. 5 deletions, `pubspec.yaml`/`pubspec.lock`, `.claude/rules/design-system.md`)
**Challenges:** 7 raised → 4 filed · 2 成立但不處理 · 0 駁回 · 1 無法判定

### CRITICAL

- **[C1]** `lib/features/tag/screens/tag_edit_screen.dart:172-180` — `_handleDelete` drops the `Future` from `deleteTag(...)`, then unconditionally shows `'刪除標籤成功'` and pops twice. Verified: `tag_detail_notifier.dart:40-53` `deleteTag` is `Future<void>` with no internal catch, and `repository.deleteTag(id)` propagates. On failure the rejection becomes an unhandled zone error — the `onError:`/`errorMessageBuilder:` this same diff wires at `:70-72` are re-entered through the dialog's `catch` (verified in ui_kit `common_delete_dialog.dart` `_onDelete`) and therefore **never fire for the async path**: nothing is logged, nothing is shown, and the user is told a tag was deleted that still exists. `architecture.md` A6.3 exists in this checkout and its rationale names exactly this ("使用者以為存檔成功而其實沒有"); here it is worse than the rule's warning case, because not even the log survives.
  ```dart
  Future<void> _handleDelete() async {
    ref.read(tagDetailProvider(widget.tagId).notifier).deleteTag(widget.tagId);

    if (mounted) {
      ErrorHandler.showSuccessSnackBar(context, '刪除標籤成功');
  ```
  (proposed CRITICAL → **CRITICAL**. Scope note, stated so the caller is not misled: the missing `await` also existed pre-diff, so this is not a runtime regression. It is filed anyway because the whole body is `+` lines the author just wrote, the three sibling call sites the *same* diff created all `await` ([E1]), and the diff newly attaches error-handling hooks at this one site that its call shape defeats. `unawaited_futures` is commented out at `analysis_options.yaml:138`, and no rule in `packages/cherishcrm_lints` catches a dropped future, so nothing mechanical covers it.)

  [E1] `grep -rn "CommonDeleteDialog.show" lib/` → 4 matches, re-run by me
    1. `customer_edit_screen.dart:69` → `_handleDelete` at `:311-314` — `await`s
    2. `task_edit_screen.dart:63` → `_handleDelete` at `:212` — `await`s
    3. `tag_edit_screen.dart:62` → `_handleDelete` at `:173` — **does not** `await`
    4. `edit_contact_log_screen.dart:172` → inline closure at `:180-183` — `await`s

### WARNING

- **[C2]** `.claude/rules/design-system.md:150-152` (and the same conclusion at `:113`) — the rewritten 互動慣例 bullet asserts 「2026-08-06 遷移前僅存的例外（`task_edit_screen.dart`）已收掉，目前沒有已知例外」. Refuted in-tree: `sync_screen.dart:154` still hand-rolls a bare `AlertDialog` for a destructive confirmation ([E2]), and the line the diff **deleted** named that exact `file:line` as one of *two* known exceptions. The diff dropped the sync_screen half and kept the conclusion. The action it guards is the account-adoption upload — its own doc comment says 「上傳後無法從這個 app 取回或刪除」, i.e. the `security.md` S-CRM4.9 gate — so the row that silently lost its documented-exception status is the most consequential one. `design-system.md:8` binds this file to 「只記錄實際存在於程式碼裡的規範」, and it is the artifact `designer`/`ux-reviewer` grade against, so the next review of a `sync_screen.dart` diff will read "no known exceptions" and pass a real violation. (`:113`'s narrower 「刪除確認」 wording is literally defensible — sync's dialog confirms an upload, not a delete — but `:150-152` scopes to 危險動作, which the deleted line itself classified sync_screen as.)

  [E2] `grep -rn "AlertDialog" lib/` → 6 matches, re-run by me
    1. `lib/shared/dialogs/common_color_picker_dialog.dart:48` — picker
    2. `lib/features/task/presentation/dialog/task_notification_picker_dialog.dart:48` — picker
    3. `lib/features/sync/presentation/screens/sync_screen.dart:154` — **destructive confirmation** (`_confirmAdopt`, 取消／確定上傳)
    4. `lib/features/contact_log/presentation/dialogs/post_contact_confirmation_dialog.dart:18` — non-destructive prompt
    5. `lib/features/contact_log/presentation/dialogs/task_selector_dialog.dart:43` — picker
    6. `lib/features/contact_log/presentation/screens/create_contact_log_screen.dart:158` — prompt

- **[C3]** `customer_edit_screen.dart:69-79`, `task_edit_screen.dart:63-74`, `tag_edit_screen.dart:62-73`, `edit_contact_log_screen.dart:172-186` — six arguments that are a project-wide invariant (`cancelLabel: '取消'`, `deleteLabel: '刪除'`, `deleteIcon: Icons.delete_forever_rounded`, `onError: → ErrorHandler.logError`, `errorMessageBuilder: ErrorHandler.getErrorMessage`) are now retyped verbatim at all four call sites, enforced only by a prose sentence at `design-system.md:113`. Verified against the deleted `lib/shared/dialogs/common_delete_dialog.dart` (`git show HEAD:`): it owned the copy, the icon **and** the single `ErrorHandler.logError(e, stackTrace: s)` call. In ui_kit both hooks are optional (`onError`, `errorMessageBuilder` nullable), so a fifth delete site that omits `onError:` logs nothing at all on failure, and one that omits `errorMessageBuilder:` falls back to ui_kit's `e.toString()` — rendering raw exception text into the dialog, the channel `error_handler.dart:17-27` deliberately closes outside `kDebugMode` (returns the fixed 「發生錯誤，請稍後再試一次。」). Neither omission is caught by a type, a lint, or a test. This may be the intended cost of the shared-package split (ui_kit ships no copy by design), but nothing in the repo records that trade.

- **[C4]** `lib/features/home/presentation/screens/welcome_screen/welcome_screen.dart:262-279` — the white-on-scrim title works only because ui_kit renders `CommonInfoWidget`'s title with `textTheme.titleMedium` **in the non-dense branch only** ([E4]) — an internal choice of a git-pinned package that nothing in this repo's types, tests or call signature encodes. Adding `dense: true` — the variant this diff's own doc introduces at `design-system.md:108` — re-roles the title to `bodyMedium.copyWith(color: colorScheme.onSurfaceVariant)`, so the override silently stops applying and dark text lands on a `Colors.black.withValues(alpha: 0.4)` scrim over a photo, with no compile error and no test. Same on any `ui_kit` bump that re-roles the title. The new comment at `:260-263` explains *why* a scoped `Theme` is used but not that the role it names must track ui_kit's internal choice.

  [E4] ui_kit `packages/ui_kit/lib/src/info/common_info_widget.dart` @ `0d1821f36250ac8246c50849a3e8b277118bb790` (the ref `pubspec.lock` pins for `ui_kit-v1.1.0`), read via `git show` in `/root/.pub-cache/git/cache/kai-packages-d74df7cd3076cdf7b2ee0147265ec6817d4a2003`:
  `final TextStyle? titleStyle = dense ? textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant) : textTheme.titleMedium;` — plus `iconSize = dense ? 20.0 : 48.0` and a `SafeArea` + 24px horizontal `Padding` wrapper in the non-dense branch only.

### 無法判定

- **[C7]** repo-wide — the mechanical bucket for this diff is unchecked. Confirmed: `which dart flutter` → exit 1, no toolchain in this environment. Correcting the challenger's framing: this checkout (at `6493f9c`) carries the custom rules as `packages/cherishcrm_lints` (bin `cherishcrm_lints.dart`, zone-based path selection in `lib/src/zone.dart`), not as `dart_lints` — `git ls-files | grep -i dart_lints` → 0 matches here, and this checkout's own `CLAUDE.md:29` documents `flutter analyze`, while the main tree at `/home/user/CherishCRM-Flutter` has both `dart_lints.yaml` and the `dart run dart_lints` mandate. Either way nothing could be run. **Not settled:** `avoid_hardcoded_color` on [C6]; `directives_ordering` / `always_specify_types` / `prefer_const_constructors` across the 36 files whose import blocks changed; whether `dart run build_runner build` is needed after the `home_screen_notifier.dart` edit (no annotation changed, but the file did). **Closed by** the author running the project's bare lint gate from the repo root, and CI.

### 成立但不處理

- **[C5]** `.claude/rules/design-system.md:108` — the premise holds: the pre-diff row's operative line 「⚠️ 固定 80dp 置中圖示、滿版排版……不是行內或表單內的小型提示」 is gone, the 80dp→48dp / `bodyLarge`+`outline`→`titleMedium`+`onSurface` / injected `SafeArea`+24px deltas are unrecorded, and `grep -rn "dense:" lib/` → 0 matches, so there is no in-tree precedent either. Not actioned: the deleted warning's premise (one full-page-only variant) no longer holds, and the replacement text names `dense` as 「行內小尺寸變體」, which carries the same selection signal in shorter form; ui_kit's own class doc states both variants' intent explicitly; the column is declared 「建構參數（節錄）」, so visual deltas are outside its shape; and the challenger constructed no failing render — I confirmed the ancestor `SafeArea`s at `home_screen.dart:59` and `tag_detail_screen.dart:42`, which `MediaQuery`-strip the injected one at the sites I traced.
- **[C6]** `welcome_screen.dart:270` — the premise holds: `Colors.white` is on a `+` line, `design-system.md:34-36` and `CLAUDE.md:107` both forbid it, and I verified `packages/cherishcrm_lints/lib/src/rules/avoid_hardcoded_color.dart` flags any `Colors.*` in a path containing `/presentation/`, so it does fire here. (The challenger's [E8] describes the main tree's `dart_lints.yaml` areas, a config that does not exist in this checkout; the substance survives via the rule source.) Not actioned: this is mechanical and owned by the lint gate — `code-reviewer.md §Rule surface` directs the judgment budget away from what lint decides deterministically; the diff is net-neutral on the literal (`iconColor: Colors.white` + `fontColor: Colors.white` before → `iconColor: Colors.white` + `copyWith(color: Colors.white)` after); and the rule's own stated rationale ("hardcoded colors ignore the current theme and break dark/light mode") does not apply to a white label over a fixed `Colors.black.withValues(alpha: 0.4)` scrim. The doc-boundary half — `design-system.md:108` now naming this file as the sanctioned pattern — is real but sanctions the `Theme`-wrapping mechanism, not the literal.

### Coverage gaps

- `.claude/rules/design-system.md:52-53`, `:93-100`, `:119`, `:134-136` — four doc hunks (the 危險動作 colour line gaining a `package:ui_kit` attribution; the §共用元件庫 heading losing its `lib/shared/` qualifier plus the new 2026-08-06 migration paragraph; the `CommonInfoTile` row gaining a `CommonBadgeType` attribution; the removal of the `CommonDeleteDialog`/`CommonInfoDialog`/`CommonLoadingDialog` rows from the Dialogs table) carry neither a challenge nor a stated reason. All are attribution/bookkeeping edits consistent with the migration; listed for completeness, not as suspicion.
- `lib/features/task/presentation/screens/task_edit_screen/task_edit_screen.dart:62` — new `tooltip: '刪除任務'` added alongside the delete-flow rewiring; not enumerated in §Detail coverage.

### Summary

1 critical, 3 warnings, 0 suggestions, 1 無法判定.
A clean, well-executed shared-package migration — the five local widgets are deleted with zero dangling references (verified), every `CommonErrorWidget` call site supplies `ErrorHandler.getErrorMessage`, and the `task_edit_screen` hand-rolled dialog and its stacked `CommonLoadingDialog` are genuinely gone; the one thing that must not ship as-is is the `tag_edit_screen` delete path, which announces success for a delete whose failure now has nowhere to surface.

coverage: time=pass · space=pass · scalability=na（diff 未觸及集合處理或資料路徑） · extendability=finding（C3） · coupling=finding（C4；新增 edge 全為 `lib/features`／`lib/shared` → `package:ui_kit` 葉節點，方向合規） · correctness=finding（C1） · error-handling=finding（C1、C3） · testability=na（無 widget-test seam 可延伸） · startup=pass（`main.dart`、provider 初始化、`LogSystem.init` 均未變動）
```
