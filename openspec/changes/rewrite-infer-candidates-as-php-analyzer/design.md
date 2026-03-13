## Context

目前 `infer-candidates.sh` 的主要問題不是單點 bug，而是整體分析流程建立在 shell 管線與多支 parser 腳本上。即使局部熱點已經下降，總時間仍約 `240s`，原因是 route、controller、service 與 dependency 的資料在多個階段被反覆重新解析，成本很難再靠 cache 或小 patch 壓下來。

成熟工具的共同作法是：
- 一次建索引
- 單一程序記憶體內分析
- 將 CLI / progress / output 與核心分析引擎分離

這次要把 `infer-candidates` 朝這個方向重構。

## Goals / Non-Goals

**Goals:**
- 用單一 PHP 分析器取代 shell-heavy 候選推測核心。
- 一次建立 route / class / action / dependency 索引，避免重複 subprocess。
- 保持現有 `new / updated / deleted` 語意、JSON 結構與 guided-sync 流程相容。
- 保持 progress/debug/timing 可觀測性。
- 將 shell 腳本角色降為 wrapper，而不是主計算引擎。

**Non-Goals:**
- 不重新定義 candidate review 流程。
- 不變更 confirmed candidates -> openapi -> apidog 的後續鏈路。
- 不一次重寫整個 `laravel-api-docs` skill 的所有 shell 腳本。
- 不在這個 change 內追求完整 AST 精準度超越現有語意，只求等價與更快。

## Decisions

1. 以 PHP 作為分析核心，而不是繼續用 shell 微優化
- 原因：專案本身是 Laravel/PHP，使用 PHP 做檔案掃描、索引與 JSON 輸出最自然，也可直接共用專案環境。
- 不選 Python：雖然也可行，但會增加另一種執行語言與維護面。
- 不選繼續 shell：已證明局部優化的回報有限。

2. 將分析拆成明確四層資料模型
- RouteIndex：`method/path -> controller@action`
- ChangeIndex：changed files、changed classes、changed service methods
- ActionIndex：`controller@action -> form request / resource / service calls / exception refs / response signals`
- CandidateResolver：依 mode 與 baseline 決定 `new / updated / deleted`
- 原因：這樣才能把目前混在 route 迴圈裡的重複工作拆乾淨。

3. shell 保留為 thin wrapper
- `infer-candidates.sh` 保留：
  - 參數解析
  - preflight / env bridge
  - progress 顯示
  - 呼叫 PHP analyzer
- 核心分析搬到 PHP。
- 原因：保留既有使用方式與 skill 文件，不讓外部入口整個破壞。

4. parser 先維持「字串/結構解析」等價，不導入重量級 AST 依賴
- 第一版先將目前 `parse-controller.sh`、`parse-service.sh` 的責任收進 PHP 分析器，保留現有欄位與偵測規則。
- 是否導入 `nikic/php-parser` 之類 AST 工具，列為後續可選。
- 原因：先達成等價與效能，不先引入更大風險。

5. timing 與 debug 改成 event-based
- PHP analyzer 輸出 machine-readable progress/timing event。
- shell wrapper 將 event 轉成目前的 checklist / progress bar / timing 行。
- 原因：這樣可以保留使用者體驗，同時讓分析器本身更容易測試。

## Risks / Trade-offs

- [Risk] 重寫後 candidate 語意不一致。
  -> Mitigation：以現有 `status/method/path` 為回歸基準，逐批比對真實 Laravel 專案輸出。

- [Risk] 先不用 AST 可能保留部分既有不精準處。
  -> Mitigation：這次優先追求等價與速度；精準度提升另開 change。

- [Risk] PHP analyzer 與 shell wrapper 共存一段時間會增加過渡成本。
  -> Mitigation：明確規定 shell 只做 wrapper，不再新增 shell 版分析邏輯。

## Migration Plan

1. 新增 PHP analyzer 入口與核心類別/模組。
2. 先實作與現有 shell 等價的 route/class/change/action 索引。
3. 讓 `infer-candidates.sh` 支援切換到 PHP analyzer，並保持現有輸出格式。
4. 在真實 Laravel 專案做回歸：
   - `status/method/path`
   - debug/timing 可讀性
   - `infer_total`
5. 通過後移除舊 shell-heavy subset/evaluation 主邏輯。

## Open Questions

- 是否需要直接引入 AST library，還是先以原生 token/regex 結構解析過渡。
- PHP analyzer 的檔案放在 `bin/` 還是 `src/`，以及是否需要簡單的測試入口。
