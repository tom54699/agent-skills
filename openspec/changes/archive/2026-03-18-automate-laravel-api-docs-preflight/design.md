## Context

目前 Step 1 Preflight 在 `SKILL.md` 中已經定義要檢查：
- Laravel 專案根目錄（`artisan`、`routes/`）
- `.env.agents` 內的 `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`
- `.gitignore` 是否包含 `.env.agents`
- `docs/api-docs/*` 必要目錄

但這些規則沒有被程式化，因此代理可能基於「先做前半段也行」的假設跳過某些條件。使用者已明確指出這會破壞 skill-first 的執行一致性，因此需要自動化 preflight。

## Goals / Non-Goals

**Goals:**
- `preflight.sh` 要能在 Laravel 專案根目錄執行。
- 缺少必要條件時回傳非零退出碼並輸出明確錯誤。
- 成功時輸出 JSON，包含檢查結果與已建立的目錄資訊。
- 能被 guided-sync 主流程與後續腳本重用。

**Non-Goals:**
- 本次不自動寫入 `.env.agents` 內容。
- 本次不實作完整互動式補齊流程。
- 本次不變更候選推測與 OpenAPI 更新規則。

## Decisions

1. Preflight 由 shell script 落地，而不是只靠 LLM 對話控制。
- 原因：前置檢查是 deterministic 任務，shell 更適合保證一致性。

2. 缺少 `.env.agents` 或必要欄位時直接失敗。
- 原因：這是 `SKILL.md` 既有規則，script 應忠實實作，而不是重新解釋流程。

3. 必要目錄由 preflight 建立。
- 原因：這類操作 deterministic，且能減少後續腳本對目錄存在的假設。

4. 檢查 `.gitignore` 是否包含 `.env.agents`，若缺少則失敗。
- 原因：Step 1 已明定這是前置條件，且屬於安全保護。

## Expected Output

成功時輸出 JSON，例如：

```json
{
  "project_root": "/path/to/project",
  "checks": {
    "artisan": true,
    "routes_dir": true,
    "env_agents": true,
    "apidog_access_token": true,
    "apidog_project_id": true,
    "gitignore_env_agents": true,
    "jq": true,
    "yq": true
  },
  "created_dirs": [
    "docs/api-docs",
    "docs/api-docs/history",
    "docs/api-docs/candidates",
    "docs/api-docs/conflicts",
    "docs/api-docs/redoc"
  ],
  "ready": true
}
```

## Migration Plan

1. 新增 `preflight.sh`。
2. 更新 `SKILL.md`，要求 guided-sync 先跑 `preflight.sh`。
3. 後續如需，可讓 `infer-candidates.sh` 或 orchestration 在開始前統一呼叫它。
