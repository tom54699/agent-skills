## 1. 版本識別基礎

- [x] 1.1 在 `skills/development-workflow/SKILL.md` frontmatter 新增 `metadata.version`（初始值 `"1.0.0"`）

## 2. Init 訊號偵測擴充

- [x] 2.1 「Inspect project signals」步驟新增：讀取目標專案 `.claude/settings.json` 的 `enabledPlugins`（若存在）
- [x] 2.2 新增讀取 `AGENTS.md`/`CLAUDE.md` 裡既有的「Plugin Decisions」記錄區塊（若存在）

## 3. Plugin Recommendations 邏輯擴充

- [x] 3.1 已安裝偵測：候選 plugin（必裝/依訊號/條件式）若已安裝，不再推薦，改列為「已安裝」狀態
- [x] 3.2 排除清單衝突偵測：若排除清單裡的 plugin 已安裝，產生一句衝突提醒，明講不建議移除
- [x] 3.3 決策記錄：使用者確認 init 計畫後，把每個 plugin 的最終狀態（installed/declined/excluded-conflict-noted）寫進 `AGENTS.md`/`CLAUDE.md` 的「Plugin Decisions」區塊

## 4. 模板輸出更新

- [x] 4.1 `Init Output Shape` 模板新增「已安裝、略過推薦」與「排除清單衝突」的呈現欄位
- [x] 4.2 `Init Output Result` 模板提及本次寫入的「Plugin Decisions」記錄

## 5. 驗證

- [x] 5.1 重讀 `skills/development-workflow/SKILL.md`，確認版本欄位、既存專案讀取邏輯、已安裝/排除衝突偵測、決策記錄寫入邏輯皆已就位
- [x] 5.2 確認 `assets/AGENTS.template.md`、`assets/CLAUDE.template.md` 未被修改
- [x] 5.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py`
- [x] 5.4 執行 `openspec validate sync-development-workflow-existing-projects --strict`
