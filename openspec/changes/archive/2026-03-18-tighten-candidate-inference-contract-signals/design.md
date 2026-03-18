## Context

目前 candidate inference 的主要問題，不再是 baseline 爆量，而是「命中了不該命中的更新」。在 `myan-ride` 的 `ff619fdd` 驗證中，以下現象很明顯：

- `SmsCacheController` 兩支 admin API 因 request 與 controller 變更而命中，合理。
- 多支 `SMSController` OTP API 因 method body 內的 scenario 字串改成 enum 而命中，是否需要更新文件其實存疑。
- `DriverService` / `UserService` 帶出的 register / reset / OTP 相關 API 因 service error-contract 推導而命中，但實際 diff 看起來多是 enum 化與 cache key 參數型別調整，不足以證明外部 error contract 真的改變。

這表示目前規則雖已排除大量 internal-only service 改動，但 controller body diff 仍被視為過強訊號，service exception metadata 也仍偏寬。

為了讓 guided-sync 真正對準「文件是否需要更新」，下一步應把規則收斂成：
- 強訊號：可直接代表文件契約或文件內容改變
- 弱訊號：只代表程式有改，但不一定需要動文件

## Goals / Non-Goals

**Goals:**
- 將 candidate inference 訊號正式分成強訊號與弱訊號。
- function 文件註解變更列為強訊號。
- 純 controller method body diff 不再直接成立 `updated`。
- 純 service method body diff 不再直接成立 `updated`。
- `reason` / `signals` 能清楚看出是哪一類訊號讓候選成立。

**Non-Goals:**
- 不引入新的 candidate status。
- 不重寫 parser 架構。
- 不在本次支援所有自定義 annotation 語法，只處理目前可穩定映射到 OpenAPI 的註解訊號。

## Decisions

### 1. 導入強訊號 / 弱訊號模型

- 決策：
  - 強訊號：
    - route / endpoint mapping 變更
    - FormRequest / inline validation 變更
    - Resource / response metadata / response annotation 變更
    - exception mapping / error contract 變更
    - function 文件註解變更
  - 弱訊號：
    - controller method body diff
    - service method body diff
  - 候選成立規則：
    - 強訊號可直接產生 `updated`
    - 弱訊號必須搭配至少一個強訊號，或能被解析成明確 contract evidence

- 原因：
  - 這可直接抑制 enum refactor、參數型別替換、內部 helper 調整等造成的假陽性。

### 2. function 文件註解列為第一級文件訊號

- 決策：
  - 將 function phpdoc 中可映射到 OpenAPI 的註解列為強訊號：
    - description / summary
    - `@queryParam`
    - `@bodyParam`
    - `@urlParam`
    - `@response`
    - `@responseFile`
    - `@responseField`
  - 一般 comment、TODO、純開發備註不算強訊號。

- 原因：
  - 這是使用者明確指出的重要文件來源。
  - 文件註解改了，即使程式行為沒變，也應該觸發文件更新。

### 3. controller body diff 改為弱訊號

- 決策：
  - `isChangedControllerAction()` 命中不再直接產生 `updated`。
  - 只有當 controller diff 同時伴隨：
    - 文件註解變更
    - request/response metadata 變更
    - exception contract 變更
    - route mapping 變更
    時，才成立候選。

- 原因：
  - controller method body 內部很容易出現 enum refactor、service 參數調整、局部變數修改，這些不應單獨構成文件更新。

### 4. service error-contract 推導改為「可證明改變」

- 決策：
  - service method 只有在 diff 內容本身能證明改到 error contract / response contract 時，才作為強訊號。
  - 僅因該 method 存在 exception metadata，不足以視為 error-contract change。
  - enum / cache key / 參數型別替換這類 diff，預設視為弱訊號或忽略。

- 原因：
  - 目前這正是 `DriverService` / `UserService` 噪音的來源。

## Risks / Trade-offs

- [Risk] controller body diff 收太緊後，少數沒有註解、沒有 request/resource，但實際 response 有變的 action 可能漏抓。
  -> Mitigation：保留 route、exception、response annotation 與未來更細的 response analyzer 作為補強，不回頭把 body diff 重新放寬。

- [Risk] service diff 若只從文字內容判定 contract evidence，可能漏掉藏得很深的 response/error payload 改動。
  -> Mitigation：先優先解決大面積假陽性；若後續專案確實有這類模式，再針對特定 pattern 補 analyzer。

- [Risk] function 註解格式不一致時，解析可能不穩。
  -> Mitigation：只承諾目前可穩定辨識的 annotation 類型，不做過度推論。

## Migration Plan

1. 定義強訊號 / 弱訊號欄位與成立規則。
2. 調整 `Analyzer` subset / resolver，讓 controller/service body diff 退為弱訊號。
3. 補強 `ControllerParser` / `ActionMetadata`，擴充 function 文件註解訊號。
4. 補測試：
   - function 註解變更會命中
   - 純 enum refactor / 純 body diff 不會單獨命中
   - request / response / error contract 變更仍會命中
5. 以 `myan-ride` 的 `ff619fdd` 回歸，確認候選由 20 支收斂到更合理的範圍。

## Open Questions

- 第一版是否需要把 `@response` / `@responseField` 細拆成不同 signal，還是先統一視為 response documentation signal？
- 對沒有 phpdoc 但有 `apiResponseCount` 的 action，是否仍視為強訊號來源？我傾向保留。
