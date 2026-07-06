## 1. 安裝範圍決策

- [x] 1.1 在 Plugin Recommendations 小節新增安裝範圍規則：必裝層預設 user（全域）scope；依訊號複選層與條件式層預設 project（共享）scope
- [x] 1.2 明講不管哪一層，最終範圍都要讓使用者確認或覆寫，不能假設預設值就是最終決定
- [x] 1.3 「Plugin Decisions」記錄格式加入安裝範圍欄位

## 2. 主動複選提問

- [x] 2.1 「Stack-specific tier」的敘述從「offer as a multi-select choice」改為「MUST use the AskUserQuestion tool」，明確要求互動式提問而非只寫進計畫文字

## 3. 模板更新

- [x] 3.1 `Init Output Shape` 模板新增欄位，呈現每個 plugin 的安裝範圍決定

## 4. 驗證

- [x] 4.1 重讀 `skills/development-workflow/SKILL.md`，確認安裝範圍規則、AskUserQuestion 要求、模板欄位皆已就位
- [x] 4.2 確認 `assets/AGENTS.template.md`、`assets/CLAUDE.template.md` 未被修改
- [x] 4.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py`
- [x] 4.4 執行 `openspec validate improve-development-workflow-plugin-prompts --strict`
