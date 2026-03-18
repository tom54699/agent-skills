## 1. Resolver 穩定性修正

- [x] 1.1 調整 `infer-candidates.sh` resolver：未命中時不得以非零狀態中止腳本。
- [x] 1.2 確認 `--output` 寫檔路徑在 resolver miss 情境下仍可走到結果輸出。

## 2. 驗證

- [x] 2.1 執行 shell 語法檢查，確認腳本修改後無語法錯誤。
- [x] 2.2 更新 OpenSpec 任務狀態，保留本次修正紀錄。
