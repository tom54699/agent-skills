## Context

使用者確認了 guided-sync 的核心操作模型：

1. 前置檢查與初始化 / 日常分流維持既有規則。
2. 先由 `infer-candidates.sh` 產生候選 API 清單。
3. LLM 只以精簡清單和使用者互動，不預設傾倒過多分析資訊。
4. 使用者可反覆刪除、保留、手動新增 API，直到最終確認。
5. 只有確認後的 final list 可以驅動 OpenAPI 更新。
6. 更新完成後才上傳 Apidog，最後才詢問是否產 HTML。

目前系統缺口在於 Step 5 與 Step 6 之間沒有一個明確的 final list artifact，也沒有把 final list 套用到 OpenAPI 的執行點。

## Goals / Non-Goals

**Goals:**
- 候選確認階段只顯示精簡 API 清單：`status + method + path`。
- 支援互動式多輪確認，直到使用者明確確認。
- final list 必須落成可被 shell 腳本讀取的結構化檔案。
- OpenAPI 更新必須只處理 final list 中的 endpoint。

**Non-Goals:**
- 本次不改候選推測的核心命中規則。
- 本次不改初始化 / 日常模式的 baseline 邏輯。
- 本次不重設 Apidog 同步與 HTML 產生的大方向。

## Decisions

1. 候選確認由 LLM orchestrate，shell 負責落檔。
- 原因：增刪修正與多輪確認屬於互動流程，LLM 比 shell 更適合。
- 實作方向：LLM 讀取 `infer-candidates.sh` 輸出，向使用者展示精簡清單；確認後將 final list 寫成 JSON 檔案供後續腳本讀取。

2. final list 需要獨立 artifact。
- 建議路徑：`docs/api-docs/candidates/<timestamp>.confirmed.json`
- 內容至少包含：`status`、`method`、`path`
- 可選附帶來源資訊，但不作為互動展示主體。

3. OpenAPI 更新需要 final list 驅動入口。
- 方案 A：新增 `apply-confirmed-candidates.sh`，根據 final list 對既有 OpenAPI 做新增 / 更新 / 刪除處理。
- 方案 B：調整 `gen-openapi.sh` 支援 `--candidate-file`，只重建 final list 所需內容，再套用到正式檔案。
- 傾向方案 B，因為可重用現有解析腳本，但需要修正目前全量掃描與 incremental 語意不清的問題。

4. 候選展示預設精簡，細節按需展開。
- 預設只展示 `new|updated|deleted METHOD PATH`
- 若使用者追問，再附上 `change_reason`、`confidence`、`signals`

## Proposed Flow

1. `infer-candidates.sh` 產生候選檔。
2. LLM 讀取候選檔，向使用者展示精簡列表。
3. 使用者回覆：
- 保留哪些
- 移除哪些
- 手動新增哪些
4. LLM 回顯新的清單，重複直到使用者明確確認。
5. LLM 將 final list 落成 confirmed JSON。
6. OpenAPI 更新腳本讀取 confirmed JSON，只處理其中 endpoint。
7. 同步 Apidog。
8. 詢問是否產生 HTML。

## Risks / Trade-offs

- [Risk] 互動多輪後，final list 與原候選來源資訊脫鉤。
  -> Mitigation：confirmed JSON 保留必要欄位與來源候選索引，供追查。
- [Risk] 若仍沿用 `gen-openapi.sh` 現有全量掃描模型，final list 容易再次失真。
  -> Mitigation：本變更要求明確的 final-list-driven update 契約，不能只靠文件描述。
- [Risk] `deleted` 的處理仍可能較敏感。
  -> Mitigation：維持既有規則，未確認不得自動刪除。

## Migration Plan

1. 更新 `SKILL.md`，明確寫出精簡候選展示與多輪確認流程。
2. 設計 confirmed JSON 結構。
3. 補一個 final-list-driven 的 OpenAPI 更新入口。
4. 調整整體 orchestration，讓上傳與 HTML 明確依賴 confirmed JSON 之後的 OpenAPI 結果。
