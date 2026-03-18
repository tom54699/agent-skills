## 1. 初始化分流規則

- [x] 1.1 更新 `SKILL.md`，新增無 success history 時的初始化分流問答。
- [x] 1.2 在文件明確列出三種基準來源（本地 OpenAPI / Apidog 匯出 / 無基準）。
- [x] 1.3 明確規定：無基準時需提供 `from_commit`。

## 2. 推測腳本調整

- [x] 2.1 調整 `infer-candidates.sh`，新增 `--from-commit` 參數。
- [x] 2.2 實作初始化 `new-only` 模式（無 OpenAPI 檔時不推測 `updated`）。
- [x] 2.3 輸出 `meta.init_mode` 與 `meta.baseline_source`，便於後續審核。

## 3. baseline 寫入與後續流程

- [x] 3.1 驗證初始化成功後 `upload-apidog.sh` 會寫入 history。
- [x] 3.2 驗證後續日常流程可讀取該 history 並使用 `synced_at` 範圍。

## 4. 成本模式

- [x] 4.1 在 `SKILL.md` 補 `fast` 與 `enhanced` 模式說明，預設 `fast`。
- [x] 4.2 確認初始化預設走 `fast`，避免首次大範圍高成本分析。
