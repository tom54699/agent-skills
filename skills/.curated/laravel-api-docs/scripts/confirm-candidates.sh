#!/bin/bash
set -euo pipefail

# 將候選清單或使用者確認後的工作清單正規化為 confirmed artifact
# 輸入可為：
# - infer-candidates.sh 的完整輸出物件（含 .candidates）
# - 純 candidates array

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

INPUT_FILE=""
OUTPUT_FILE=""
SOURCE_FILE=""
PROGRESS_ENABLED=1
GUIDED_TIMING_FILE="$(mktemp)"

usage() {
  cat <<'USAGE'
Usage: confirm-candidates.sh [options]

Options:
  --input FILE             Candidate JSON file (required)
  --output FILE            Confirmed JSON output path
  --source FILE            Source candidate file path recorded in meta
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
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --source)
      SOURCE_FILE="$2"
      shift 2
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
      usage >&2
      exit 1
      ;;
  esac
done

guided_progress_set_enabled "$PROGRESS_ENABLED"
trap 'rm -f "$GUIDED_TIMING_FILE"' EXIT

guided_progress_emit "confirm_candidate_list" "validate_input" "in_progress" 0 4 "starting candidate confirmation"
guided_timing_begin "confirm_total"

if [ -z "$INPUT_FILE" ]; then
  echo "錯誤：必須提供 --input" >&2
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "錯誤：找不到輸入檔案 $INPUT_FILE" >&2
  exit 1
fi

if [ -z "$SOURCE_FILE" ]; then
  SOURCE_FILE="$INPUT_FILE"
fi

if [ -z "$OUTPUT_FILE" ]; then
  ts="$(date -u +"%Y%m%dT%H%M%SZ")"
  OUTPUT_FILE="docs/api-docs/candidates/${ts}.confirmed.json"
fi

guided_progress_emit "confirm_candidate_list" "validate_input" "in_progress" 1 4 "input validated"
guided_timing_begin "normalize_candidates"

mkdir -p "$(dirname "$OUTPUT_FILE")"

INPUT_JSON="$(cat "$INPUT_FILE")"
PATH_STRATEGY="$(
  echo "$INPUT_JSON" | jq -r '
    if type == "object" then
      (.meta.path_strategy // "")
    else
      ""
    end
  '
)"

NORMALIZED_CANDIDATES="$(
  echo "$INPUT_JSON" | jq '
    if type == "object" then
      (.candidates // [])
    elif type == "array" then
      .
    else
      []
    end
    | map({
        status: ((.status // "") | ascii_downcase),
        method: ((.method // "") | ascii_upcase),
        path: (.path // ""),
        folder_id: (
          if has("folder_id") and (.folder_id != null) and ((.folder_id | tostring) | test("^[0-9]+$")) then
            (.folder_id | tonumber)
          else
            null
          end
        )
      })
    | map(select(
        (.status == "new" or .status == "updated" or .status == "deleted")
        and (.method | length > 0)
        and (.path | length > 0)
      ))
    | unique_by(.status, .method, .path)
    | map(if .folder_id == null then del(.folder_id) else . end)
    | sort_by(.path, .method, .status)
  '
)"

CANDIDATE_COUNT="$(echo "$NORMALIZED_CANDIDATES" | jq 'length')"
CONFIRMED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
guided_timing_end "confirm-candidates" "normalize_candidates" "candidates=$CANDIDATE_COUNT"
guided_progress_emit "confirm_candidate_list" "normalize_candidates" "in_progress" 2 4 "normalized $CANDIDATE_COUNT candidates"
guided_timing_begin "write_output"

RESULT="$(
  jq -n \
    --arg confirmed_at "$CONFIRMED_AT" \
    --arg source_candidate_file "$SOURCE_FILE" \
    --arg input_file "$INPUT_FILE" \
    --arg output_file "$OUTPUT_FILE" \
    --arg path_strategy "$PATH_STRATEGY" \
    --argjson candidates "$NORMALIZED_CANDIDATES" \
    '{
      meta: {
        confirmed_at: $confirmed_at,
        source_candidate_file: $source_candidate_file,
        input_file: $input_file,
        output_file: $output_file,
        path_strategy: (if $path_strategy == "" then null else $path_strategy end)
      },
      candidate_count: ($candidates | length),
      candidates: $candidates
    }'
)"

echo "$RESULT" | jq '.' > "$OUTPUT_FILE"
guided_timing_end "confirm-candidates" "write_output" "output=$OUTPUT_FILE"
guided_progress_emit "confirm_candidate_list" "write_output" "in_progress" 3 4 "confirmed file written"
guided_timing_end "confirm-candidates" "confirm_total" "candidates=$CANDIDATE_COUNT"
TIMINGS_JSON="$(guided_timing_json)"
guided_progress_emit "confirm_candidate_list" "complete" "done" 4 4 "candidate confirmation complete"
echo "確認清單已輸出：$OUTPUT_FILE" >&2
echo "$RESULT" | jq --argjson timings "$TIMINGS_JSON" '. + {timings: $timings}'
