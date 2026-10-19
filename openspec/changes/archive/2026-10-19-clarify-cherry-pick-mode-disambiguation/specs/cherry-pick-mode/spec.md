## MODIFIED Requirements

### Requirement: Cherry-pick mode is triggered by explicit user phrasing
當使用者說「只想上傳這幾個 API」、「單獨產這幾個 endpoint 的 Redoc」、「cherry-pick」或「挑幾個 API」時，系統 SHALL 進入 cherry-pick 模式，不走完整 guided-sync 流程。

當使用者點名一個或少數幾個具體 API/endpoint、但沒有使用上述任一固定觸發詞時，該句話本身不足以判斷模式；LLM SHALL 在執行任何腳本前，先問清楚該 API 的程式碼是否剛寫或改過，以此決定要進 guided-sync（程式碼有變更，需要重新分析）還是 cherry-pick（程式碼沒變，只是要重發既有文件），不得預設直接進入 guided-sync 主流程。

#### Scenario: Cherry-pick trigger recognized
- **WHEN** 使用者輸入含有 cherry-pick 觸發短語
- **THEN** LLM 進入 cherry-pick 模式，列出 `openapi.yaml` 現有 endpoint 清單供選取

#### Scenario: Guided-sync trigger is not confused with cherry-pick
- **WHEN** 使用者說「幫我產生 API 文件」、「更新 API 文件」
- **THEN** 進入 guided-sync 主流程，不進入 cherry-pick 模式

#### Scenario: Named API without an explicit trigger phrase requires a clarifying question
- **WHEN** 使用者點名一個具體 API（例如「幫我處理訂單建立這支 API 的文件」），但沒有使用 cherry-pick 固定觸發詞，也沒有說「全部」/「所有 API」這類全面性字眼
- **THEN** LLM MUST 在執行任何腳本前，先問使用者該 API 的程式碼是否剛寫或改過
- **AND** 若程式碼有變更，進入 guided-sync（可口頭確認之後仍會依整段 diff 推測，Step 5 再手動篩選）
- **AND** 若程式碼沒有變更，進入 cherry-pick，從既有 `openapi.yaml` 挑出該 API
