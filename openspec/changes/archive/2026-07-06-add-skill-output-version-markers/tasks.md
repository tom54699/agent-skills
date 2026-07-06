## 1. 版本識別基礎（三個 skill）

- [x] 1.1 `skills/ai-project-index/SKILL.md` frontmatter 新增 `metadata.version`（初始值 `"1.0.0"`）
- [x] 1.2 `skills/laravel-api-docs/SKILL.md` frontmatter 新增 `metadata.version`（初始值 `"1.0.0"`）
- [x] 1.3 `skills/business-logic-workflow/SKILL.md` frontmatter 新增 `metadata.version`（初始值 `"1.0.0"`）

## 2. ai-project-index 版本比對邏輯

- [x] 2.1 在 `skills/ai-project-index/scripts/audit-index.py` 定義腳本期望的 schema 版本常數
- [x] 2.2 `main()` 讀取 index 後，比對 `index.get("version")`；不符時呼叫 `warning_audit()` 並帶入新的 `version_mismatch` reason
- [x] 2.3 確認 `warning_audit()` 現有邏輯不需修改即可承載新 reason（純呼叫端新增分支）

## 3. laravel-api-docs 同步歷史 schema_version

- [x] 3.1 `SKILL.md` 同步歷史紀錄規格新增 `schema_version` 欄位說明與範例
- [x] 3.2 新增規則：`schema_version` 缺失時視為隱含舊版本，沿用既有 `path_strategy` 那種欄位級 fallback 精神，不強制遷移

## 4. business-logic-workflow 輸出標記

- [x] 4.1 三個 Output Shape（Brief/As-Is/Delta）都在 `Status:` 後新增一行 `Generated-by: business-logic-workflow vX.X.X`

## 5. 驗證

- [x] 5.1 重讀三個 `SKILL.md`，確認版本欄位、schema_version 說明、Generated-by 標記皆已就位
- [x] 5.2 手動測試 `audit-index.py`：構造一個 `version` 不符的 `index.json`，確認觸發 `warning` 狀態與 `version_mismatch` reason（實測通過）
- [x] 5.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py`，確認既有（版本相符的）index 仍正常運作、不誤報（實測通過，`status: ok`）
- [x] 5.4 執行 `openspec validate add-skill-output-version-markers --strict`
