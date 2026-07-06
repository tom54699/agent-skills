## Context

`development-workflow` 目前的 `init` 流程只處理專案政策文件（`AGENTS.md`/`CLAUDE.md`）與既有 skill（`business-logic-workflow`、OpenSpec workflow skills、`ai-project-index`）的路由，對 Claude Code marketplace plugin 完全沒有涉及。

一輪針對 `claude-plugins-official`（及少數外部 marketplace，如 `mixedbread-ai/mgrep`）的評估，查證了官方文件、GitHub issue、社群比較文章，逐一判斷了十幾個 plugin 對這個專案的適用性，包括跟既有 skill 重複的、跟 OpenSpec 精神衝突的、技術棧不合的、有資料外送疑慮的，以及查無公開成本效益數據、需要自行試用評估的。這些判斷目前只存在對話紀錄裡，需要沉澱成可重複執行的 init 邏輯。

## Goals / Non-Goals

**Goals:**
- 讓 `development-workflow init` 能偵測專案技術棧訊號（PHP/Laravel、Python、前端框架、Prisma）
- 提供結構化的 plugin 推薦分層（必裝／依訊號複選／條件式／排除），並附上每個判斷的理由
- 提供把「應該執行的規則」（例如 refresh index、commit 前驗證）升級成 hook 的建議路徑，並指出 `hookify` 作為降低門檻的實作機制
- 更新 `Init Output Shape`/`Init Output Result` 模板，讓推薦結果有固定的呈現格式

**Non-Goals:**
- 不會自動安裝任何 plugin 或建立任何 hook 規則檔——這次只更新「建議邏輯」，實際安裝/設定仍是使用者的決定
- 不修改 `assets/AGENTS.template.md`／`assets/CLAUDE.template.md`——plugin 安裝是一次性環境設定決策，不同於 karpathy 行為準則那種需要寫進每個專案永久政策文件的「行為原則」
- 不評估 `claude-plugins-official` 之外、還沒實測過的 plugin——分類清單只涵蓋這次實際查證過的項目，未來新出現的 plugin 需要另外評估後再擴充

## Decisions

**1. 用四層分類，而不是單一推薦清單**
單一清單無法表達「必裝」跟「看情況、有成本」之間的差異。四層（必裝／依訊號複選／條件式附成本說明／明確排除）讓每個 plugin 的建議強度跟理由都清楚,對照現有 SKILL.md 已經在用的「OpenSpec: found/missing/recommended?」條件式寫法風格一致。

*替代方案考慮過*：只列「建議裝」跟「不建議裝」兩類。捨棄理由：這樣會把「security-guidance 這種有實際成本、需要使用者自己判斷」跟「context7 這種幾乎無腦裝」混在一起，喪失了今天查證出來的精細度。

**2. 技術棧偵測用檔案訊號（`composer.json`/`requirements.txt`/`package.json`/`schema.prisma`），不用複雜的框架版本解析**
這幾個檔案的存在與否已經足夠判斷要不要問使用者對應的 plugin，符合 `development-workflow` 一貫「輕量、不引入不影響結果的流程」的 Core Rules。

**3. Hook 建議指向 `hookify`，而不是直接教使用者寫 `settings.json`**
今天查證確認 `hookify` 用簡單 markdown/白話文就能建 hook，比起在 SKILL.md 裡教一遍 `PreToolUse`/`matcher`/`if` 的語法，直接建議「先裝 hookify 再用它建規則」門檻低很多，也讓兩條 hook 建議（refresh index、commit 前驗證）有一致的建立方式。

**4. `security-guidance`／`claude-md-management` 歸類為「條件式」而非「必裝」或「排除」**
`security-guidance` 有實際但目前查無公開統計的 token 成本；`claude-md-management` 雖然沒有 hook、風險較低，但它對「好的 CLAUDE.md」的判斷是通用邏輯，不理解本專案 `development-workflow` 的特定模板結構與 OpenSpec 慣例，套用其建議前需要自行審閱。兩者都不適合無條件推薦，也不適合直接排除，需要在建議文字裡把限制講清楚，讓使用者自己判斷。（`commit-commands` 經確認不需要納入推薦清單，已從範圍移除。）

## Risks / Trade-offs

- **[風險] Marketplace 內容會持續變動，這次列的清單可能隨時間過期** → **緩解**：這份清單明確定位為「這次查證當下的判斷」，不是永久真理；SKILL.md 裡的措辭會維持條件式（「若偵測到...」），未來重新評估只需要更新對應段落，不影響整體架構
- **[風險] `security-guidance` 沒有公開的 token 消耗實測數據，建議文字可能誤導使用者低估或高估成本** → **緩解**：明確在建議文字裡寫「查無公開實測數據，建議先裝著試用並用 `/costs` 或用量監控工具量測，再決定是否長期保留」，不包裝成無條件推薦
- **[風險] 偵測邏輯只用檔案存在與否判斷，可能有偽陽性（例如專案裡殘留一個沒在用的 `schema.prisma`）** → **緩解**：偵測結果只是「進入複選候選清單」，最終仍由使用者確認勾選，不會直接安裝

## Migration Plan

無資料遷移或部署步驟——這是純文件性質的 skill 邏輯新增，屬於新增章節與新增模板欄位，不影響現有段落的既有行為。套用後下次執行 `development-workflow init` 即可看到新邏輯生效，無需額外部署動作。
