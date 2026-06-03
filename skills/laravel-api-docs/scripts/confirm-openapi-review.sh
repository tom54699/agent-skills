#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

INPUT_FILE=""
DECISIONS_FILE=""
OUTPUT_FILE=""
ACCEPT_ALL=false
PROGRESS_ENABLED=1
GUIDED_TIMING_FILE="$(mktemp)"

usage() {
  cat <<'USAGE'
Usage: confirm-openapi-review.sh [options]

Options:
  --input FILE             Review artifact JSON file
  --decisions FILE         Working decision JSON file
  --output FILE            Decision artifact output path
  --accept-all             Accept all review items
  --no-progress            Disable progress output
  -h, --help               Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_FILE="$2"
      shift 2
      ;;
    --decisions)
      DECISIONS_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --accept-all)
      ACCEPT_ALL=true
      shift
      ;;
    --no-progress)
      PROGRESS_ENABLED=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

guided_progress_set_enabled "$PROGRESS_ENABLED"
trap 'rm -f "$GUIDED_TIMING_FILE"' EXIT
guided_progress_emit "confirm_openapi_review" "validate_input" "in_progress" 0 4 "starting review confirmation"
guided_timing_begin "review_confirm_total"

[ -n "$INPUT_FILE" ] || { echo "錯誤：必須提供 --input" >&2; exit 1; }
[ -f "$INPUT_FILE" ] || { echo "錯誤：找不到 review artifact $INPUT_FILE" >&2; exit 1; }

if [ "$ACCEPT_ALL" = false ] && [ -z "$DECISIONS_FILE" ]; then
  echo "錯誤：必須提供 --accept-all 或 --decisions" >&2
  exit 1
fi

if [ -n "$DECISIONS_FILE" ] && [ ! -f "$DECISIONS_FILE" ]; then
  echo "錯誤：找不到 decisions 檔案 $DECISIONS_FILE" >&2
  exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
  ts="$(date -u +"%Y%m%dT%H%M%SZ")"
  OUTPUT_FILE="docs/api-docs/reviews/${ts}.approved.json"
fi

REVIEW_ITEMS="$(
  jq -c '
    [
      (.unresolved_validation_rules // [])[],
      (.unresolved_response_shape // [])[],
      (.unresolved_security // [])[],
      (.low_confidence_examples // [])[]
    ]
  ' "$INPUT_FILE"
)"

REVIEW_COUNT="$(echo "$REVIEW_ITEMS" | jq 'length')"
guided_progress_emit "confirm_openapi_review" "validate_input" "in_progress" 1 4 "review artifact loaded"

if [ "$ACCEPT_ALL" = true ]; then
  NORMALIZED_DECISIONS="$(
    echo "$REVIEW_ITEMS" | jq '
      map({
        id: .id,
        action: "accept",
        note: "accepted via --accept-all"
      })
    '
  )"
else
  NORMALIZED_DECISIONS="$(
    jq '
      if type == "object" then
        (.decisions // [])
      elif type == "array" then
        .
      else
        []
      end
      | map({
          id: (.id // ""),
          action: ((.action // "") | ascii_downcase),
          note: (.note // "")
        })
      | map(select((.id | length > 0) and (.action == "accept" or .action == "reject")))
      | unique_by(.id)
    ' "$DECISIONS_FILE"
  )"
fi

guided_progress_emit "confirm_openapi_review" "normalize_decisions" "in_progress" 2 4 "decisions normalized"
mkdir -p "$(dirname "$OUTPUT_FILE")"

CONFIRMED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
RESULT="$(
  jq -n \
    --arg review_file "$INPUT_FILE" \
    --arg decisions_file "$DECISIONS_FILE" \
    --arg output_file "$OUTPUT_FILE" \
    --arg confirmed_at "$CONFIRMED_AT" \
    --argjson review_count "$REVIEW_COUNT" \
    --argjson decisions "$NORMALIZED_DECISIONS" \
    '{
      meta: {
        review_file: $review_file,
        decisions_file: (if $decisions_file == "" then null else $decisions_file end),
        output_file: $output_file,
        confirmed_at: $confirmed_at,
        review_item_count: $review_count
      },
      review_item_count: $review_count,
      decisions: $decisions
    }'
)"

echo "$RESULT" | jq '.' > "$OUTPUT_FILE"
guided_progress_emit "confirm_openapi_review" "write_output" "in_progress" 3 4 "decision artifact written"
guided_timing_end "confirm-openapi-review" "review_confirm_total" "review_items=$REVIEW_COUNT"
TIMINGS_JSON="$(guided_timing_json)"
guided_progress_emit "confirm_openapi_review" "complete" "done" 4 4 "review confirmation complete"
echo "Review decision 已輸出：$OUTPUT_FILE" >&2
echo "$RESULT" | jq --argjson timings "$TIMINGS_JSON" '. + {timings: $timings}'
