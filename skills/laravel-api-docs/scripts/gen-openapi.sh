#!/bin/bash
set -euo pipefail

INCREMENTAL=false
BASE_FILE=""
SKIP_RESOURCE=false
CANDIDATE_FILE=""
REVIEW_FILE=""
OUTPUT_DIR="docs/api-docs"
OPENAPI_FILE="$OUTPUT_DIR/openapi.yaml"
PROGRESS_ENABLED=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"
PHP_GENERATOR="$SCRIPT_DIR/../bin/gen-openapi.php"
FORWARD_ARGS=()

usage() {
  cat <<'USAGE'
Usage: gen-openapi.sh [options]

Options:
  --incremental            Merge generated endpoints into an existing OpenAPI file
  --candidate-file FILE    Apply only endpoints listed in the confirmed candidate file
  --base FILE              Use specified OpenAPI file as merge base
  --review-file FILE       Write unresolved review artifact to the given path
  --path-strategy STRATEGY Route path strategy: keep-full-path | strip-api-prefix-to-server
  --skip-resource          Reserved for compatibility
  --no-progress            Disable progress output
  -h, --help               Show help
USAGE
}

php_event_adapter() {
  local line=""
  local event_type=""
  local stage=""
  local current=""
  local total=""
  local message=""
  local duration_ms=""
  local detail=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue

    if ! echo "$line" | jq -e . >/dev/null 2>&1; then
      echo "$line" >&2
      continue
    fi

    event_type="$(echo "$line" | jq -r '.type // ""' 2>/dev/null || true)"
    case "$event_type" in
      progress)
        stage="$(echo "$line" | jq -r '.stage // ""' 2>/dev/null || true)"
        current="$(echo "$line" | jq -r '.current // 0' 2>/dev/null || echo 0)"
        total="$(echo "$line" | jq -r '.total // 0' 2>/dev/null || echo 0)"
        message="$(echo "$line" | jq -r '.message // ""' 2>/dev/null || true)"
        guided_progress_emit "update_openapi" "$stage" "in_progress" "$current" "$total" "$message"
        ;;
      timing)
        stage="$(echo "$line" | jq -r '.stage // ""' 2>/dev/null || true)"
        duration_ms="$(echo "$line" | jq -r '.duration_ms // 0' 2>/dev/null || echo 0)"
        detail="$(echo "$line" | jq -r '.detail.detail // ""' 2>/dev/null || true)"
        guided_timing_record "gen-openapi" "$stage" "$duration_ms" "$detail"
        ;;
      warning)
        message="$(echo "$line" | jq -r '.message // ""' 2>/dev/null || true)"
        echo "⚠️  $message" >&2
        ;;
      *)
        echo "$line" >&2
        ;;
    esac
  done
}

if [ ! -f "$PHP_GENERATOR" ]; then
  echo "錯誤：找不到 PHP generator：$PHP_GENERATOR" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --incremental)
      INCREMENTAL=true
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --candidate-file)
      CANDIDATE_FILE="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --base)
      BASE_FILE="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --review-file)
      REVIEW_FILE="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --path-strategy)
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --skip-resource)
      SKIP_RESOURCE=true
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --no-progress)
      PROGRESS_ENABLED=0
      FORWARD_ARGS+=("$1")
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知參數：$1" >&2
      exit 1
      ;;
  esac
done

guided_progress_set_enabled "$PROGRESS_ENABLED"
guided_progress_emit "update_openapi" "route_snapshot" "in_progress" 0 6 "starting openapi generation"
guided_timing_begin "openapi_total"

PHP_STDOUT_FILE="$(mktemp)"
if php -n "$PHP_GENERATOR" "${FORWARD_ARGS[@]}" >"$PHP_STDOUT_FILE" 2> >(php_event_adapter); then
  generated_count="$(jq -r '.generated_endpoint_count // 0' "$PHP_STDOUT_FILE" 2>/dev/null || echo 0)"
  deleted_count="$(jq -r '.deleted_candidate_count // 0' "$PHP_STDOUT_FILE" 2>/dev/null || echo 0)"
  review_count="$(jq -r '.review_item_count // 0' "$PHP_STDOUT_FILE" 2>/dev/null || echo 0)"
  review_file="$(jq -r '.review_file // ""' "$PHP_STDOUT_FILE" 2>/dev/null || true)"
  guided_timing_end "gen-openapi" "openapi_total" "generated=$generated_count deleted=$deleted_count"
  guided_progress_emit "update_openapi" "complete" "done" 6 6 "openapi update complete"
  echo "OpenAPI 文件已產出：$OPENAPI_FILE" >&2
  if [ "${review_count:-0}" -gt 0 ] && [ -n "${review_file:-}" ]; then
    echo "OpenAPI review 清單已輸出：$review_file" >&2
  fi
  cat "$PHP_STDOUT_FILE"
  rm -f "$PHP_STDOUT_FILE"
  exit 0
fi

exit_code=$?
cat "$PHP_STDOUT_FILE" >&2 || true
rm -f "$PHP_STDOUT_FILE"
exit "$exit_code"
