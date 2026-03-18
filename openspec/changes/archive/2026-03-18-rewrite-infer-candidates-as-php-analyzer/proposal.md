## Why

目前 `infer-candidates.sh` 雖然已做過局部優化，但整體耗時仍約 4 分鐘，對「只是推測本次 API 變更」來說不可接受。問題核心不是單一熱點，而是整體實作仍以 shell、`jq`、`awk`、`grep` 與多支子腳本反覆組合，難以再靠小修取得有感改善。

## What Changes

- 將 `infer-candidates` 的核心分析流程改寫為單一 PHP 分析器，不再由 shell 當主要計算引擎。
- 將 route snapshot、class index、changed files、changed service methods、controller/action 關聯改為一次建索引、記憶體內分析。
- 保留現有 guided-sync 對外契約：
  - 候選 JSON 結構
  - `new / updated / deleted` 語意
  - `--debug` / progress / timing 輸出
  - 初始化 / 日常模式分流
- shell 腳本改為 orchestration wrapper，負責 preflight、參數處理、呼叫 PHP 分析器與落檔。
- 逐步淘汰目前高成本的 shell-heavy subset/evaluation 邏輯。

## Capabilities

### New Capabilities
- `laravel-api-docs-php-candidate-analyzer`: 以單一 PHP 程式完成候選 API 推測、索引建立與 impacted endpoint 分析。

### Modified Capabilities
- `laravel-api-docs-candidate-evaluation-performance`: 將效能優化主軸從 shell 局部調整，改為單程序分析器。
- `laravel-api-docs-guided-sync`: guided-sync 的候選推測實作改由 PHP 分析器提供，但外部流程與輸出契約維持相容。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/.curated/laravel-api-docs/scripts/parse-controller.sh`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - 新增 `skills/.curated/laravel-api-docs/bin/` 或 `skills/.curated/laravel-api-docs/src/` 下的 PHP 分析器
- 影響行為：
  - 候選結果與現有 `status/method/path` 應維持等價
  - `infer_total` 目標應明顯低於目前 shell 版
  - debug/timing 改為由 PHP 分析器輸出結構化事件，再由 wrapper 呈現
