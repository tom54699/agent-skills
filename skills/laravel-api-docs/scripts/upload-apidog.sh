#!/bin/bash
set -euo pipefail

# 依 folder_id 分批上傳本次 spec 到 Apidog，上傳後驗證每支 API 的路徑與資料夾。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apidog-lib.sh"

OPENAPI_FILE=""
TARGETS_FILE=""

usage() {
  cat <<'USAGE'
Usage: upload-apidog.sh --openapi FILE --targets FILE

在 Laravel 專案根目錄執行，憑證讀取 .env.agents。

Options:
  --openapi FILE  本次的 spec（YAML 或 JSON）
  --targets FILE  要上傳的 API：[{"method": "post", "path": "/...", "folder_id": 123}]，根目錄 folder_id 為 0
  -h, --help      Show help

上傳前檢查失敗時不會送出任何請求；上傳後 API 不存在或不在指定資料夾時以非 0 結束。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      [ $# -ge 2 ] || fail "--openapi 需要值"
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --targets)
      [ $# -ge 2 ] || fail "--targets 需要值"
      TARGETS_FILE="$2"
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

[ -n "$OPENAPI_FILE" ] || fail "需要 --openapi"
[ -n "$TARGETS_FILE" ] || fail "需要 --targets"

SPEC_JSON_FILE="$(mktemp)"
BATCH_SPEC_FILE="$(mktemp)"
REQUEST_FILE="$(mktemp)"
RESPONSE_FILE="$(mktemp)"
FLAT_TREE_FILE="$(mktemp)"
trap 'rm -f "$SPEC_JSON_FILE" "$BATCH_SPEC_FILE" "$REQUEST_FILE" "$RESPONSE_FILE" "$FLAT_TREE_FILE"' EXIT

# ── 上傳前檢查（不送任何請求）────────────────────────────────────────────────
spec_to_json "$OPENAPI_FILE" "$SPEC_JSON_FILE"
[ -f "$TARGETS_FILE" ] || fail "找不到 targets 檔：$TARGETS_FILE"
jq -e 'type == "array" and length > 0' "$TARGETS_FILE" >/dev/null 2>&1 \
  || fail "targets 檔必須是非空的 JSON 陣列：$TARGETS_FILE"

PROBLEMS="$(jq -r --slurpfile spec "$SPEC_JSON_FILE" '
  ($spec[0].paths // {}) as $paths
  | to_entries[]
  | (.key + 1) as $n
  | .value as $t
  | if ($t | type) != "object" then "第 \($n) 筆不是物件"
    elif ($t.method | type) != "string" or $t.method == "" then "第 \($n) 筆缺少 method"
    elif ($t.path | type) != "string" or ($t.path | startswith("/") | not) then "第 \($n) 筆缺少 path，或 path 不是以 / 開頭"
    elif ($t.folder_id | type) != "number" or $t.folder_id != ($t.folder_id | floor) or $t.folder_id < 0 then
      "\($t.method | ascii_upcase) \($t.path) 的 folder_id 必須是非負整數"
    elif (($paths[$t.path] // {}) | has($t.method | ascii_downcase) | not) then
      "\($t.method | ascii_upcase) \($t.path) 不在 spec 中"
    else empty end
' "$TARGETS_FILE")"

if [ -z "$PROBLEMS" ]; then
  PROBLEMS="$(jq -r '
    map((.method | ascii_upcase) + " " + .path) | group_by(.) | map(select(length > 1) | .[0])[]
    | "重複的 target：\(.)"
  ' "$TARGETS_FILE")"
fi

if [ -n "$PROBLEMS" ]; then
  echo "上傳前檢查失敗，未送出任何請求：" >&2
  printf '%s\n' "$PROBLEMS" | sed 's/^/  - /' >&2
  exit 1
fi

TARGETS="$(jq -c 'map({method: (.method | ascii_downcase), path, folder_id})' "$TARGETS_FILE")"
BATCHES="$(jq -c 'group_by(.folder_id) | map({folder_id: .[0].folder_id, endpoints: map({method, path})})' <<<"$TARGETS")"
BATCH_COUNT="$(jq 'length' <<<"$BATCHES")"

load_apidog_env

# ── 依資料夾分批上傳 ─────────────────────────────────────────────────────────
CREATED=0
UPDATED=0
IGNORED=0
FAILED=0
BATCH_INDEX=0

while IFS= read -r batch; do
  BATCH_INDEX=$((BATCH_INDEX + 1))
  folder_id="$(jq -r '.folder_id' <<<"$batch")"
  endpoints="$(jq -c '.endpoints' <<<"$batch")"

  jq --argjson eps "$endpoints" "$JQ_DEFS filter_endpoints(\$eps) | strip_apidog_folder | prune_components" \
    "$SPEC_JSON_FILE" >"$BATCH_SPEC_FILE"

  jq -n --rawfile spec "$BATCH_SPEC_FILE" --argjson folder_id "$folder_id" '{
    input: $spec,
    options: {
      targetEndpointFolderId: $folder_id,
      targetSchemaFolderId: 0,
      endpointOverwriteBehavior: "OVERWRITE_EXISTING",
      schemaOverwriteBehavior: "OVERWRITE_EXISTING",
      updateFolderOfChangedEndpoint: true,
      prependBasePath: false
    }
  }' >"$REQUEST_FILE"

  echo "上傳第 ${BATCH_INDEX}/${BATCH_COUNT} 批：folder_id=${folder_id}，$(jq 'length' <<<"$endpoints") 支 API" >&2
  apidog_request POST "https://api.apidog.com/v1/projects/$APIDOG_PROJECT_ID/import-openapi?locale=en-US" "$RESPONSE_FILE" "$REQUEST_FILE"

  CREATED=$((CREATED + $(jq '.data.counters.endpointCreated // 0' "$RESPONSE_FILE")))
  UPDATED=$((UPDATED + $(jq '.data.counters.endpointUpdated // 0' "$RESPONSE_FILE")))
  IGNORED=$((IGNORED + $(jq '.data.counters.endpointIgnored // 0' "$RESPONSE_FILE")))
  FAILED=$((FAILED + $(jq '.data.counters.endpointFailed // 0' "$RESPONSE_FILE")))
done < <(jq -c '.[]' <<<"$BATCHES")

# ── 上傳後驗證路徑與資料夾 ───────────────────────────────────────────────────
echo "驗證上傳結果..." >&2
fetch_flat_tree "$FLAT_TREE_FILE"

MISMATCHES="$(jq -r --argjson targets "$TARGETS" '
  .apis as $apis
  | $targets[] as $t
  | [$apis[] | select(.method == $t.method and .path == $t.path)] as $hits
  | (($t.method | ascii_upcase) + " " + $t.path) as $label
  | if ($hits | length) == 0 then "\($label)：上傳後在 Apidog 找不到"
    elif ($hits | any(.folder_id == $t.folder_id)) then empty
    else "\($label)：預期 folder_id \($t.folder_id)，實際在 "
      + ($hits | map("\(if .folder_path == "" then "(root)" else .folder_path end) (\(.folder_id))") | join("、"))
    end
' "$FLAT_TREE_FILE")"

SUMMARY="$(jq -n \
  --argjson created "$CREATED" \
  --argjson updated "$UPDATED" \
  --argjson ignored "$IGNORED" \
  --argjson failed "$FAILED" \
  --argjson batches "$BATCH_COUNT" \
  --argjson targets "$TARGETS" \
  '{created: $created, updated: $updated, ignored: $ignored, failed: $failed, batches: $batches, target_count: ($targets | length)}')"

if [ -n "$MISMATCHES" ]; then
  echo "$SUMMARY" >&2
  echo "上傳後驗證失敗：" >&2
  printf '%s\n' "$MISMATCHES" | sed 's/^/  - /' >&2
  exit 1
fi

echo "上傳完成，$(jq 'length' <<<"$TARGETS") 支 API 都在指定資料夾" >&2
jq '. + {verified: true}' <<<"$SUMMARY"
