## 1. SKILL.md：Cherry-pick 模式規格新增

- [x] 1.1 新增 cherry-pick 觸發條件（關鍵字列表）與和 guided-sync 的區分說明
- [x] 1.2 撰寫 cherry-pick 流程規格：列出 endpoint → 使用者選取（支援描述式）→ 確認清單 → 組 temp subset spec → 選擇動作
- [x] 1.3 規格明確禁止：不修改 `openapi.yaml`，不寫 sync history，temp spec 寫 `/tmp/cherry-pick-<timestamp>.json`
- [x] 1.4 補充上傳 Apidog 的腳本呼叫範例：`upload-apidog.sh --openapi <temp> --skip-history --no-delta`
- [x] 1.5 補充產 Redoc 的腳本呼叫範例：`gen-html.sh --openapi <temp>`
- [x] 1.6 補充 conflict detection 跳過警告的互動規範（上傳前 LLM 必須告知使用者）
