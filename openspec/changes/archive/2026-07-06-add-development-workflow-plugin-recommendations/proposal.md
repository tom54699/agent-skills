## Why

一輪對 Claude Code plugin marketplace（`claude-plugins-official` 及少數外部 marketplace）的實測與查證，得出了哪些 plugin 適合這個專案、哪些跟既有 skill/OpenSpec 流程衝突、哪些有資料外送或成本疑慮的具體判斷。這些判斷目前只存在對話紀錄裡，下次初始化這個 repo 或任何新專案時都要重新討論一次。`development-workflow` 作為專案初始化的協調入口，應該把這些判斷沉澱成 init 流程的一部分，讓專案訊號偵測後能系統性地分類推薦 plugin，並提供把「應該執行的規則」升級成 hook 的建議路徑。

## What Changes

- `development-workflow init` 的專案訊號偵測，新增偵測 PHP/Laravel、Python、前端框架、Prisma 這幾種技術棧訊號
- 新增 Plugin Recommendations 邏輯，分四層：必裝、依偵測訊號複選、條件式建議（附成本/風險說明）、明確排除清單（附排除理由）
- 新增 Hook Recommendations 邏輯，建議用 `hookify` plugin 設定「skill/guidance 檔案變更後提醒 refresh `.ai-project-index`」與「commit 前若有未 archive 的 OpenSpec change 提醒先驗證」這兩條規則
- `Init Output Shape` 與 `Init Output Result` 模板新增對應欄位，呈現偵測到的技術棧與 plugin 推薦結果

不涉及 `assets/AGENTS.template.md`／`assets/CLAUDE.template.md`——plugin 安裝是一次性環境設定決策，不是要寫進生成給新專案的永久行為原則。

無 **BREAKING** 變更：現有 init 流程的既有步驟、既有模板欄位保持不變，這次是新增章節與新增欄位。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `development-workflow-skill`：`Init Command` 需求新增「偵測技術棧訊號、產生 plugin 推薦、產生 hook 建議」的情境；`Init Output Shape`/`Init Output Result` 呈現內容需求隨之擴充

## Impact

- 受影響檔案：`skills/development-workflow/SKILL.md`（唯一需要修改的實作檔案）
- 不影響：`assets/AGENTS.template.md`、`assets/CLAUDE.template.md`、其他 skill 的既有行為
- 不引入新的外部依賴——這次只是新增建議文字，不會自動安裝任何 plugin 或建立任何 hook 規則檔，實際安裝/設定仍由使用者依 init 產出的計畫另外決定
