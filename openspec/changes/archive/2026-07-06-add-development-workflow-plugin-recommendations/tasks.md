## 1. Init 訊號偵測

- [x] 1.1 在 `development-workflow init` 的「Inspect project signals」步驟，新增技術棧偵測：`composer.json` 含 `laravel/framework`、`requirements.txt`/`pyproject.toml` 存在、`package.json` 含前端框架、`schema.prisma` 存在
- [x] 1.2 新增偵測 `hookify` 是否已安裝，供 Hook Recommendations 小節引用

## 2. Plugin Recommendations 小節

- [x] 2.1 新增「Plugin Recommendations」小節，列出必裝層：`context7`、`skill-creator`、`hookify`
- [x] 2.2 新增依技術棧訊號複選層的對照表：PHP/Laravel → `laravel-boost`/`php-lsp`；Python → `pyright-lsp`；前端框架 → `figma`/`frontend-design`/`typescript-lsp`/`playwright`/`chrome-devtools-mcp`；Prisma schema → `prisma`
- [x] 2.3 新增條件式建議層：`security-guidance`（附三層防護說明、無公開 token 成本數據、建議先試用量測）、`claude-md-management`（附「無 hook、需主動觸發，但對 CLAUDE.md 品質的判斷是通用邏輯，不懂本專案 `development-workflow` 模板慣例，建議接受前自行審閱」的說明）
- [x] 2.4 新增明確排除清單：`code-review`/`code-simplifier`/`feature-dev`/`ralph-loop`/`mgrep`/`claude-context`，各附一句排除理由

## 3. Hook Recommendations 小節

- [x] 3.1 新增「Hook Recommendations」小節，說明用 `hookify` 設定「skill/guidance 檔案變更後提醒 refresh `.ai-project-index`」規則
- [x] 3.2 新增「commit 前若有未 archive 的 OpenSpec change 提醒先跑 `openspec validate --strict`」規則
- [x] 3.3 明講 hook 建立與是否啟用（warn/block）由使用者決定，skill 本身不建立任何規則檔

## 4. 模板更新

- [x] 4.1 `Init Output Shape` 模板，於 `OpenSpec: <found/missing/recommended?>` 行後新增 `Detected stack signals` 與 `Plugin recommendations`（Mandatory / Stack-specific / Conditional）欄位
- [x] 4.2 `Init Output Result` 模板，於 `Installed or recommended skills` 行後新增 `Installed or recommended plugins` 欄位

## 5. 驗證

- [x] 5.1 重讀 `skills/development-workflow/SKILL.md` 對應段落，確認四層 plugin 分類、Hook Recommendations、兩個模板更新皆已就位，措辭與既有 OpenSpec/`ai-project-index` 條件式寫法一致
- [x] 5.2 確認 `assets/AGENTS.template.md`、`assets/CLAUDE.template.md` 未被修改
- [x] 5.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py` 讓索引反映本次修改
- [x] 5.4 執行 `openspec validate add-development-workflow-plugin-recommendations --strict` 確認 artifacts 合規
