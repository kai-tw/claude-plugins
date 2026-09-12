# Style rules — Dart / Flutter 語言層

載入條件：diff 含 `.dart`。每條應掛於 `index.md` 之一既有 `S<N>` 下；掛不上者，應先
修憲（`CONVENTIONS.md`）。

## S3 — 折疊應逐消費點證成

- **S3.4-dart 可清除之可空欄位，`copyWith` 參數應用 `T? Function()?`** — Check: 該可空
  欄位之 `copyWith` 是否須表達「清為空」？須而參數宣告為 `T?` 者，違反本條：「未給」與
  「設為空」抵達時均為 `null`，而 `x ?? this.x` 一律將該歧義解為保留。僅空→有值、不回頭
  之單調欄位維持 `T?`（無清除情形可資表達，包裹僅屬贅餘）。應用純 Dart 之函式型別，
  不用 Flutter 之 `ValueGetter`——domain 層不得匯入 Flutter，而可清除之可空欄位正最常
  出現於該層。
