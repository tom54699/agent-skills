## 1. Skill 文件重構

- [x] 1.1 重寫 `skills/.curated/laravel-api-docs/SKILL.md` 為單一 `guided-sync` 流程。
- [x] 1.2 移除舊的三模式互動描述，改為「AI 先猜清單 -> 討論確認 -> 執行」。
- [x] 1.3 明確定義同步順序：更新 OpenAPI -> 上傳 Apidog -> 產生 HTML。

## 2. 同步歷史契約

- [x] 2.1 在 `SKILL.md` 新增 `docs/api-docs/history/apidog-sync-history.jsonl` 的欄位契約。
- [x] 2.2 定義基準選擇規則（以 `synced_at` 時間切 Git 範圍）。

## 3. 流程細化

- [x] 3.1 將 `Step 6` 定義為同步與衝突處理，並輸出衝突清單。
- [x] 3.2 將 `Step 7` 改為詢問是否產生 HTML，`Step 8` 才執行產生。
- [x] 3.3 補上 `Step 5` 深度分析項目（Controller/Service/FormRequest/Exception/Resource）。

## 4. 後續腳本對齊（下一階段）

- [x] 4.1 新增或調整 script 以輸出候選清單（含 reason/confidence）。
- [x] 4.2 新增同步成功後 append 歷史紀錄的 script。
- [x] 4.3 補上跨平台相容性修正（避免 `grep -P` 等問題）。
- [x] 4.4 清理舊流程未使用 scripts，避免維護混淆。
