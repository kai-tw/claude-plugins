---
type: regex
pattern: '^ok-heredoc=0$'
flags: m
arm: with-only
---
check.sh 跑到最後一條——另外兩個 grader 在沒有輸出時也會通過，這條防它空轉。
