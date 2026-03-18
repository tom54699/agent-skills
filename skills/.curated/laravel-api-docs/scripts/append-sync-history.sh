#!/bin/bash
set -euo pipefail

# 在 Apidog 同步成功後 append 一筆 history 紀錄
#
# 預設：
# - history: docs/api-docs/history/apidog-sync-history.jsonl
# - openapi: docs/api-docs/openapi.yaml（若不存在且 docs/openapi.yaml 存在則回退）

HISTORY_FILE="docs/api-docs/history/apidog-sync-history.jsonl"
OPENAPI_FILE="docs/api-docs/openapi.yaml"

SYNC_ID=""
SYNCED_AT=""
FROM_TIME=""
TO_TIME=""
STATUS="success"
APIDOG_PROJECT_ID="${APIDOG_PROJECT_ID:-}"
IMPORTED_COUNT=0
UPDATED_COUNT=0
SKIPPED_COUNT=0
CONFLICT_COUNT=0

usage() {
  cat <<'USAGE'
Usage: append-sync-history.sh [options]

Options:
  --history FILE            History jsonl path
  --openapi FILE            OpenAPI file path
  --sync-id ID              Sync record id
  --synced-at UTC_ISO8601   Sync time (UTC), e.g. 2026-03-06T16:15:00Z
  --from-time UTC_ISO8601   Candidate range start time
  --to-time UTC_ISO8601     Candidate range end time
  --status STATUS           success|failed (default: success)
  --apidog-project-id ID    Apidog project id
  --imported-count N        Imported endpoint count
  --updated-count N         Updated endpoint count
  --skipped-count N         Skipped endpoint count
  --conflict-count N        Conflict count
  -h, --help                Show help
USAGE
}

is_utc_iso8601() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

ensure_non_negative_int() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --history)
      HISTORY_FILE="$2"
      shift 2
      ;;
    --openapi)
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --sync-id)
      SYNC_ID="$2"
      shift 2
      ;;
    --synced-at)
      SYNCED_AT="$2"
      shift 2
      ;;
    --from-time)
      FROM_TIME="$2"
      shift 2
      ;;
    --to-time)
      TO_TIME="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --apidog-project-id)
      APIDOG_PROJECT_ID="$2"
      shift 2
      ;;
    --imported-count)
      IMPORTED_COUNT="$2"
      shift 2
      ;;
    --updated-count)
      UPDATED_COUNT="$2"
      shift 2
      ;;
    --skipped-count)
      SKIPPED_COUNT="$2"
      shift 2
      ;;
    --conflict-count)
      CONFLICT_COUNT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$OPENAPI_FILE" ] && [ "$OPENAPI_FILE" = "docs/api-docs/openapi.yaml" ] && [ -f "docs/openapi.yaml" ]; then
  OPENAPI_FILE="docs/openapi.yaml"
fi

if [ ! -f "$OPENAPI_FILE" ]; then
  echo "錯誤：找不到 OpenAPI 檔案：$OPENAPI_FILE" >&2
  exit 1
fi

if [ "$STATUS" != "success" ] && [ "$STATUS" != "failed" ]; then
  echo "錯誤：--status 必須為 success 或 failed" >&2
  exit 1
fi

for n in "$IMPORTED_COUNT" "$UPDATED_COUNT" "$SKIPPED_COUNT" "$CONFLICT_COUNT"; do
  if ! ensure_non_negative_int "$n"; then
    echo "錯誤：count 參數必須為非負整數" >&2
    exit 1
  fi
done

if [ -z "$SYNCED_AT" ]; then
  SYNCED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fi
if ! is_utc_iso8601 "$SYNCED_AT"; then
  echo "錯誤：--synced-at 必須為 UTC ISO 8601（YYYY-MM-DDTHH:mm:ssZ）" >&2
  exit 1
fi

if [ -n "$FROM_TIME" ] && ! is_utc_iso8601 "$FROM_TIME"; then
  echo "錯誤：--from-time 必須為 UTC ISO 8601（YYYY-MM-DDTHH:mm:ssZ）" >&2
  exit 1
fi

if [ -z "$TO_TIME" ]; then
  TO_TIME="$SYNCED_AT"
fi
if [ -n "$TO_TIME" ] && ! is_utc_iso8601 "$TO_TIME"; then
  echo "錯誤：--to-time 必須為 UTC ISO 8601（YYYY-MM-DDTHH:mm:ssZ）" >&2
  exit 1
fi

# 若沒有傳 from_time，嘗試從最後一筆 success 的 synced_at 補上
if [ -z "$FROM_TIME" ] && [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
  FROM_TIME="$(jq -s -r 'map(select(.status=="success")) | last | .synced_at // ""' "$HISTORY_FILE" 2>/dev/null || true)"
fi

if [ -n "$FROM_TIME" ] && ! is_utc_iso8601 "$FROM_TIME"; then
  echo "錯誤：history 中最後 success 的 synced_at 不是合法 UTC ISO 8601" >&2
  exit 1
fi

if [ -z "$APIDOG_PROJECT_ID" ]; then
  APIDOG_PROJECT_ID="unknown"
fi

GIT_HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
GIT_SHORT="$(echo "$GIT_HEAD_COMMIT" | cut -c1-7)"

if command -v shasum >/dev/null 2>&1; then
  OPENAPI_SHA256="$(shasum -a 256 "$OPENAPI_FILE" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  OPENAPI_SHA256="$(sha256sum "$OPENAPI_FILE" | awk '{print $1}')"
else
  echo "錯誤：找不到 shasum 或 sha256sum，無法計算 SHA256" >&2
  exit 1
fi

if [ -z "$SYNC_ID" ]; then
  SYNC_ID="$(echo "$SYNCED_AT" | tr -d ':-' | sed 's/T//; s/Z$//')-${GIT_SHORT}"
fi

mkdir -p "$(dirname "$HISTORY_FILE")"

record="$(
  jq -c -n \
    --arg sync_id "$SYNC_ID" \
    --arg synced_at "$SYNCED_AT" \
    --arg from_time "$FROM_TIME" \
    --arg to_time "$TO_TIME" \
    --arg git_head_commit "$GIT_HEAD_COMMIT" \
    --arg git_branch "$GIT_BRANCH" \
    --arg openapi_sha256 "$OPENAPI_SHA256" \
    --arg apidog_project_id "$APIDOG_PROJECT_ID" \
    --argjson imported_count "$IMPORTED_COUNT" \
    --argjson updated_count "$UPDATED_COUNT" \
    --argjson skipped_count "$SKIPPED_COUNT" \
    --argjson conflict_count "$CONFLICT_COUNT" \
    --arg status "$STATUS" \
    '{
      sync_id: $sync_id,
      synced_at: $synced_at,
      from_time: (if $from_time == "" then null else $from_time end),
      to_time: $to_time,
      git_head_commit: $git_head_commit,
      git_branch: $git_branch,
      openapi_sha256: $openapi_sha256,
      apidog_project_id: $apidog_project_id,
      imported_count: $imported_count,
      updated_count: $updated_count,
      skipped_count: $skipped_count,
      conflict_count: $conflict_count,
      status: $status
    }'
)"

echo "$record" >> "$HISTORY_FILE"
echo "已追加同步紀錄：$HISTORY_FILE" >&2
echo "$record" | jq '.'
