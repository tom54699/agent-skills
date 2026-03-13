## 1. OpenSpec

- [x] 1.1 確認 `gen-openapi` 改寫 proposal / design / specs / tasks 完整落地。

## 2. PHP Generator 骨架

- [x] 2.1 新增 PHP OpenAPI generator 入口，能接收 `gen-openapi.sh` 現有參數。
- [x] 2.2 建立 route / candidate / operation / merge 四層資料模型。
- [x] 2.3 實作 progress/timing event 輸出，供 shell wrapper 延用既有 UI。

## 3. 解析與輸出搬移

- [x] 3.1 將 controller parser 內聚到 PHP generator。
- [x] 3.2 將 FormRequest parser 內聚到 PHP generator。
- [x] 3.3 將 service parser 內聚到 PHP generator。
- [x] 3.4 將 operation 組裝與 candidate-driven endpoint 輸出搬進 PHP generator。
- [x] 3.5 將 `--incremental` / `--base` / `--candidate-file` 的 merge 與 delete 邏輯搬進 PHP generator。
- [x] 3.6 讓 `gen-openapi.sh` 改為呼叫 PHP generator，移除 shell parser 主路徑。

## 4. 回歸與文件

- [x] 4.1 在真實 Laravel 專案比對 candidate-driven `openapi.yaml` 關鍵欄位與現有穩定版相容。
  - 已在 `/Users/athena/Herd/myan-ride` 以代表性 GET `/user/user-config` 與 POST `/user/login/password` 做 candidate-driven 驗證。
  - summary / description / tags / 固定 responses 與 requestBody 欄位皆與舊 shell parser 規則相容，且成功產出 `docs/api-docs/openapi.yaml` 並通過 YAML 結構檢查。
- [x] 4.2 比較 `gen-openapi` 主要 timing，確認 subprocess 與總耗時下降。
  - 在 `/Users/athena/Herd/myan-ride` 的兩條 representative candidate 下，PHP generator 完整 `openapi_total` 約 `1937ms`。
  - 重建的 legacy shell 路徑即使做最小 escape 修補，僅 `route_snapshot + candidate_normalization` 就已約 `1997ms`，且在進入 endpoint generation 前即因額外 shell/jq fragility 失敗。
  - 可確認 PHP generator 不僅減少 parser subprocess，且整體完成時間已低於舊 shell 路徑尚未完成前的耗時。
- [x] 4.3 更新 `skills/laravel-api-docs/SKILL.md`，說明 OpenAPI 生成改由 PHP generator 提供。
- [x] 4.4 降級或移除 `parse-controller.sh`、`parse-service.sh`、`parse-form-request.sh` 在主路徑的角色。
  - `gen-openapi.sh` 主路徑已不再呼叫三支 shell parser；後續收尾 change 已將過渡 shell parser 自 runtime 移除。
