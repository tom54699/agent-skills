## Context

一次全面盤點（Explore agent，涵蓋四個 skill）確認 `development-workflow` 的版本識別缺口已由 `sync-development-workflow-existing-projects` 處理。這份 change 處理盤點時發現的另外三個 skill：

- `ai-project-index` 的版本欄位是純裝飾——寫了但沒有任何比對邏輯，风险最高
- `laravel-api-docs` 有一個欄位級的 fallback 先例（`path_strategy`），但沒有系統化 schema version
- `business-logic-workflow` 完全沒有版本概念，純自由格式 Markdown

三者風險等級不同，處理深度也不同：`ai-project-index` 值得投入真正的比對邏輯（JSON 格式，被程式讀取，靜默不相容的代價最高）；後兩者這次只建立標記，不建立比對邏輯（純文字/單一 jsonl 欄位，人工可讀，風險與投入成本都較低）。

## Goals / Non-Goals

**Goals:**
- 讓 `ai-project-index` 的版本欄位從裝飾性變成真正會被比對的機制，比對不符時走既有的 `warning_audit()` 路徑
- 三個 skill 的 `SKILL.md` frontmatter 都有 `metadata.version`
- `laravel-api-docs` 的同步歷史新增 `schema_version` 欄位，並延續既有的向後相容慣例（缺欄位時容錯，不強制遷移）
- `business-logic-workflow` 的輸出文件標記產生時的 skill 版本

**Non-Goals:**
- 不建立 `laravel-api-docs`／`business-logic-workflow` 的自動版本比對邏輯——這次只建立標記，比對邏輯留待未來真的需要時再設計
- 不追溯修改任何既有的歷史紀錄或既有產出文件——只影響這次更新之後新產生的資料
- 不建立跨 skill 統一的版本管理框架——四個 skill 各自维护自己的 `metadata.version`，這次不引入額外的版本協調機制

## Decisions

**1. `ai-project-index` 的版本比對，重用既有的 `warning_audit()` 函式，不新增獨立的錯誤處理路徑**
`audit-index.py` 已經有 `warning_audit(args, root, reason, detail)` 這個函式處理「index 讀不到／格式不對」的情況，新增一個 `version_mismatch` reason 直接複用這條路徑，符合 Surgical Changes 精神——只加必要的東西，不重新發明一套錯誤處理機制。

**2. `laravel-api-docs` 用「新增欄位＋沿用既有 fallback 慣例」，不追溯改寫歷史資料**
既有規則本來就是「日常與 generator 優先沿用最後一筆 success 的 `path_strategy`；若 legacy history 缺少該欄位，才回退偵測或舊預設」——`schema_version` 採用同樣的容錯精神：沒有這個欄位的舊紀錄視為隱含版本，讀取邏輯不強制要求它存在。

*替代方案考慮過*：強制要求所有歷史紀錄升級補上 `schema_version`。捨棄理由：舊紀錄是不可變的歷史事實，追溯改寫違反「不確定內容不得寫成已確認事實」的精神，也不符合現有的向後相容慣例。

**3. `business-logic-workflow` 只加一行 `Generated-by`，不建立比對邏輯**
Business Logic Brief/As-Is/Delta 是給人看、給人審閱的文件，不是被程式解析的資料格式，就算版本不符也不會造成程式錯誤，只需要讓人在讀文件時知道「這是哪個版本產生的」，不需要額外的機器可讀比對機制。

## Risks / Trade-offs

- **[風險] 三個 skill 各自的 `metadata.version` 沒有統一的升版流程，可能各自漂移、版本號意義不一致** → **緩解**：這次只建立最小基礎，統一的版本管理流程留給未來有實際需求時再設計，避免這次過度設計
- **[風險] `ai-project-index` 新增的版本比對，如果腳本自身版本號忘記同步更新，可能誤判所有既有專案都是「版本不符」** → **緩解**：版本比對只在 `index.get("version")` 存在且與腳本期望值不同時才觸發 warning；同一次改動裡腳本輸出的版本號與比對邏輯用同一個常數，不會出現腳本剛發布就自我誤判的情況
- **[風險] `laravel-api-docs` 新增 `schema_version` 欄位後，若後續維護者忘記在新增欄位時同步更新版本號，這個欄位一樣可能淪為裝飾性** → **緩解**：這是流程紀律問題，不是這次技術變更能完全解決的，只能透過 SKILL.md 裡明確寫出「新增/改名欄位時需要考慮是否升版」提醒未來的維護者

## Migration Plan

無需資料遷移。三個 skill 都是純新增（欄位、標記行、比對分支），既有輸出格式與既有資料不受影響，套用後從下一次執行開始生效。
