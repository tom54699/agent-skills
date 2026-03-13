## 1. OpenSpec

- [x] 1.1 建立 PHP 單程序分析器重寫 proposal/design/tasks，明確停止再以 shell 微優化為主。

## 2. 分析器骨架

- [x] 2.1 新增 PHP analyzer 入口，能接收現有 `infer-candidates.sh` 所需參數。
- [x] 2.2 建立 route/class/change/action 四層索引資料模型。
- [x] 2.3 實作 progress/timing event 輸出，供 shell wrapper 轉成既有 UI。

## 3. 候選推測等價實作

- [x] 3.1 實作 initialization / daily mode 分流與 baseline 載入。
- [x] 3.2 實作 `new / updated / deleted` 等價判定。
- [x] 3.3 將 controller/service/request/resource/exception 關聯判斷搬進 PHP analyzer。
- [x] 3.4 讓 `infer-candidates.sh` 改為呼叫 PHP analyzer，保留既有 JSON/debug 契約。
  - `infer-candidates.sh` 已降為 thin wrapper，僅保留 PHP analyzer 入口與 progress/timing adapter。

## 4. 回歸與文件

- [x] 4.1 在真實 Laravel 專案比對 `status/method/path` 與現有穩定版等價。
  - 在 `/Users/athena/Herd/myan-ride` 與 shell 穩定版比對時，PHP analyzer 多出 4 條 `SMSController -> SmsService::verifyOtp` 路由。
  - 經定點檢查，這 4 條 route action、controller parser、service method diff 與 dependency link 條件皆成立，採納為 shell 既有遺漏，PHP analyzer 結果作為新基準。
- [x] 4.2 比較 `infer_total` 與主要 breakdown，確認有明顯下降。
  - 同一專案與 commit 範圍下，shell 約 `145521ms`，PHP analyzer 約 `2925ms`。
- [x] 4.3 更新 `skills/laravel-api-docs/SKILL.md`，說明候選推測改由 PHP analyzer 提供。
- [x] 4.4 清理或降級舊 shell-heavy 分析邏輯，避免雙邏輯並存。
  - 舊 shell-heavy inference 已自 `infer-candidates.sh` 移除；後續 `gen-openapi` 也完成 PHP 化後，過渡 shell parser 已一併退出主路徑。
