---
type: regex
pattern: '^filters=data-locale="zh-TW">繁中,data-locale="en">英文,data-mode="light">淺色,data-mode="dark">深色,data-mode="all">淺色與深色,data-screen="all">全部畫面,data-screen="step_wait">等待頁,data-screen="account_unresolved">帳號無法確認頁$'
flags: m
arm: with-only
---
One button per locale (its name from labels.json, no "all"), a light/dark filter and one button per screen, in the founder's language and labels.json's order.
