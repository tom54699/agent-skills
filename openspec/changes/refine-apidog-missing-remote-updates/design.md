## Context

現在 `upload-apidog.sh` 對 confirmed `updated` 逐一比對本地與遠端 operation。若本地存在、遠端不存在，就直接產生：

- `conflict_type = missing_remote_endpoint`
- `suggested_action = use_local`

接著在 `keep_remote` 模式下，這批 endpoint 仍會被留在 conflict 集合內，最後不會用本地版本進入 upload payload。對初始化導入來說，這會讓「實際需要新建到 Apidog 的 updated endpoint」全部被擋住。

## Goals / Non-Goals

**Goals**
- 讓 `updated + remote missing` 在初始化/首次導入情境下可被安全同步。
- 保留真正欄位衝突的 `keep_remote / use_local / manual_merge` 契約。
- 讓 conflict file 能清楚區分「remote 缺少 operation」與「remote 已存在但欄位不一致」。

**Non-Goals**
- 不在這筆 change 內重做整個 Apidog export/import 流程。
- 不在這筆 change 內修改 `infer-candidates` 的 `updated` 判定語意。
- 不處理 path normalization 以外的複雜 remote matching 策略。

## Decisions

### 1. `updated + remote missing` 改為非阻斷型結果

當 confirmed `updated` endpoint 在本地存在、遠端不存在時：

- 仍輸出到 conflict evaluation 結果，方便觀察
- 但不將其視為需要 `keep_remote` 保留遠端版本的 hard conflict
- `keep_remote` 模式下，這類 endpoint 必須保留本地 operation 進 upload payload

理由：
- remote 根本沒有對應 operation，無 remote 內容可保留
- 初始化導入時，這通常代表「需要由本地建立」而不是「更新衝突」

### 2. conflict file 區分 blocking 與 informational

`missing_remote_endpoint` 仍保留在 conflict file 中，但增加可機器判讀的欄位：

- `blocking`: `false`

而真正欄位不一致或 local missing 仍為：

- `blocking`: `true`

理由：
- 保留可觀測性
- 讓後續策略可只針對 blocking conflict 決策

### 3. `keep_remote` 只套用 blocking conflicts

`apply_keep_remote_strategy()` 應只對 `blocking=true` 且 remote operation 存在的項目，用遠端內容覆寫本地 upload payload。  
對 `missing_remote_endpoint` 這類 informational result，不得移除或覆蓋本地 operation。

## Risks / Trade-offs

- 若 remote export 暫時缺漏 operation，可能讓本地上傳建立重複 endpoint。
  - 接受此風險，因為目前更大的問題是 updated 全被擋住。
- conflict file 會同時出現 blocking / non-blocking 項目。
  - 用 `blocking` 欄位降低解讀成本。

## Migration Plan

1. 調整 `detect_conflicts()` 對 `missing_remote_endpoint` 的輸出格式。
2. 調整 `apply_keep_remote_strategy()` 只處理 blocking conflicts。
3. 在代表性初始化情境驗證 `updated + remote missing` 會進 upload payload。
4. 更新 `SKILL.md` 與 OpenSpec tasks。
