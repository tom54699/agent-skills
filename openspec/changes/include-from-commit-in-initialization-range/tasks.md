## 1. 初始化 range 語意修正

- [x] 1.1 調整初始化模式的 `from-commit` 解析，讓指定 commit 本身會被納入 diff 範圍。
- [x] 1.2 補上 root commit 無 parent 時的明確錯誤訊息。
- [x] 1.3 保留 `meta.from_commit`，並讓 `meta.diff_range` 顯示實際展開後的 inclusive range。

## 2. 文件同步

- [x] 2.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明初始化 `from-commit` 會包含指定 commit 本身。
- [x] 2.2 更新 [laravel-api-docs-guided-sync.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/laravel-api-docs-guided-sync.md)，補上 `from_commit` 與 `diff_range` 的差異說明。

## 3. 驗證與回歸

- [x] 3.1 補測試覆蓋 inclusive `from-commit` 行為。
- [x] 3.2 補測試覆蓋 root commit 錯誤情境。
- [x] 3.3 用 `myan-ride` 專案的 `ff619fdd97103cc22752813b2ec902b56aa1cacf` 重跑初始化驗證，確認候選清單納入該 commit 本身的 API 相關修改。
