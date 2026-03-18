## Context

目前 `laravel-api-docs` 在掃描 Laravel routes 後，會直接把 `api/` 前綴裁掉，再讓 OpenAPI `servers.url` 承接 `/api`。這其實是一種 path strategy，而不是 Laravel route 的唯一正確表示方式。對某些專案來說，OpenAPI `paths` 應該保留 `/api/...`；對另一些專案來說，則希望 `servers` 吃掉 `/api`，讓 `paths` 保持 `/admin/...`。

問題在於，skill 現在把這個選擇硬編碼在 analyzer 與 generator 內：
- candidate inference 以裁掉 `/api` 後的 path 做比對
- OpenAPI generation 也以裁掉 `/api` 後的 path 生成文件

這使得初始化時若沒有先確認路徑策略，後續整個 guided-sync 都會沿用錯誤假設，導致：
- 本地 OpenAPI path 與使用者既有 Apidog path 風格不一致
- candidate diff / merge 容易失真
- `/api` 到底屬於 `paths` 還是 `servers.url` 變成隱性規則

## Goals / Non-Goals

**Goals:**
- 初始化時強制使用者確認 API path strategy。
- 將選定策略持久化，讓 daily inference、OpenAPI generation 與 merge 都沿用同一策略。
- 讓 debug / meta / 文件能清楚顯示目前專案採用哪種 path strategy。
- 讓 `/api` 前綴不再是 skill 內部硬編碼假設，而是顯式專案設定。

**Non-Goals:**
- 不在本次支援多個 prefix 同時混用。
- 不在本次自動推導所有專案的最佳策略；可以提供建議值，但最終仍由使用者確認。
- 不在本次重做整體 guided-sync 初始化流程，只擴充必要的決策與持久化欄位。

## Decisions

### 1. 初始化必選 path strategy，daily 一律沿用

- 決策：
  - 初始化流程新增 path strategy 選擇。
  - 至少提供兩個策略：
    - `keep-full-path`: 保留 Laravel route 原樣，例如 `/api/admin/login`
    - `strip-api-prefix-to-server`: 將 `/api` 視為 base path，`paths` 使用 `/admin/login`
  - 後續 daily 不再自動猜測，統一讀取已持久化策略。

- 原因：
  - 這是路徑契約，不是單次執行參數。
  - 若每次重新猜測，會導致歷史文件與新輸出互相打架。

- 替代方案：
  - 繼續使用硬編碼裁掉 `/api`。
  - 缺點是對保留完整 path 的專案永遠不相容。

### 2. 優先將 path strategy 寫入 sync history，避免引入新設定檔

- 決策：
  - 初始化成功後，將 `path_strategy` 寫入 success history record。
  - daily 以最後一筆 success history 的 `path_strategy` 作為主基準。
  - 若 history 尚未帶此欄位，才 fallback 到舊行為或引導使用者補選。

- 原因：
  - 目前 guided-sync 已以 success history 承接同步邊界。
  - 直接沿用 history，可減少新設定檔與額外同步問題。

- 替代方案：
  - 新增專門設定檔。
  - 缺點是多一份狀態來源，容易與 history 不一致。

### 3. 路徑 normalization 抽象化，analyzer 與 generator 共用

- 決策：
  - 將 route path normalization 從「固定裁掉 `api/`」改為「依 path strategy 決定如何正規化」。
  - analyzer 與 generator 必須使用同一套 normalization 規則。

- 原因：
  - 若兩者策略不一致，candidate route key 與生成出的 OpenAPI path 會錯位。

- 替代方案：
  - 只改 generator，不改 analyzer。
  - 缺點是候選比對仍會用另一套 path，問題只會換地方爆。

### 4. 預設建議值可根據現有 baseline 判斷，但不能取代使用者確認

- 決策：
  - 若初始化時已存在本地 `openapi.yaml` 或 Apidog 匯出，可根據現有 `paths` / `servers` 提供建議策略。
  - 但初始化仍需明確確認，不能完全自動決定。

- 原因：
  - 現有專案常已經有文件風格，skill 應盡量順著既有契約。
  - 但自動推斷仍有誤判風險，尤其當 `servers` 與 `paths` 原本就不一致。

## Risks / Trade-offs

- [Risk] 舊專案 history 沒有 `path_strategy`，daily 執行時仍可能不知道該沿用哪種表示法。
  -> Mitigation：對 legacy history 提供 fallback 與顯式提醒，必要時要求補選一次。

- [Risk] 一旦變更 path strategy，既有 `openapi.yaml` 與 Apidog path 可能整體位移。
  -> Mitigation：將策略視為初始化契約，後續不鼓勵頻繁切換；若要切換，應視為專案遷移。

- [Risk] `servers.url` 與 `paths` 的責任邊界在文件中若寫不清楚，使用者仍會困惑。
  -> Mitigation：在 `SKILL.md` 與 guided-sync 文件加明確對照範例。

## Migration Plan

1. 在初始化流程加入 path strategy 選擇與建議值邏輯。
2. 將 strategy 寫入 success history record，並讓 daily 讀取。
3. 抽出共用 path normalization，套用到 analyzer 與 generator。
4. 為 legacy history 補 fallback：缺少 strategy 時提供提醒或保守沿用舊行為。
5. 更新文件與測試，覆蓋兩種 path strategy 的 route / OpenAPI 輸出結果。

## Open Questions

- legacy history 缺少 `path_strategy` 時，daily 是否應直接中止要求補選，還是先保守沿用舊的 strip 行為？
- 若使用者同時有本地 `openapi.yaml` 與 Apidog remote，但兩者策略不一致，初始化應以哪個作為建議值？
