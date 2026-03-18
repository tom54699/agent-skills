## Context

`gen-openapi.sh` 目前已負責 candidate-driven OpenAPI 更新，但真正的內容解析仍分散在 `parse-controller.sh`、`parse-service.sh`、`parse-form-request.sh`。這代表 OpenAPI 生成鏈路仍保留 shell-heavy 結構：同一份 controller / service / request 會在不同階段被重複讀取與解析，並透過多個 subprocess 回傳 JSON，再由 shell 合成 YAML。

`infer-candidates` 已證明單一 PHP 分析器可顯著改善效能與穩定性，因此 `gen-openapi` 應沿用同一策略，把 parser 與核心生成邏輯收進單一 PHP 程序。

## Goals / Non-Goals

**Goals:**
- 用單一 PHP generator 取代 `gen-openapi.sh` 目前依賴的 shell parser 主路徑。
- 保持 `gen-openapi.sh`、`--incremental`、`--candidate-file`、`--base` 的外部契約相容。
- 在 PHP generator 內完成 controller / service / form request 解析與 OpenAPI operation 組裝。
- 讓 `infer-candidates` 與 `gen-openapi` 共用相同的 PHP 解析能力，降低雙邏輯漂移。

**Non-Goals:**
- 不在這筆 change 內重寫 Apidog upload 與 HTML 產生流程。
- 不重新定義 confirmed candidate list 的格式。
- 不在這一輪移除所有 shell 腳本；只處理 `gen-openapi` 主路徑。
- 不追求一次導入完整 AST 依賴，先以現有 PHP token / regex parser 能力等價搬移。

## Decisions

1. `gen-openapi.sh` 保留為 thin wrapper
- shell 只保留參數解析、preflight、呼叫 PHP generator、落檔與進度轉譯。
- 不再在 shell 內直接呼叫 `parse-controller.sh`、`parse-service.sh`、`parse-form-request.sh`。

2. 新增 PHP OpenAPI generator
- 新 generator 負責：
  - 讀取 route list / candidate file / base OpenAPI
  - 解析 controller action metadata
  - 解析 FormRequest rules
  - 解析 service exception / response signals
  - 組裝 operation 並輸出最終 OpenAPI
- 這樣可避免同一 endpoint 生成時反覆開 subprocess。

3. parser 先共用既有 PHP 能力
- 優先複用或抽取 `InferCandidates` 已有的 `ControllerParser`、`ServiceParser`、`FormRequestParser`。
- 若欄位不完全相同，再補 generator 專用 adapter，而不是再回頭新增 shell parser 分支。

4. merge / delete 邏輯保留在 generator 內
- `--candidate-file`、`--incremental`、`--base` 的結果合併與刪除操作直接在 PHP 內完成。
- shell 不再先產碎片 YAML 再交給外部工具拼裝。

## Risks / Trade-offs

- [Risk] parser 內聚後，產出的 OpenAPI 欄位與舊版不完全一致。
  -> Mitigation：以現有 `openapi.yaml` 關鍵欄位與 candidate-driven 輸出為回歸基準。

- [Risk] `infer-candidates` 與 `gen-openapi` 共用 parser 後，若 parser 有 bug 會同時影響兩條鏈路。
  -> Mitigation：保留獨立 wrapper 與針對 parser 的最小回歸測試。

- [Risk] 一次搬移 merge / delete / operation 組裝可能讓 change 太大。
  -> Mitigation：先完成 parser 與 operation generation 內聚，再處理 merge / delete。

## Migration Plan

1. 新增 PHP generator 入口與模組骨架。
2. 將 controller / service / form request parser 內聚到 generator。
3. 讓 `gen-openapi.sh` 改為呼叫 PHP generator。
4. 以 candidate-driven 與 incremental 兩條路徑做最小回歸。
5. 通過後再降級舊 shell parser 的主路徑角色。

## Open Questions

- parser 類別應抽成共用 namespace，還是先由 OpenAPI generator 直接引用 `InferCandidates` 內的 parser。
- OpenAPI merge 是否完全移入 PHP，或短期仍保留部分 `yq` 輔助。
