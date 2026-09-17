# Style rules — Dart / Flutter 法律層

載入條件：diff 含 `.dart`。每條應掛於母法之一既有 `S<N>` 下；掛不上者，應先修憲
（`CONVENTIONS.md`）。

## S2 — 名字離開宣告後，應仍可辨其所屬、種類與分類

- **S2.1-dart 型別名依 `<所屬><概念><種類>` 之序組成，所屬依用途判定** — Check: 該型別
  （private 亦然）是否以其所屬為首？功能所有者以該功能名；跨功能共用者以命令層所定之一個
  保留字；因單一平台 API 而存在者以平台名（`Ios` / `Android`），依其用途而非其編譯範圍。
  概念名詞已含功能名者，不重複前綴。所屬錯置或缺漏者，違反本條。種類詞之詞彙由命令層定之。
- **S2.2-dart 以 Material / Cupertino 元件名收尾之 widget，應即為該元件** — Check: 名為
  `…Card`、`…Chip`、`…BottomSheet` 之類者，是否繼承、組合或直接算繪該元件？形似而未使用
  者，違反母法 S2.6，應改用命令層表中之他詞。以一個帶靜態 `build(context, …)` 之命名空間
  類別冒充 widget 者，同。

## S3 — 折疊應逐消費點證成

- **S3.1-dart 可清除之可空欄位，`copyWith` 參數應用 `T? Function()?`** — Check: 該可空
  欄位之 `copyWith` 是否須表達「清為空」？須而參數宣告為 `T?` 者，違反本條：「未給」與
  「設為空」抵達時均為 `null`，而 `x ?? this.x` 一律將該歧義解為保留。僅空→有值、不回頭
  之單調欄位維持 `T?`（無清除情形可資表達，包裹僅屬贅餘）。應用純 Dart 之函式型別，
  不用 Flutter 之 `ValueGetter`——domain 層不得匯入 Flutter，而可清除之可空欄位正最常
  出現於該層。

## S4 — 持久化之值，其意義不得繫於位置或人工維護

- **S4.1-dart `enum` 持久化應用 `toString()`** — Check: 該 `enum` 寫出之形式為何？用
  `.index` 者，違反母法 S4.1（序列位置）。用 `.name` 者，違反本條：本語言之持久化形式為
  `toString()`（`Foo.bar`），其型別前綴使儲存值自帶 namespace，而二形式並存時，同一份
  儲存有二種編碼，讀者非兩端俱讀不能辨其一。其代價依母法 S4.2 載於該 enum 之宣告處：
  成員或型別更名即為一次資料遷移，且**不得覆寫 `toString()`**——覆寫即改寫儲存格式，
  而該改寫不出聲。讀取端仍須備一 `wildcard` 分支以退回未知值。

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

## S10 — 編譯期已記錄之集合，不得以執行期查找繞過

- **S10.1-dart 經 portal 算繪者，不繼承其詞法脈絡** — Check: 該經 portal 算繪之 widget
  （`showDialog`、`showModalBottomSheet`、`Draggable.feedback`、`OverlayEntry`、任何
  `Overlay.of(context).insert`），有無讀取一個其宿主並未供應之 `InheritedWidget`？有者，
  違反本條：它掛在 app 根部的 `Overlay`，故呼叫端與宿主之間的每一層——`BlocProvider`、
  `Theme`、`Material`、`MediaQuery`、`Directionality`——全數不在。其失敗**僅於執行期
  顯現**，無編譯錯誤亦無 lint。二條出路，依序：該 widget 完全不讀自己的 `context`，
  資料與 callback 由呼叫端傳入；或逐一顯式重橋接其子樹確實會讀到的每一層。
  預設答案是「有」——任何非簡單的 widget 至少讀 `Theme` 與 `Material`。

