#!/bin/bash
set -euo pipefail

# 推測候選 API 清單（guided-sync Step 2/3）
# 現在僅作為 thin wrapper：
# - 保留既有 shell 入口
# - 委派給 PHP analyzer
# - 將 progress / timing event 轉回 guided-sync stderr 輸出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

PHP_ANALYZER="$SCRIPT_DIR/../bin/infer-candidates.php"
OUTPUT_FILE=""
FORWARD_ARGS=()

usage() {
  cat <<'USAGE'
Usage: infer-candidates.sh [options]

Options:
  --history FILE
  --openapi FILE
  --from-commit COMMIT
  --path-strategy STRATEGY
  --analysis-mode MODE
  --scan-roots ROOTS
  --debug
  --lookback-commits N
  --output FILE
  --no-progress
  -h, --help
USAGE
}

php_event_stage_name() {
  case "$1" in
    route_index) echo "route_snapshot" ;;
    change_index) echo "git_inventory" ;;
    action_index) echo "action_hints" ;;
    candidate_resolver) echo "candidate_evaluation" ;;
    *) echo "$1" ;;
  esac
}

php_event_adapter() {
  local line=""
  local event_type=""
  local stage=""
  local mapped_stage=""
  local current=""
  local total=""
  local message=""
  local duration_ms=""
  local detail=""
  local debug_message=""
  local debug_context=""

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
        mapped_stage="$(php_event_stage_name "$stage")"
        current="$(echo "$line" | jq -r '.current // 0' 2>/dev/null || echo 0)"
        total="$(echo "$line" | jq -r '.total // 0' 2>/dev/null || echo 0)"
        message="$(echo "$line" | jq -r '.message // ""' 2>/dev/null || true)"
        guided_progress_emit "infer_candidates" "$mapped_stage" "in_progress" "$current" "$total" "$message"
        ;;
      timing)
        stage="$(echo "$line" | jq -r '.stage // ""' 2>/dev/null || true)"
        mapped_stage="$(php_event_stage_name "$stage")"
        duration_ms="$(echo "$line" | jq -r '.duration_ms // 0' 2>/dev/null || echo 0)"
        detail="$(echo "$line" | jq -r '.detail.detail // ""' 2>/dev/null || true)"
        guided_timing_record "infer-candidates" "$mapped_stage" "$duration_ms" "$detail"
        ;;
      debug)
        debug_message="$(echo "$line" | jq -r '.message // ""' 2>/dev/null || true)"
        debug_context="$(echo "$line" | jq -cr '.context // {}' 2>/dev/null || echo '{}')"
        if [ "$debug_context" = "{}" ]; then
          echo "[infer-debug] $debug_message" >&2
        else
          echo "[infer-debug] $debug_message: $debug_context" >&2
        fi
        ;;
      *)
        echo "$line" >&2
        ;;
    esac
  done
}

if [ ! -f "$PHP_ANALYZER" ]; then
  echo "錯誤：找不到 PHP analyzer：$PHP_ANALYZER" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [ $# -ge 2 ] || { echo "錯誤：--output 缺少值" >&2; exit 1; }
      OUTPUT_FILE="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --engine)
      [ $# -ge 2 ] || { echo "錯誤：--engine 缺少值" >&2; exit 1; }
      if [ "$2" != "php" ]; then
        echo "錯誤：infer-candidates.sh 已移除 shell engine，請使用預設 PHP analyzer。" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

PHP_STDOUT_FILE="$(mktemp)"
guided_timing_begin "infer_total"

exit_code=0
if php -n "$PHP_ANALYZER" "${FORWARD_ARGS[@]}" >"$PHP_STDOUT_FILE" 2> >(php_event_adapter); then
  JSON_SOURCE="$PHP_STDOUT_FILE"
  if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
    guided_timing_record "infer-candidates" "write_output" 0 "output=$OUTPUT_FILE"
    JSON_SOURCE="$OUTPUT_FILE"
    echo "候選清單已輸出：$OUTPUT_FILE" >&2
  fi

  route_count="$(jq -r '.indexes.routes // 0' "$JSON_SOURCE" 2>/dev/null || echo 0)"
  subset_count="$(jq -r '.indexes.evaluation_routes // 0' "$JSON_SOURCE" 2>/dev/null || echo 0)"
  candidate_count="$(jq -r '.candidate_count // 0' "$JSON_SOURCE" 2>/dev/null || echo 0)"
  guided_timing_end "infer-candidates" "infer_total" "routes=$route_count subset_routes=$subset_count candidates=$candidate_count"
  guided_progress_emit "infer_candidates" "candidate_evaluation" "done" 8 8 "candidate inference complete"
  cat "$PHP_STDOUT_FILE"
  rm -f "$PHP_STDOUT_FILE"
  exit 0
fi

exit_code=$?
cat "$PHP_STDOUT_FILE" >&2 || true
rm -f "$PHP_STDOUT_FILE"
exit "$exit_code"
