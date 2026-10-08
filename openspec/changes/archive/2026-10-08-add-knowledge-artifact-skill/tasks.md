## 1. `knowledge-artifact` skill

- [x] 1.1 建立 `skills/knowledge-artifact/SKILL.md`：frontmatter（name、含中文觸發詞的 description、`metadata.version: "1.0.0"`）、角色與邊界、核心規則
- [x] 1.2 在 SKILL.md 定義共同製作流程：提案 → 本機產生 → 檢查與預覽 → 依回饋修改 → 使用者確認後上傳；小幅修正可跳過提案但不可跳過確認
- [x] 1.3 在 SKILL.md 定義本機工作目錄、平台為準的更新方式、平台不可用時的處理、之後上傳本機草稿
- [x] 1.4 在 SKILL.md 定義上網查證規則、更新與搜尋、存取設定、刪除與版本還原規則、轉交 `knowledge-platform-dev`
- [x] 1.5 在 SKILL.md 定義提案與完成回報的輸出格式
- [x] 1.6 建立 `references/platform-operations.md`：設定與 header、操作 ↔ v1 endpoint 對照、curl 範例（不輸出 token）、用 slug 找 artifact 的方式、錯誤處理
- [x] 1.7 建立 `references/artifact-authoring.md`：依內容類型的呈現方式、品質規則、技術與安全要求、預覽方式、檢查清單與建議指令
- [x] 1.8 建立 `references/portable-artifact-format.md`，並把 `knowledge-platform-dev` 那份的結尾說明改成中性措辭，兩份內容完全一致

## 2. Repo 文件更新

- [x] 2.1 更新 `README.md`：安裝指令加入 `knowledge-artifact`，Skills 清單加入說明
- [x] 2.2 更新 `docs/install-skills.md`：安裝指令與「目前可用 Skill」
- [x] 2.3 更新 `CLAUDE.md` 與 `AGENTS.md` 的專案結構導覽與閱讀順序
- [x] 2.4 更新 `.ai-project-index/config.json` 的 `expectedCoverage`

## 3. 驗證

- [x] 3.1 用 diff 確認兩份 `portable-artifact-format.md` 完全相同
- [x] 3.2 確認 skill 內沒有任何 secret、使用者實際網域或 server 資訊
- [x] 3.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py`
- [x] 3.4 執行 `python3 skills/ai-project-index/scripts/evaluate-index.py`
- [x] 3.5 執行 `openspec validate add-knowledge-artifact-skill --strict`
- [x] 3.6 執行 `openspec validate --all --strict`
