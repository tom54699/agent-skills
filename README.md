# Agent Skills

這個 repo 主要拿來放我自己用的 agent skills 和相關 OpenSpec 紀錄；如果剛好有人也要用，可以直接從 `skills/` 找對應 skill。

## 目錄

- `skills/`：技能本體與腳本
- `openspec/`：需求、設計、spec、tasks 紀錄

## 目前主要技能

### `skills/laravel-api-docs`

用來跑 Laravel API 文件 guided-sync。流程大致會：

- 先檢查 Laravel 專案環境、Apidog 設定與必要工具
- 根據 Git 變更範圍推測這次受影響的 API
- 和使用者確認最終 API 清單
- 依確認後的清單更新 `openapi.yaml`
- 同步到 Apidog，必要時處理 review 與衝突
- 最後產生多頁 HTML 文件

HTML 輸出固定為：

- `index.html`：摘要首頁
- `api-docs.html`：純 API 文件頁

使用方式：

- 進到 Laravel 專案目錄
- 在 agent 對話裡直接說：
  - `幫我更新 API 文件`
  - `sync api docs`
  - `幫我產生 API 文件`

## 備註

- 這個 repo 偏自用，不特別做通用化包裝。
- 本地協作檔不進版控，正式變更以 `skills/` 和 `openspec/` 為主。
