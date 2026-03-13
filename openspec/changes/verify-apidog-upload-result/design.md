## Context

目前 Step 7 流程是：

1. 準備 upload payload
2. 呼叫 Apidog `import-openapi`
3. 只要 HTTP 200/201 就視為成功
4. 直接寫入 success history

但真實專案驗證顯示，Apidog import 可能回成功 counters，卻在後續 export 時仍只剩 schemas、`paths` 為空。這表示 import counters 不能作為唯一成功依據。

## Goals / Non-Goals

**Goals**
- 定義可驗證的 Step 7 成功條件。
- 避免把未真正落地到遠端的同步寫成 success history。
- 盡量重用既有 `export_remote_openapi_json()`，不增加新的外部依賴。

**Non-Goals**
- 不在這筆 change 內解出 Apidog import payload 的最終正確契約。
- 不在這筆 change 內重做 conflict compare。

## Decisions

### 1. 成功上傳後必須重新 export 驗證

在 `import-openapi` 返回 200/201 後，流程必須再執行一次 `export_remote_openapi_json()`，得到 post-upload remote spec。

### 2. 驗證範圍以 confirmed active candidates 為主

若提供 `--candidate-file`，則至少驗證 confirmed file 內所有 `new` 與 `updated` endpoint 在 remote export 裡可找到對應 `path + method`。

若未提供 `--candidate-file`，則退化成檢查 remote export 是否至少存在非空 `paths`。

### 3. 驗證失敗視為同步失敗

若 post-upload verification 未通過：

- 不得 append success history
- command 必須 non-zero exit
- 錯誤訊息需包含缺席 endpoint 數量與部分樣本

## Risks / Trade-offs

- 會多一次 remote export API 呼叫，Step 7 變慢一些。
- 若 Apidog export 本身延遲寫入，可能出現 false negative。
  - 先接受，必要時再補短暫 retry。

## Migration Plan

1. 在 `upload-apidog.sh` 補 `verify_remote_upload_result()`。
2. 將 verification 接到 `upload_request` 之後、`append_history` 之前。
3. 更新 `SKILL.md` 與 tasks。
