## Context

今天稍早建立的 Plugin Recommendations 四層分類（必裝／依訊號複選／條件式／排除）解決了「推薦什麼」的問題，但沒有處理「怎麼問」的問題。使用者看完 README 後點出兩個實務缺口：安裝範圍（Claude Code 的 user/project/local scope 我們之前討論過，會影響是否跟著 repo 走）從沒被問過；依訊號推薦的 plugin 只是寫進計畫文字，不夠主動。

## Goals / Non-Goals

**Goals:**
- 每一層 plugin 推薦都要有安裝範圍的預設值與使用者確認機制
- 依訊號複選層改用 AskUserQuestion 工具做明確互動式提問

**Non-Goals:**
- 不改變四層分類本身的內容（必裝/依訊號/條件式/排除清單維持不變）
- 不強制條件式層或排除清單也要用 AskUserQuestion——條件式層本來就已經要求「ask explicitly」，這次澄清的重點是依訊號複選層

## Decisions

**1. 範圍預設值依層級而非統一**
必裝層（`context7`/`skill-creator`/`hookify`）性質是個人生產力工具，價值在「跟著你、不限這個專案」，預設 user scope 合理；依訊號複選層（`laravel-boost` 等）與條件式層（`security-guidance` 等）的價值更常是「這個專案的隊友也該一起用」，預設 project scope 更合理。兩者都只是預設，使用者可以在確認時覆寫。

**2. 依訊號複選層改用 AskUserQuestion，不再只寫文字**
文字計畫容易被使用者略讀跳過；AskUserQuestion 的複選介面強制使用者做出明確選擇，符合「更主動」的訴求，也符合這個 skill 一貫「先確認再執行」的原則。

## Risks / Trade-offs

- **[風險] 每一層都要問安裝範圍，可能讓 init 流程變得囉唆** → **緩解**：範圍問題只問一次（可以在複選提問裡一併帶出「這些要裝在 user 還是 project」的選項），不需要每個 plugin 各問一次
