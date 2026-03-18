## Context

在實際 Laravel 專案中，`infer-candidates.sh` 一次初始化推測的耗時約為：

- `class_index`: 約 16 秒
- `candidate_evaluation`: 約 245 秒
- `infer_total`: 約 264 秒

其中 `candidate_evaluation` 是絕對瓶頸。從 debug 可見：

- `prefilter passed=284 skipped=161 total_routes=445`
- `controller=284`
- `service_requested=118`

代表主要問題不是 route snapshot 本身，而是目前仍對過大的 route 工作集做深度 evaluation。

## Goals / Non-Goals

**Goals**
- 在深度 evaluation 前先把 route 工作集收斂到 commit-range-derived impacted subset。
- 降低 `candidate_evaluation` 中重複 lookup 的成本。
- 不改 `new / updated / deleted` 判定語意。
- 保持輸出 JSON 與 debug/timing 相容。

**Non-Goals**
- 不改 initialization/daily 分流。
- 不改 route hint / dependency hit 的語意。
- 不改 `new / updated / deleted` 的最終判定規則。

## Decisions

1. 先建立 `candidate_route_subset`
- 根據：
  - route action hints
  - changed controller actions
  - action-bound dependency hits
  - baseline `new` keys
- 先收斂出需要進深度 evaluation 的 route keys。

2. 把 prefilter 往前推
- 現在的 prefilter 在深度 evaluation 迴圈裡執行，雖然能 `continue`，但主迴圈與大量低成本 lookup 仍掃過整份 route snapshot。
- 調整後先產出 subset，再只對 subset 做 evaluation。

3. 預先建立低成本 lookup 結果
- 例如：
  - controller symbol -> file
  - changed file membership
  - route key membership
  - dependency-linked action hit
- 目的：減少 per-route 重複 `jq/grep/sed/awk`。

4. cache 只作為輔助
- 若某些 parser/cache 沒有穩定收益，不視為主方案。
- 只有在能配合 subset build 明顯減少重複解析時才保留。

5. subset build 需要細部 timing
- `candidate_subset` 降低了 evaluation 工作集，但自身仍可能成為新瓶頸。
- 必須再拆出 aggregate timing，例如：
  - key membership
  - controller lookup
  - direct hint checks
  - dependency gate
  - controller parse
  - dependency action link

6. `parse-controller.sh` 改為單次解析
- subset breakdown 已確認 `candidate_subset_controller_parse` 是最大耗時區段。
- 現有 `parse-controller.sh` 每次呼叫都會重複執行多段 `awk/grep/sed/perl/jq`，在數百次呼叫下成本過高。
- 改為單次解析流程：
  - 一次讀入 controller 檔案
  - 一次定位 method 與 PHPDoc
  - 以單次執行抽出 form request、resource、api response、service call、exception ref
- 目標是不改 JSON schema 與欄位語意，只降低每次 parse 的 subprocess 成本。



## Risks / Trade-offs

- [Risk] subset prefilter 若做得過度激進，可能漏掉應進入 evaluation 的 endpoint。
  -> Mitigation：subset 規則必須沿用現有判定訊號，只是把收斂步驟提前。

- [Risk] 新增 subset build 會讓程式更複雜。
  -> Mitigation：保持資料流明確，先 `subset build`，後 `evaluation`，避免兩階段互相穿插。

## Migration Plan

1. 在 `infer-candidates.sh` 新增 subset build 階段與必要 lookup helper。
2. 讓深度 evaluation 只處理 subset。
3. 保留輸出相容，驗證語法與候選結果仍可輸出。
4. 在實際 Laravel 專案重跑，觀察 subset 大小與 `candidate_evaluation` timing 變化。
5. 觀察 `candidate_subset_controller_parse` 與 `infer_total` 是否再下降。
