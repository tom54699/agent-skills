## Why

使用者檢視 README 後指出兩個 Plugin Recommendations 流程的實務缺口：一是從沒問過「這些 plugin 要裝在哪個範圍」（Claude Code 的 user/project/local scope 會直接影響是否跟著 repo 走、隊友能不能一起用到）；二是依技術棧訊號推薦的 plugin，目前只是寫進 init 計畫文字裡讓使用者自己看到，不夠主動，容易被忽略。

## What Changes

- Plugin Recommendations 新增安裝範圍決策：必裝層預設建議 user（全域）scope；依訊號複選層與條件式層預設建議 project（共享）scope；不管哪一層，最終範圍都要讓使用者確認或覆寫
- 依技術棧訊號複選的 plugin，從「寫進計畫文字」改為**必須使用 AskUserQuestion 工具做明確的複選提問**，而不是嵌在文字計畫裡讓使用者自己找
- `Init Output Shape` 模板新增欄位呈現每個 plugin 的安裝範圍決定

無 **BREAKING** 變更：純新增決策步驟與呈現欄位。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `development-workflow-skill`：`Plugin Recommendations` requirement 新增安裝範圍決策與主動複選提問的情境

## Impact

- 受影響檔案：`skills/development-workflow/SKILL.md`
- 不影響：`assets/AGENTS.template.md`、`assets/CLAUDE.template.md`、其他 skill
