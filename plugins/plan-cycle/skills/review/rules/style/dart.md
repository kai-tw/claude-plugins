# Style rules — Dart / Flutter 法律層

載入條件：diff 含 `.dart`。每條應掛於母法之一既有 `S<N>` 下；掛不上者，應先修憲
（`CONVENTIONS.md`）。

## S3 — 折疊應逐消費點證成

- **S3.1-dart 可清除之可空欄位，`copyWith` 參數應用 `T? Function()?`** — Check: 該可空
  欄位之 `copyWith` 是否須表達「清為空」？須而參數宣告為 `T?` 者，違反本條：「未給」與
  「設為空」抵達時均為 `null`，而 `x ?? this.x` 一律將該歧義解為保留。僅空→有值、不回頭
  之單調欄位維持 `T?`（無清除情形可資表達，包裹僅屬贅餘）。應用純 Dart 之函式型別，
  不用 Flutter 之 `ValueGetter`——domain 層不得匯入 Flutter，而可清除之可空欄位正最常
  出現於該層。

## S4 — 持久化之值，其意義不得繫於位置或人工維護

- **S4.1-dart `enum` 持久化應用 `.name`** — Check: 該 `enum` 寫出之形式為何？用 `.index`
  者，違反母法 S4.1（序列位置）。用 `toString()` 者，違反本條：其輸出帶型別前綴
  （`Foo.bar`），故型別更名亦成為一次資料遷移，而 `.name` 只綁成員名。二者皆須於讀取端
  備一 `wildcard` 分支以退回未知值。

## S5 — 中止流程而不出聲者，應載明觸發條件與所跳過之流程

- **S5.1-dart fire-and-forget 應以 `unawaited()` 明示** — Check: 該不等待結果之呼叫，是否
  包在 `unawaited()` 內？裸呼叫者，違反本條——裸呼叫與「忘了 `await`」在原始碼中外觀
  全同，而 `unawaited()` 使該決定成為一個寫下的字。其理由另依母法 S5.2 載明。

## S7 — 失敗之處理，應與失敗之種類相稱

- **S7.1-dart 邊界換型別應用 `Error.throwWithStackTrace`** — Check: 於 `catch (e, s)` 內
  轉譯例外時，是否以 `Error.throwWithStackTrace(mapped, s)` 拋出？以 `throw mapped(e)`
  拋出者，違反本條：`throw` 會將 stack 重設至轉譯所在之行，故 crash reporting 指向邊界，
  而非實際出錯之 frame。

## S9 — 資源應有上界，且上界應於寫下之時載明

- **S9.1-dart `compute()` 之 payload 應小於其所省之運算** — Check: 送進 isolate 之
  payload 有多大？`compute()` 對 payload 作深拷貝，故為省一次廉價運算而運送大型物件圖
  者，違反本條——其拷貝成本即為新的上界，且該成本不出現在被搬走的那段程式碼裡。
