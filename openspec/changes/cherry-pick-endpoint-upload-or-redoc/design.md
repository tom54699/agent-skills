## Context

Cherry-pick 的核心需求是「從 `openapi.yaml` 取 subset，臨時使用」。現有腳本（`upload-apidog.sh`、`gen-html.sh`）都接受 `--openapi FILE`，只要能提供一個 temp subset spec 檔案就可以重用。Subset spec 組裝邏輯由 LLM 完成，不需要新腳本。

## Goals / Non-Goals

**Goals:**
- LLM 讀取 `openapi.yaml`，列出 endpoint 清單供使用者選取
- 支援描述式選取（「跟 User 相關的」）和明確列舉（`GET /users`, `POST /users`）
- LLM 組出 temp subset spec（`/tmp/cherry-pick-<timestamp>.json`），包含選定 paths 與完整 `info`/`servers`/`components`
- 選擇上傳：`upload-apidog.sh --openapi <temp> --skip-history --no-delta`
- 選擇 Redoc：`gen-html.sh --openapi <temp>`
- 不修改 `openapi.yaml`，不寫 sync history

**Non-Goals:**
- 不新增腳本（完全依賴現有 `upload-apidog.sh`、`gen-html.sh`）
- cherry-pick 不做 conflict detection（上傳前不拉 remote compare）
- cherry-pick 產出的 Redoc 不覆蓋 `docs/api-docs/redoc/`（寫到臨時位置或由使用者指定）

## Decisions

### D1：Subset spec 由 LLM 直接組裝，不走 PHP generator

Cherry-pick 的 subset 來自既有 `openapi.yaml`（已是最終結果），不需要重新解析 Laravel 原始碼。LLM 從 YAML 複製所選 paths，保留共用節點，寫成 temp JSON/YAML 即可。

這比引入新腳本更輕量，且 LLM 可以更靈活處理描述式選取（「跟付款相關的 API」）。

### D2：Temp spec 寫到系統 temp 目錄，不落地到 docs/

`/tmp/cherry-pick-<timestamp>.json`，不納入 git、不污染 `docs/api-docs/`。使用者有需要時可自行複製。

### D3：Cherry-pick 觸發條件由 SKILL.md 關鍵字決定

明確的觸發短語（不進入 guided-sync 主流程）：
- 「我只想上傳這幾個 API」
- 「單獨產這幾個 endpoint 的 Redoc」
- 「cherry-pick」、「挑幾個 API」

## Risks / Trade-offs

- **LLM 組 subset 可能遺漏 `$ref` 依賴**：若 selected paths 引用 `components/schemas` 裡的 ref，只要 components 完整保留就不會有問題。LLM 須確保 components 完整複製。
- **不做 conflict detection**：cherry-pick 上傳 Apidog 時跳過 conflict compare，可能覆蓋遠端手動修改。這是刻意設計（cherry-pick 是快速通道），SKILL.md 需說明此限制。
