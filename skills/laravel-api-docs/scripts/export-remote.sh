#!/bin/bash
set -euo pipefail

# 從 Apidog 匯出指定 API（含 Apidog extensions），作為更新既有 API 的底稿。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apidog-lib.sh"

ENDPOINTS='[]'
OUTPUT_FILE=""

usage() {
  cat <<'USAGE'
Usage: export-remote.sh --endpoint "METHOD /path" [--endpoint ...] --output FILE

在 Laravel 專案根目錄執行，憑證讀取 .env.agents。

Options:
  --endpoint "METHOD /path"  要匯出的 API，可重複指定；path 需與 Apidog 上的格式一致
  --output FILE              輸出檔（OpenAPI JSON，只含指定 operation 與被引用的 components）
  -h, --help                 Show help

stdout 輸出 {"output", "found": [...], "missing": [...]}；missing 代表 Apidog 上沒有這支 API。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      [ $# -ge 2 ] || fail "--endpoint 需要值"
      method="$(printf '%s' "$2" | awk '{print tolower($1)}')"
      path="$(printf '%s' "$2" | awk '{print $2}')"
      case "$path" in
        /*) ;;
        *) fail "--endpoint 格式應為 \"METHOD /path\"：$2" ;;
      esac
      ENDPOINTS="$(jq -c --arg m "$method" --arg p "$path" '. + [{method: $m, path: $p}] | unique' <<<"$ENDPOINTS")"
      shift 2
      ;;
    --output)
      [ $# -ge 2 ] || fail "--output 需要值"
      OUTPUT_FILE="$2"
      shift 2
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

[ "$(jq 'length' <<<"$ENDPOINTS")" -gt 0 ] || fail "至少需要一個 --endpoint"
[ -n "$OUTPUT_FILE" ] || fail "需要 --output"

load_apidog_env

FULL_SPEC_FILE="$(mktemp)"
trap 'rm -f "$FULL_SPEC_FILE"' EXIT

echo "正在從 Apidog 匯出規格..." >&2
export_remote_spec "$FULL_SPEC_FILE"

mkdir -p "$(dirname "$OUTPUT_FILE")"
jq --argjson eps "$ENDPOINTS" "$JQ_DEFS filter_endpoints(\$eps) | prune_components" "$FULL_SPEC_FILE" >"$OUTPUT_FILE"

jq -n \
  --arg output "$OUTPUT_FILE" \
  --argjson eps "$ENDPOINTS" \
  --slurpfile spec "$OUTPUT_FILE" \
  '($spec[0].paths // {}) as $paths
  | {
      output: $output,
      found: ($eps | map(select(. as $e | ($paths[$e.path] // {}) | has($e.method))) | map((.method | ascii_upcase) + " " + .path)),
      missing: ($eps | map(select(. as $e | (($paths[$e.path] // {}) | has($e.method)) | not)) | map((.method | ascii_upcase) + " " + .path))
    }'
