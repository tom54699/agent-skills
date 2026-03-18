## 1. 日常 range selection 與 history 契約調整

- [x] 1.1 調整 `Analyzer` 的日常 range selection，優先使用最後一筆 success history 的 `git_head_commit..HEAD`。
- [x] 1.2 補上 commit baseline 不可用時的 fallback 規則，保留 `synced_at` 時間窗作為相容路徑。
- [x] 1.3 更新 `SKILL.md` 與相關文件，明確說明日常模式以 commit baseline 為主、時間窗為 fallback。

## 2. Candidate inference 收斂規則重構

- [x] 2.1 修改 `candidate_subset`，移除 daily 模式下 baseline-new route 對工作集的直接擴張。
- [x] 2.2 修改 `candidate_resolver`，讓 daily `new` 僅由 route/action 變更訊號成立，`updated` 由 controller/request/resource/service/exception 訊號成立。
- [x] 2.3 保留 baseline 缺口統計作為 debug / meta diagnostics，而不是直接轉成 candidate。
- [x] 2.4 確認 `deleted` 仍只在 daily 且有 baseline 時由 route/baseline 差集產出。

## 3. History 輸出與觀測資訊補強

- [x] 3.1 檢查 `append-sync-history.sh` / `upload-apidog.sh`，確認 success history 穩定寫入 `git_head_commit`。
- [x] 3.2 擴充 candidate output meta/debug，區分 `last_success_commit`、`time_window_fallback` 等 range source。
- [x] 3.3 更新 debug 閱讀說明，區分 candidate signals、baseline diagnostics 與 delete diagnostics。

## 4. 文件更新

- [x] 4.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，同步新的 commit-driven 日常判定、fallback 規則與 baseline 責任邊界。
- [x] 4.2 在 `docs/` 新增或更新一份目前最完整的 guided-sync 流程說明，涵蓋初始化、日常、history、candidate inference、OpenAPI merge、Apidog sync 與常見 fallback。
- [x] 4.3 檢查本次變更涉及的其他文件是否需要同步修正，確保文件與實作一致。

## 5. 驗證與回歸

- [x] 5.1 在 thin-baseline 專案驗證：無 API 相關變更時不再產生全站 `new` 候選。
- [x] 5.2 驗證 route 新增、controller 變更、service/request/resource/exception 變更時，仍能正確收斂到 impacted endpoints。
- [x] 5.3 驗證 legacy history 缺少可用 `git_head_commit` 時，會退回時間窗策略且輸出可辨識的 fallback meta。
- [x] 5.4 執行語法與最小流程檢查，確認不影響既有 OpenAPI merge、Apidog sync 與 history append 路徑。
