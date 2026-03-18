## 1. 規格與共用層

- [x] 1.1 新增 progress/timing 的 OpenSpec spec，定義 checklist、進度條與 timing 輸出契約。
- [x] 1.2 新增 `skills/.curated/laravel-api-docs/scripts/progress-lib.sh`，集中管理步驟定義、進度條與 timing helper。
- [x] 1.3 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明 guided-sync 的進度與慢點分析方式。

## 2. 粗粒度腳本進度

- [x] 2.1 為 `preflight.sh` 加入步驟進度與完成勾選輸出。
- [x] 2.2 為 `confirm-candidates.sh`、`upload-apidog.sh`、`gen-html.sh` 加入步驟進度輸出。
- [x] 2.3 保持上述腳本既有 `stdout` JSON 結果格式不變。

## 3. 候選推測可觀測性

- [x] 3.1 為 `infer-candidates.sh` 加入主要階段 progress/timing 埋點。
- [x] 3.2 為 candidate evaluation 主迴圈加入數量型進度更新，避免長時間無輸出。
- [x] 3.3 在結果中加入 timing summary，方便事後分析瓶頸。

## 4. OpenAPI 生成可觀測性

- [x] 4.1 為 `gen-openapi.sh` 加入主要階段 progress/timing 埋點。
- [x] 4.2 為 endpoint generation 主迴圈加入數量型進度更新。
- [x] 4.3 在結果中加入 timing summary，方便比對 merge / delete / write 的耗時。

## 5. 驗證

- [x] 5.1 以 `bash -n` 驗證所有修改過的腳本語法。
- [x] 5.2 以最小樣本實跑 `preflight.sh`、`confirm-candidates.sh`，確認 progress 只出現在 `stderr`。
- [x] 5.3 在實際 Laravel 專案重新跑 `infer-candidates.sh`，確認可直接看出慢點所在。
