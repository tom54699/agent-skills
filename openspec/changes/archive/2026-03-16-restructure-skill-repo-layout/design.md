## Context

目前 repo 只有一個主要 skill，因此使用平鋪的 `skills/.curated/laravel-api-docs` 還能運作。但未來會有多個 skill，且成熟度不同；若沒有穩定/實驗分層，對外安裝說明與內部維護都會逐漸失焦。

同時，這個 repo 比較像 skill collection，而不是 npm package。對外最適合的分發方式是 repo-based installer，而不是先做套件化發佈。

## Goals / Non-Goals

**Goals**
- 建立可擴充的多 skill repo 結構。
- 讓穩定 skill 與實驗 skill 有明確邊界。
- 提供最小但清楚的安裝文件，對齊 `npx skills add <repo>` 的使用方式。
- 修正 repo 內仍活躍文件的路徑引用。

**Non-Goals**
- 不在這筆 change 導入 npm package 或自製 installer。
- 不重寫 archive 內的歷史變更紀錄。
- 不在這筆 change 新增第二個 skill。

## Decisions

### 1. 採用 `.curated/` 與 `.experimental/` 分層

`skills/.curated/` 放可公開推薦安裝的 skill，`skills/.experimental/` 放仍在驗證中的 skill。這個分層直接反映 repo 對外的穩定度承諾。

### 2. 先只搬移既有穩定 skill

目前只有 `laravel-api-docs` 需要對外提供，因此先移到 `skills/.curated/laravel-api-docs`。`.experimental/` 只建立結構，不預先塞入範例 skill。

### 3. 安裝說明以 repo-based 為主

README 與 `docs/install-skills.md` 都以 `npx skills add <owner>/<repo> --skill laravel-api-docs` 為主要安裝方式，不引入 npm 套件化流程。

### 4. 只更新活的引用，不改 archive

repo root README、新增 docs、以及 `openspec/changes/` 下非 archive 的路徑引用要同步更新；`openspec/changes/archive/` 保留歷史原貌，不批次改寫。

## Risks / Trade-offs

- skill 目錄搬移後，任何寫死舊路徑的文件都會失效，因此需要一起掃描並修正活的引用。
- `.experimental/` 初期可能是空資料夾，需要用 placeholder 檔保留目錄結構。

## Migration Plan

1. 建立 `skills/.curated/`、`skills/.experimental/` 結構。
2. 搬移 `laravel-api-docs` 到 curated 位置。
3. 更新 README、repo 級安裝文件與活的 OpenSpec 路徑引用。
4. 驗證 repo 內已無非 archive 的舊路徑引用。
