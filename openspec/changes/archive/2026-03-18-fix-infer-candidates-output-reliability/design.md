## Context

`infer-candidates.sh` 使用 `set -euo pipefail`，這能讓真正錯誤及早暴露，但目前部分 resolver 函式把「找不到檔案」也表達成非零退出碼。當呼叫端以 command substitution 接收結果時，bash 會直接中止腳本，後續 candidate summary、`result` 組裝與 `--output` 寫檔都不會執行。

系統限制：
- 維持既有候選推測規則與 debug 格式。
- 不引入額外相依套件。
- 只處理輸出可靠性，不擴大到候選精度調整。

## Goals / Non-Goals

**Goals:**
- resolver 找不到對應檔案時回傳空字串且維持成功狀態。
- 腳本在解析 miss 下仍能完成輸出組裝與寫檔。
- 變更範圍限制在輸出可靠性，不改業務判定。

**Non-Goals:**
- 不修正初始化無 baseline 時的候選膨脹問題。
- 不新增新的 CLI 參數。
- 不調整 `change_reason`、`signals` 或 candidate 分類規則。

## Decisions

1. 將 resolver miss 視為可容忍狀態。
- 做法：`resolve_symbol_file` 與 `resolve_service_file` 在未命中時明確 `return 0`。
- 原因：未解析到對應檔案只代表缺少關聯訊號，不應視為執行失敗。

2. 保留呼叫端原本的 command substitution。
- 做法：優先修正 resolver 函式契約，而不是在每個呼叫點額外加 `|| true`。
- 原因：集中修正可降低遺漏風險，也讓函式語意更一致。

## Risks / Trade-offs

- [Risk] 某些真正的 resolver 異常會被視為 miss。
  -> Mitigation：本次只在「未命中」路徑回傳成功；實際執行錯誤仍會由內部命令失敗暴露。
- [Risk] CLI 仍可能因其他非 resolver 例外而提前結束。
  -> Mitigation：本次聚焦先排除已知主因，驗證輸出鏈路恢復。

## Migration Plan

1. 調整 resolver 函式的回傳語意。
2. 以 shell 語法檢查驗證腳本可執行。
3. 更新 tasks 狀態，保留本次變更紀錄。
