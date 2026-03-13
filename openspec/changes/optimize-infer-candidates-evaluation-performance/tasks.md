## 1. OpenSpec

- [x] 1.1 新增效能優化 proposal/design/spec/tasks，明確限制為不改候選判定語意。

## 2. infer-candidates 實作

- [x] 2.1 在主迴圈前建立 `candidate_route_subset`。
- [x] 2.2 將 prefilter 往前推，讓 evaluation 只跑 subset。
- [x] 2.3 預先建立低成本 lookup / hint 結果，減少 per-route shell/jq/grep。
- [x] 2.4 保持既有 JSON/debug/timing 輸出格式相容。
- [x] 2.5 為 `candidate_subset` 增加細部 aggregate timing，能定位新的主瓶頸。
- [x] 2.6 將 `parse-controller.sh` 改為單次解析流程，降低 controller parse 的 subprocess 成本。

## 3. 驗證

- [x] 3.1 以 `bash -n` 驗證 `infer-candidates.sh` 語法。
- [x] 3.2 在實際 Laravel 專案重跑 `infer-candidates.sh`，確認能正常輸出候選清單。
- [x] 3.3 比較 subset 大小與 `candidate_evaluation` timing，確認有實質下降。
- [x] 3.4 比較 `candidate_subset` 細部 timing，確認新的主要耗時區段。
- [x] 3.5 比較 parser 改寫前後的 `parse-controller.sh` 輸出樣本，確認 JSON schema 與核心欄位相容。
- [x] 3.6 在實際 Laravel 專案重跑 `infer-candidates.sh`，確認 `candidate_subset_controller_parse` 或 `infer_total` 有再下降。
