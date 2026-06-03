# AI Project Index 使用流程

`.ai-project-index` 是給 AI 使用的專案索引，用來快速找到可能相關的 source、OpenSpec、docs、tests 路徑。它不是 source of truth。

## 產物政策

- `.ai-project-index/index.json`、`.ai-project-index/audit.json`、`.ai-project-index/evaluation.json`、`.ai-project-index/evaluation.md` 都是 local-regenerate artifacts。
- 這些產物預設不需要 commit。
- 若未來要改成部分 commit 或加入 hook，必須另開 OpenSpec change。

## Refresh 時機

以下內容變更後，應重新 refresh：

- `skills/` 內的 skill 規格或腳本
- `.codex/skills/` 內的 OpenSpec workflow skill
- `openspec/specs/` accepted specs
- `openspec/changes/` active changes
- `docs/` 文件
- `tests/` 測試
- `AGENTS.md`、`CLAUDE.md`、`README.md` 等專案協作或導覽文件

從 repo root 執行：

```bash
python3 skills/ai-project-index/scripts/refresh-index.py
```

這會依序執行：

```bash
python3 skills/ai-project-index/scripts/generate-index.py
python3 skills/ai-project-index/scripts/audit-index.py
```

如果 audit status 是 `warning`，AI 不應依賴 index 做 routing。先 refresh 並重新 audit；若仍 warning，直接閱讀 source/spec/docs/tests。

## AI 使用規則

AI 可以用 index 做 broad discovery：

```bash
python3 skills/ai-project-index/scripts/query-index.py "query parameter"
```

適合先 query index 的情境：

- 不確定功能分散在哪些檔案
- 想快速定位相關 source/spec/docs/tests
- 想避免一開始就讀大量 repo 內容
- 想查 OpenSpec、docs、tests 的入口

不應只靠 index 的情境：

- 要判斷精確行為
- 要修改 API contract
- 要處理安全、資料一致性或副作用
- 剛搬檔、刪檔、改大量檔案，但還沒有 refresh
- audit status 是 `warning`

最後結論必須回到 source of truth 驗證：

- source files
- accepted OpenSpec specs
- reviewed docs
- tests

## Archive 與 Self 查詢

預設 query 會排除 archived OpenSpec changes 和 `ai-project-index` skill 自己，避免歷史內容或索引工具本身干擾一般查詢。

需要看 archive 時：

```bash
python3 skills/ai-project-index/scripts/query-index.py "evaluate understand anything" --include-archive
```

需要查 `ai-project-index` skill 自己時：

```bash
python3 skills/ai-project-index/scripts/query-index.py "refresh index evaluation" --include-self
```

## 評估流程

執行：

```bash
python3 skills/ai-project-index/scripts/evaluate-index.py
```

評估會比較：

- 直接閱讀候選檔案的約略 token 成本
- query index 後再讀目標檔案的約略 token 成本
- index 是否找到預期 source-of-truth 路徑
- 哪些 case 需要 fallback 回直接讀 source

token 估算只用於相對比較，不代表實際模型計費。

## 後續自動化決策

目前不加入 mandatory git hook 或 pre-commit workflow。

理由：

- `.ai-project-index` 仍定位為 local-regenerate artifact
- 忽略檔、私有檔與生成檔的掃描策略仍可能依 repo 調整
- 需要先用 evaluation cases 驗證它確實能穩定節省 token 並正確 routing

若未來要加入 optional hook、pre-commit check 或 workflow automation，應另開 OpenSpec change 討論。
