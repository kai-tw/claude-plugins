# Style rules — C# 法律層

載入條件：diff 含 `.cs`。每條應掛於母法之一既有 `S<N>` 下；掛不上者，應先修憲
（`CONVENTIONS.md`）。

## S3 — 折疊應逐消費點證成

- **S3.1-csharp `struct` 之 `default` 繞過建構式** — Check: 該以 `struct`（`record struct`
  亦屬之）表達之值，其全零之 `default` 是否為一個合法態？否者，違反母法 S3.5：建構式所把
  之關，`default(T)`、`new T[n]`、未指派之欄位與反序列化全數繞過，型別不會擋，而零值讀起來
  與一個真的值無異。應改以參考型別表達，或使 `default` 成為一個具名之合法態。

## S4 — 持久化之值，其意義不得繫於位置或人工維護

- **S4.1-csharp `enum` 持久化應為成員名** — Check: 該 enum 寫出之形式為何？
  `System.Text.Json` 之預設形式為底層數值（`Phase.Payout` 寫出為 `2`），未掛
  `JsonStringEnumConverter` 即寫出者，違反母法 S4.1（序列位置）：成員之間插入一個新成員，
  既存存檔即整批位移一格，而讀回不出聲。轉 `(int)` 或 `ToString("D")` 者，同。其代價依母法
  S4.2 載於該 enum 之宣告處：成員更名即為一次資料遷移。
- **S4.2-csharp 時刻應以 `DateTimeOffset` 持久化** — Check: 該寫出之時刻，其型別為
  `DateTime` 抑或 `DateTimeOffset`？屬前者，違反本條：`Kind` 不隨值寫出，讀回一律為
  `Unspecified`，其後之時區換算即以讀取端之本地時區為準——同一筆資料於不同裝置讀出不同
  時刻，且不報錯。

## S6 — 註解應答 WHY，並繫於距其最近之宣告

- **S6.1-csharp `!` 應載明其保證由誰維持** — Check: 該 `= null!`、`default!` 或 `!` 抑制
  之處，有無載明該值由誰、於何時填入（框架鉤子、序列化器、呼叫順序）？無者，違反母法
  S6.5：`!` 關掉的是編譯器的檢查，換來的保證改由讀者維持，而該保證之來源自本 repo 之型別
  讀不出來。建構式填得起來者，應改為建構式注入。

## S7 — 失敗之處理，應與失敗之種類相稱

- **S7.1-csharp 邊界換型別應接回原 stack trace** — Check: 於 `catch` 內轉譯例外時，是否以
  `ExceptionDispatchInfo.SetRemoteStackTrace` 將原 stack trace 接上新例外後拋出？以
  `throw new XFailure(msg, ex)` 挾帶 `InnerException` 代之者，違反母法 S7.5：新例外之 stack
  起於轉譯所在之行，而 `InnerException` 正係母法所排除之挾帶。

## S8 — 協調不得建立於「通常會對」之上

- **S8.1-csharp 非同步臨界區應以 `SemaphoreSlim(1, 1)` 序列化** — Check: 該跨 `await` 之
  臨界區，其守衛為 `SemaphoreSlim`，抑或 `lock` 加一個 `bool`？屬後者，違反母法 S8.1：
  `lock` 不得跨 `await`（編譯器擋在該行），故改寫之結果通常是只護住續行點之前的半段，而
  那半段本無競爭。

## S9 — 資源應有上界，且上界應於寫下之時載明

- **S9.1-csharp `event` 之訂閱清單無上界** — Check: 該 `+=` 之對稱 `-=` 位於何處？答不出
  者，違反本條：C# 之 event 對訂閱者持強參考，發布者較訂閱者長壽時，訂閱者永不回收，且其
  回呼於訂閱者已被拆除之後照樣送達。Example: 短命之訂閱者於建立時訂閱一個長壽單例之事件，
  拆除時無人退訂。

## S10 — 編譯期已記錄之集合，不得以執行期查找繞過

- **S10.1-csharp `enum` 之值域為其底層整數之全域** — Check: 該自儲存、網路或 `Enum.Parse`
  讀回之 enum，有無於邊界以 `Enum.IsDefined` 或窮盡之 `switch` 表達式把關？無者，違反母法
  S10.1：`(Phase)99` 合法、`JsonSerializer.Deserialize<Phase>("99")` 亦原樣收下，而
  `switch` 語句漏掉它只是靜靜跑完——`switch` 表達式由編譯器之 CS8524 擋下，語句無此保護。

## S15 — 守衛應指名其所防之狀態，其數目係設計之徵兆

- **S15.1-csharp `?.` 係一個未具名之守衛** — Check: 該 `?.` 或 `??` 所防之 `null`，來自
  哪一條路徑？答不出者，違反母法 S15.1：整串運算式靜靜求值為 `null` 或整個不執行，呼叫端與
  使用者皆無回饋，而那個不明的 `null` 才是瑕疵。

## S16 — 一個物件擁有一項能力，並以其介面為唯一邊界

- **S16.1-csharp 露出之唯讀集合應為真正唯讀** — Check: 宣告為 `IReadOnlyList<T>` 之回傳
  值，其背後實體是否即為擁有者所持之 `List<T>`？是者，違反母法 S16.4：該介面僅是視角，
  呼叫端一次 `as List<T>` 即取得擁有者之內部集合。`AsReadOnly()` 擋下該轉型；呼叫端所需為
  當下之快照者，應回傳一份拷貝。
