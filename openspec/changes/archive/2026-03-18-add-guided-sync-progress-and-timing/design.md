## Context

使用者希望 guided-sync 在實際執行時不再是黑盒子：

1. 整體流程要能顯示固定步驟 checklist，完成即打勾。
2. 每個步驟都要顯示自己的進度條，不只是單一「正在執行」訊息。
3. 長時間腳本要能說明慢在哪個階段，避免代理端只能輪詢。

目前各腳本雖然會輸出少量 debug，但沒有統一格式，也無法把腳本內部階段映射回 guided-sync 的總流程。

## Goals / Non-Goals

**Goals**
- 建立可在所有 guided-sync 腳本重用的進度與 timing 共用層。
- 在不破壞既有 JSON `stdout` 契約的前提下，從 `stderr` 輸出人類可讀且機器可解析的進度訊息。
- 對 `infer-candidates.sh` 與 `gen-openapi.sh` 補上細粒度分階段 timing。
- 讓後續 orchestration 可以直接依賴這些訊息，而不必持續輪詢。

**Non-Goals**
- 本次不新增完整 shell orchestrator 來取代 LLM 的 guided-sync 控制。
- 本次不重寫候選推測與 OpenAPI 生成核心邏輯。
- 本次不改 Apidog conflict handling 的功能範圍。

## Decisions

1. 新增共用 `progress-lib.sh`
- 內容包含：
  - guided-sync 固定步驟定義
  - checklist renderer
  - 進度條 renderer
  - 簡單 timing helpers
- 所有腳本透過 `source` 重用，避免各自維護不同格式。

2. 進度與 timing 一律走 `stderr`
- 原因：各腳本目前都以 `stdout` 回傳 JSON 結果，不能被進度輸出污染。
- 好處：CLI 可直接看到進度，代理端也能從 `stderr` 擷取進度事件。

3. checklist 採無狀態推導
- guided-sync 固定步驟順序為：
  1. `preflight`
  2. `infer_candidates`
  3. `confirm_candidate_list`
  4. `update_openapi`
  5. `upload_apidog`
  6. `generate_html`
- 每支腳本只需要宣告自己屬於哪個步驟；renderer 依步驟順序推導前面為已完成、後面為未開始。
- 這樣可避免維護額外的進度狀態檔。

4. 長時間腳本採「整體步驟進度 + 當前階段進度」雙層輸出
- `infer-candidates.sh`
  - 主要階段：range selection、class index、git inventory、route snapshot、action hints、candidate evaluation、write output
  - `candidate evaluation` 需依 route 數量回報子進度
- `gen-openapi.sh`
  - 主要階段：route snapshot、candidate normalization、endpoint generation、merge base、apply deletions、write output
  - `endpoint generation` 需依 endpoint 數量回報子進度

5. timing 採 key-value line 格式
- 範例：
  - `[guided-timing] script=infer-candidates stage=class_index duration_ms=1820 detail="symbols=606"`
  - `[guided-progress] step=infer_candidates stage=candidate_evaluation percent=57 current=254 total=445 message="evaluating endpoints"`
- 格式保持 line-based，便於 CLI 顯示與代理解析。

6. 提供關閉進度輸出開關
- 加入 `--no-progress` 參數，必要時可停用 `stderr` 進度輸出。
- 預設開啟，符合 guided-sync 互動需求。

## Proposed Flow

1. 腳本啟動後載入 `progress-lib.sh`。
2. 腳本註冊自己的 guided-sync 步驟 ID。
3. 在每個主要階段開始、更新、完成時，呼叫共用函式輸出：
- workflow checklist
- 目前步驟的 progress bar
- timing 行
4. 腳本原本的 `stdout` JSON 輸出維持不變。
5. `SKILL.md` 更新為：
- guided-sync 會在執行過程顯示 checklist 與進度條
- 慢點分析應優先查看 timing 行與最後的 timing summary

## Risks / Trade-offs

- [Risk] checklist 採無狀態推導，若單獨直接跑後段腳本，前面步驟會被視為已完成。
  -> Mitigation：文件明確說明 checklist 代表 guided-sync 標準順序；單獨執行腳本時僅作參考。

- [Risk] `infer-candidates.sh` 與 `gen-openapi.sh` 增加 progress/timing 後，程式碼會更長。
  -> Mitigation：抽共用函式到 `progress-lib.sh`，只在穩定邊界埋點。

- [Risk] 進度太頻繁會讓輸出過多。
  -> Mitigation：長迴圈只在固定區間更新，例如每 5% 或每 N 筆輸出一次。

## Migration Plan

1. 建立 `progress-lib.sh`。
2. 先為 `preflight.sh`、`infer-candidates.sh`、`gen-openapi.sh` 接上 progress/timing。
3. 再補上 `confirm-candidates.sh`、`upload-apidog.sh`、`gen-html.sh` 的粗粒度進度。
4. 更新 `SKILL.md` 與驗證指引。
