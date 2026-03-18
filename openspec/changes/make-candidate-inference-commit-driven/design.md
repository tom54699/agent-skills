## Context

目前 guided-sync 的日常候選推測有兩個責任混在一起：

1. 用 `history` 決定「本次要看哪段 Git 範圍」
2. 用本地 `openapi.yaml` 判定「哪些 endpoint 算 candidate」

這在 baseline 完整時看起來可用，但在 `openapi.yaml` 覆蓋率很低時，`routeIndex - documentRouteKeys` 會把大量歷史 endpoint 視為 `new`。實際上，這些 endpoint 並不是本次 commit 範圍造成的變更，而是舊文件債。  

現有 history 已經保存 `git_head_commit`，但日常推測仍主要使用 `synced_at` 切時間窗。這讓 candidate inference 與真正的同步邊界產生偏差，也讓「上次成功同步後到目前 HEAD 的變更」無法被直接、穩定地表達。

限制條件：
- 保留 guided-sync 既有人工確認節點與 `new|updated|deleted` 基本輸出契約。
- 避免一次重寫 downstream OpenAPI generator / Apidog sync。
- 必須兼容舊 history 記錄，因為既有專案可能只有 `synced_at` 可用。

## Goals / Non-Goals

**Goals:**
- 日常模式以最後一筆成功同步的 `git_head_commit..HEAD` 作為主要 diff range。
- 候選推測以 commit 範圍內的 route / action / dependency 變更訊號為主，不再因 baseline 過薄而膨脹。
- baseline 不再直接決定 `new` 候選，只保留在 `deleted`、OpenAPI merge 與診斷資訊使用。
- 對 legacy history 提供 deterministic fallback，避免舊專案直接失效。
- 讓 debug / meta 能清楚說明本次是 commit-driven 還是 fallback-driven。
- 同步更新技能文件與 `docs/` 正式流程文件，讓日常、初始化、fallback 與 baseline 責任邊界有單一可讀來源。

**Non-Goals:**
- 不在本次引入新的 candidate 狀態，例如 `undocumented_existing`。
- 不重做 `gen-openapi`、`upload-apidog` 的整體契約。
- 不在本次解決「如何全量補齊歷史未入檔 API」的治理流程。

## Decisions

### 1. 日常 diff range 改以 `git_head_commit` 為主基準

- 決策：
  - 讀取最後一筆 `status=success` 的 history。
  - 若其中有合法 `git_head_commit` 且該 commit 仍存在於目前 repo，日常模式的 diff range 固定為 `<last_success_commit>..HEAD`。
  - `from_time` / `to_time` 仍可保留作觀測欄位，但不再是日常候選推測的主基準。

- 原因：
  - commit 比時間窗更符合「文件已同步到哪個版本」的語意。
  - 可避免時間窗包含無關 commit、遺漏 rebased commit，或在 thin baseline 下放大噪音。

- 替代方案：
  - 繼續使用 `synced_at`。
  - 缺點是只表達「大致時間」，不表達「明確同步邊界」，且與實際 Git 狀態較容易偏移。

### 2. 候選工作集改為純 change-signal 驅動

- 決策：
  - `candidate_subset` 僅由 commit 範圍命中的變更訊號組成：
    - `routes/*` 新增或修改命中的 action
    - controller action diff 命中
    - request / resource / service / exception 經 action 關聯命中
  - `routeIndex - documentRouteKeys` 只保留為 diagnostics，不再直接把 route 納入日常 candidate subset。

- 原因：
  - 候選清單的目的應是表達「本次變更影響哪些 API」，而不是表達「本地文件還缺哪些 API」。
  - 這可直接避免 baseline 很薄時的全站 `new` 爆量。

- 替代方案：
  - 保留 `baseline-new` 路徑，但加覆蓋率閾值。
  - 缺點是行為仍依賴 baseline 健康度，且不同專案仍會出現不可預期的分界。

### 3. 保留 `new|updated|deleted` 契約，但重定義 daily `new`

- 決策：
  - `new` 僅在 commit 範圍能證明 route 新增或 route mapping 新建時成立。
  - `updated` 用於 controller / request / resource / service / exception 等對既有 endpoint 的影響；即使該 operation 目前不在本地 OpenAPI，也仍允許 downstream 以 upsert 方式處理。
  - `deleted` 仍可由 baseline 與當前 route snapshot 比對得出，但只在日常模式且存在 baseline 時產出。

- 原因：
  - 保持輸出契約穩定，降低下游衝擊。
  - 避免把「本地缺文件」誤當成「本次新 API」。

- 替代方案：
  - 將 `new/updated` 合併為 `changed`。
  - 缺點是需要同步修改 confirm / generator / upload 契約，改動面太大。

### 4. legacy history 採 fallback 而非強制遷移

- 決策：
  - 若最後一筆 success 缺少 `git_head_commit`、commit 已不存在，或不屬於目前歷史，則退回既有 `synced_at` 推導策略。
  - `meta.diff_range_source` 與 debug 必須明確標示使用 `last_success_commit` 或 `time_window_fallback`。
  - 一旦後續同步成功，新寫入的 history 會自動補齊 commit 基準，逐步完成遷移。

- 原因：
  - 避免一次性要求所有專案重建 history。

- 替代方案：
  - 啟動時強制 migrate 舊 history。
  - 缺點是會增加導入成本，且對單次日常使用者不友善。

## Risks / Trade-offs

- [Risk] `git_head_commit` 可能因 rebase / force-push 不再存在於目前分支。
  -> Mitigation：fallback 到 `synced_at` 策略，並在 debug / meta 顯示原因。

- [Risk] 單靠 route diff 不一定能 100% 區分 route rename 與新 route。
  -> Mitigation：先沿用現有 route action hint 規則，並將 ambiguous case 保守視為 `updated` 而非擴大 `new`。

- [Risk] `updated` endpoint 在本地 baseline 缺失時，後續 merge 仍可能形成「實際新增但狀態為 updated」。
  -> Mitigation：保留 downstream upsert 行為，並在 reason/signals 中揭露 baseline 缺失，先求候選收斂正確。

- [Risk] 刪除判定仍依賴 baseline，若 baseline 落後，`deleted` 可能有噪音。
  -> Mitigation：維持目前 only-daily-with-baseline 的保守策略，不把 `deleted` 擴大到 initialization 或無 baseline 情境。

## Migration Plan

1. 調整 `Analyzer` 的 range selection，優先從 history 讀取 `git_head_commit` 生成日常 diff range。
2. 重構 daily candidate subset / resolver，移除 baseline-new 對候選收斂的直接影響。
3. 更新 history append 與 `SKILL.md`，明確宣告日常推測以 commit 基準為主、時間窗為 fallback。
4. 在代表性 thin-baseline 專案驗證：
   - `.gitignore` 等無 API 變更提交不再炸出全站 `new`
   - 真正 route/controller/service 變更仍能收斂到 impacted endpoints
5. 更新 `SKILL.md` 與 `docs/` 流程文件，補齊 commit baseline、fallback、candidate 判定與 baseline 責任邊界說明。
6. 若驗證失敗，可 rollback 為舊 range selection 與 baseline-new subset 規則。

## Open Questions

- route 檔案 diff 是否需要進一步抽出 method/path 層級訊號，取代目前只抓 `Controller@action` 的 hint？
- 是否要在 candidate meta 額外提供 `history_base_commit` 與 `fallback_reason`，方便使用者排查？
- 是否要在後續 change 中新增「歷史未入檔 API 治理模式」，與日常 candidate inference 明確拆開？
