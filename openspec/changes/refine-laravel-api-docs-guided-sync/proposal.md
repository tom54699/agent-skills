## Why

目前 `laravel-api-docs` 技能流程過長且重複掃描，使用者在日常開發時需要更快地完成「推測變更 API -> 討論確認 -> 更新文件 -> 同步 Apidog」。
同時缺少同步歷史紀錄，導致 AI 無法以「上次成功同步點」作為推測範圍基準。

## What Changes

- 將技能流程收斂為單一模式 `guided-sync`。
- 改為 AI 先根據上次同步紀錄與 Git 變更範圍推測候選 API 清單，再與使用者討論確認。
- 以確認後清單為唯一分析範圍，更新 `docs/api-docs/openapi.yaml`。
- 固定流程為：更新 OpenAPI -> 上傳 Apidog（含衝突處理）-> 依需求產生 Redoc HTML。
- 新增同步歷史檔案契約：`docs/api-docs/history/apidog-sync-history.jsonl`，每次成功上傳都必須寫入一筆紀錄。

## Capabilities

### New Capabilities
- `laravel-api-docs-guided-sync`: 使用單一引導模式推測並同步 API 文件，並維護同步歷史基準。

### Modified Capabilities
- None.

## Impact

- 影響檔案：`skills/laravel-api-docs/SKILL.md`
- 可能影響腳本：`skills/laravel-api-docs/scripts/*.sh`（後續依契約補強）
- 新增資料檔案契約：`docs/api-docs/history/apidog-sync-history.jsonl`
