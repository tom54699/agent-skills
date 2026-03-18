## Context

目前 debug 行為同時輸出 route snapshot、OpenAPI baseline 差集、changed files、changed classes、prefilter 與 candidate summary，但沒有清楚區分哪些是「全集參考值」、哪些是「候選收斂訊號」。這在初始化且無 baseline 時會讓 `route diff` 顯得像是候選爆量，與實際結果不一致。

系統限制：
- 不改變 candidate 推測邏輯。
- 維持 `--debug` 為純 stderr 診斷輸出。
- 不引入新的 CLI 參數。

## Goals / Non-Goals

**Goals:**
- debug 要能清楚區分 Git 變更盤點、baseline 資訊、action hint、prefilter、candidate summary。
- 在無 baseline 時，明確說明 route/doc 差集僅供參考，不代表候選數。
- 更新文件讓使用者知道應優先看哪些 debug 行。

**Non-Goals:**
- 不調整 `new/updated/deleted` 判定。
- 不修改 candidate JSON 結構。
- 不新增 debug 等級。

## Decisions

1. 以語意清楚的標籤取代模糊名稱。
- `changed files by domain` 保留為 Git 盤點。
- `changed classes` 改名為 class-level inventory。
- `route diff` 改為 baseline comparison，無 baseline 時直接註明 informational only。

2. 保留既有數值，只調整呈現方式。
- 原因：避免把 debug 優化和推測邏輯耦合在一起，方便單獨驗證。

## Risks / Trade-offs

- [Risk] 舊的 debug 關鍵字可能不再和既有筆記完全一致。
  -> Mitigation：在 `SKILL.md` 更新新的閱讀方式，並保留核心數值欄位。

## Migration Plan

1. 調整 `infer-candidates.sh` debug 訊息內容。
2. 更新 `SKILL.md` 的 debug 說明。
3. 以 shell 語法檢查驗證腳本可執行。
