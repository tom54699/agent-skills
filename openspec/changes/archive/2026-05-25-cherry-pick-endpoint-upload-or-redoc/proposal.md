## Why

目前 guided-sync 是全流程綁定的，無法脫離完整流程單獨處理幾個特定 API。使用者有時只想「把這幾個 endpoint 上傳 Apidog」或「只針對這幾個 API 產一份 Redoc 給對接方看」，但現有腳本不支援，只能靠 LLM 手動組 YAML，容易出錯且不一致。

## What Changes

- `SKILL.md` 新增 `cherry-pick` 模式：使用者指定幾個 endpoint（描述式或明確列舉），LLM 從 `openapi.yaml` 組出 temp subset spec，不落地也不修改主檔，選擇上傳 Apidog 或產 Redoc HTML。
- Temp subset spec 不寫入 `openapi.yaml`，不寫 sync history（以 `--skip-history` 執行）。
- 上傳到 Apidog 走 `--no-delta`（subset spec 本身就是要全數上傳的內容）。

## Capabilities

### New Capabilities

- `cherry-pick-mode`: LLM 主導的選擇性 endpoint 處理模式，從現有 `openapi.yaml` 取 subset，支援上傳 Apidog 或產 Redoc，不修改主檔或 sync history。

## Impact

- `skills/.curated/laravel-api-docs/SKILL.md`：新增 cherry-pick 模式觸發條件與流程規格
- `scripts/` 無新增腳本；重用 `upload-apidog.sh --skip-history --no-delta` 與 `gen-html.sh`
