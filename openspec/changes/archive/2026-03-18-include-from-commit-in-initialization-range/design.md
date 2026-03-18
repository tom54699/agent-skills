## Context

guided-sync 初始化模式目前要求使用者提供 `--from-commit`，並將其直接轉成 `<from_commit>..HEAD`。這個做法的問題不是 Git 語法錯，而是產品語意與使用者預期不一致。

對後端工程師而言，初始化常見的操作語意是：
- 「從這次需求開始的 commit 起算」
- 「把這次功能起點那顆 commit 以及之後的修改都納進來」

但 `<from_commit>..HEAD` 會把 `from_commit` 本身排除掉。結果是：
- `changed_files` 少掉該 commit 內真正改動的 controller / request / route
- 候選推測可能收斂到 0，或只剩與本次 API 無關的後續內部修改
- 使用者容易誤以為工具漏判，實際上是 range 語意設計不直覺

限制條件：
- 只修改初始化模式的 `--from-commit` 語意，不影響 daily 模式的 `last_success_commit..HEAD`
- 不重做 commit-driven inference 主架構
- 不引入新的設定檔或新 status
- 避免為 root commit 等少數情況加入複雜 fallback 邏輯

## Goals / Non-Goals

**Goals:**
- 初始化模式下，`--from-commit` 必須包含該 commit 本身。
- `meta.from_commit` 保留原始輸入；`meta.diff_range` 顯示實際展開後的範圍。
- 對沒有 parent 的 commit 提供清楚、可操作的錯誤訊息。
- 補測試與文件，讓這個語意變成明確契約。

**Non-Goals:**
- 不改 daily 模式 range selection。
- 不處理 root commit 的特殊全量掃描策略。
- 不在本次改動 OpenAPI generation、Apidog sync 或 path strategy。

## Decisions

### 1. 初始化 `from-commit` 採 inclusive 語意

- 決策：
  - 初始化模式下，使用者輸入 `--from-commit <commit>` 時，工具應視為「包含該 commit 本身」。
  - 實作上，若 `<commit>` 有 parent，實際 diff lower bound 改用 `<commit>^`，使整體範圍等價於包含 `<commit>` 的變更集合。

- 原因：
  - 這比較符合 guided-sync 初始化的產品語意。
  - 使用者不需要理解 Git `A..B` 的排除式細節，也不用手動傳 `^`。

- 替代方案：
  - 保留現況，只在文件要求使用者自行傳 `ff619fdd^`
  - 缺點是把 Git 細節外露給使用者，初始化體驗差，也容易再踩一次同樣的坑。

### 2. 保留原始輸入 commit，並揭露實際展開 range

- 決策：
  - `meta.from_commit` 仍保存使用者輸入值。
  - `meta.diff_range` 顯示實際執行用的展開範圍，例如 `<from_commit>^..HEAD`。
  - 若有 debug/meta 額外欄位，應能看出該 range 是 inclusive initialization semantics。

- 原因：
  - 使用者需要知道自己輸入的是哪顆 commit。
  - 排錯時也需要看到系統實際怎麼展開 range。

### 3. root commit 直接報錯，不做隱性 fallback

- 決策：
  - 若 `--from-commit` 沒有 parent，直接報錯並要求使用者指定一顆有 parent 的 commit。

- 原因：
  - root commit 很少是 guided-sync 初始化的合理起點。
  - 若為了這個少數情境加入特殊邏輯，會讓 range selection 複雜化。
  - 目前需求重點是修正語意，而不是支援所有 Git 極端案例。

- 替代方案：
  - 自動 fallback 為全歷史掃描或空樹 diff。
  - 缺點是行為不夠直覺，也可能讓初始化範圍比使用者預期更大。

## Risks / Trade-offs

- [Risk] 已經習慣 Git 原生 `A..HEAD` 語意的使用者，可能會注意到 guided-sync 的 `from-commit` 與原生 Git 有差異。
  -> Mitigation：在文件中明確宣告 guided-sync 的 `from-commit` 是產品語意上的 inclusive 起點。

- [Risk] `meta.diff_range` 顯示 `<commit>^..HEAD`，使用者可能疑惑為何與輸入不完全相同。
  -> Mitigation：同步保留 `meta.from_commit` 並在文件說明「前者是使用者輸入，後者是實際展開 range」。

- [Risk] root commit 直接報錯會限制極少數專案初始化場景。
  -> Mitigation：先保持最小改動；若後續真的有 root commit 初始化需求，再另外開 change。

## Migration Plan

1. 調整初始化 `RangeSelection`，將 `--from-commit` 解析為 inclusive 起點。
2. 更新 `Analyzer` meta/debug，揭露原始 `from_commit` 與實際 `diff_range`。
3. 補測試覆蓋 inclusive range 與 root commit 錯誤訊息。
4. 用 `myan-ride` 的 `ff619fdd97103cc22752813b2ec902b56aa1cacf` 重跑初始化驗證，確認 candidate 清單會納入該 commit 本身的 SMS 相關修改。
5. 更新 `SKILL.md` 與 guided-sync 文件。

## Open Questions

- `meta` 是否需要額外新增如 `from_commit_inclusive=true` 這類明示欄位，還是保留 `from_commit + diff_range` 就足夠？
