#!/bin/bash
set -euo pipefail

# 列出 Apidog 資料夾路徑與 folder ID，或每支 API 目前所在的資料夾。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apidog-lib.sh"

SHOW_APIS=false
AS_JSON=false

usage() {
  cat <<'USAGE'
Usage: list-folders.sh [--apis] [--json]

在 Laravel 專案根目錄執行，憑證讀取 .env.agents。

Options:
  --apis      改列每支 API 所在的資料夾（METHOD /path → 資料夾路徑 (folder ID)）
  --json      輸出 JSON：{"folders": [{id, path}], "apis": [{method, path, folder_id, folder_path}]}
  -h, --help  Show help

根目錄的 folder ID 為 0。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apis)
      SHOW_APIS=true
      shift
      ;;
    --json)
      AS_JSON=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "未知參數：$1"
      ;;
  esac
done

load_apidog_env

FLAT_TREE_FILE="$(mktemp)"
trap 'rm -f "$FLAT_TREE_FILE"' EXIT
fetch_flat_tree "$FLAT_TREE_FILE"

if [ "$AS_JSON" = true ]; then
  jq . "$FLAT_TREE_FILE"
elif [ "$SHOW_APIS" = true ]; then
  jq -r '.apis | sort_by(.path, .method)[]
    | "\(.method | ascii_upcase) \(.path) → \(if .folder_path == "" then "(root)" else .folder_path end) (\(.folder_id))"' "$FLAT_TREE_FILE"
else
  jq -r '.folders | sort_by(.path)[] | "\(.path) → \(.id)"' "$FLAT_TREE_FILE"
fi
