## 1. SKILL.md 規則補充

- [x] 1.1 在 `skills/laravel-api-docs/SKILL.md` 的 `## Cherry-pick 模式` 新增「點名特定 API 時的模式判斷」小節
- [x] 1.2 規則內容涵蓋：判斷依據（程式碼是否變更）、觸發時機（點名具體 API 但未命中既有觸發詞）、必須在跑腳本前先問的要求、問句範例

## 2. 驗證

- [x] 2.1 重讀新增小節，確認與既有「觸發條件」段落不衝突（不重複列舉觸發詞、不改變既有觸發詞行為）
- [x] 2.2 `openspec validate clarify-cherry-pick-mode-disambiguation --strict`
