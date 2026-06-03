#!/bin/bash
set -euo pipefail

# 從完整 OpenAPI 與 confirmed candidates 產生 changed-only subset OpenAPI。

OPENAPI_FILE="docs/api-docs/openapi.yaml"
CANDIDATE_FILE=""
OUTPUT_FILE=""

usage() {
  cat <<'USAGE'
Usage: gen-subset-openapi.sh [options]

Options:
  --openapi FILE          Full OpenAPI YAML/JSON path (default: docs/api-docs/openapi.yaml)
  --candidate-file FILE   Confirmed candidate JSON path (required)
  --output FILE           Subset OpenAPI JSON output path
  -h, --help              Show help
USAGE
}

fail() {
  echo "錯誤：$*" >&2
  exit 1
}

normalize_spec_to_json_file() {
  local input_file="$1"
  local output_file="$2"

  if jq -e . "$input_file" >/dev/null 2>&1; then
    jq -c . "$input_file" >"$output_file"
    return 0
  fi

  yq -o=json '.' "$input_file" | jq -c . >"$output_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --candidate-file)
      CANDIDATE_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
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

[ -n "$CANDIDATE_FILE" ] || fail "必須提供 --candidate-file"
[ -f "$CANDIDATE_FILE" ] || fail "找不到 --candidate-file 指定檔案：$CANDIDATE_FILE"

if [ ! -f "$OPENAPI_FILE" ] && [ "$OPENAPI_FILE" = "docs/api-docs/openapi.yaml" ] && [ -f "docs/openapi.yaml" ]; then
  OPENAPI_FILE="docs/openapi.yaml"
fi

[ -f "$OPENAPI_FILE" ] || fail "找不到 OpenAPI 檔案：$OPENAPI_FILE"

if [ -z "$OUTPUT_FILE" ]; then
  ts="$(date '+%Y%m%d-%H%M%S')"
  OUTPUT_FILE="docs/api-docs/versions/${ts}/subset-openapi.json"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

SPEC_JSON_FILE="$(mktemp)"
trap 'rm -f "$SPEC_JSON_FILE"' EXIT
normalize_spec_to_json_file "$OPENAPI_FILE" "$SPEC_JSON_FILE"

CANDIDATES_JSON="$(
  jq -c '
    (.candidates // [])
    | map(select((.status // "" | ascii_downcase) == "new" or (.status // "" | ascii_downcase) == "updated"))
    | map({
        method: ((.method // "") | ascii_downcase),
        path: (.path // "")
      })
    | map(select((.method | length > 0) and (.path | length > 0)))
    | unique_by(.method, .path)
  ' "$CANDIDATE_FILE"
)"

CANDIDATE_COUNT="$(echo "$CANDIDATES_JSON" | jq 'length')"
[ "$CANDIDATE_COUNT" -gt 0 ] || fail "confirmed candidate file 中沒有可產生 subset 的 new/updated endpoint"

MATCHED_COUNT="$(
  jq --argjson candidates "$CANDIDATES_JSON" '
    . as $spec
    |
    [
      $candidates[]
      | (.path // "") as $candidate_path
      | ((.method // "") | ascii_downcase) as $candidate_method
      | select($candidate_path != "" and $candidate_method != "")
      | select((($spec.paths[$candidate_path] // {}) | has($candidate_method)))
    ] | length
  ' "$SPEC_JSON_FILE"
)"

if [ "$MATCHED_COUNT" -eq 0 ]; then
  echo "candidate operations: $(echo "$CANDIDATES_JSON" | jq -r 'map((.method | ascii_upcase) + " " + .path) | join(", ")')" >&2
  fail "candidate operations 與 OpenAPI path/method 無任何匹配"
fi

jq --argjson candidates "$CANDIDATES_JSON" '
  def method_keys: ["get", "put", "post", "delete", "options", "head", "patch", "trace"];
  def candidate_methods_for_path($path):
    $candidates
    | map(select((.path // "") == $path))
    | map((.method // "") | ascii_downcase)
    | unique;

  . + {
    paths: (
      (.paths // {})
      | to_entries
      | map(. as $path_entry
        | (candidate_methods_for_path($path_entry.key)) as $candidate_methods
        | select(($candidate_methods | length) > 0)
        | {
            key: $path_entry.key,
            value: (
              $path_entry.value
              | with_entries(. as $operation_entry | select(
                  ($operation_entry.key == "parameters")
                  or ((method_keys | index($operation_entry.key)) != null and (($candidate_methods | index($operation_entry.key)) != null))
                ))
            )
          }
      )
      | map(select((.value | keys | map(select(. != "parameters")) | length) > 0))
      | from_entries
    )
  }
' "$SPEC_JSON_FILE" >"$OUTPUT_FILE"

echo "Subset OpenAPI 已輸出：$OUTPUT_FILE" >&2
jq -n \
  --arg openapi_file "$OPENAPI_FILE" \
  --arg candidate_file "$CANDIDATE_FILE" \
  --arg output_file "$OUTPUT_FILE" \
  --argjson candidate_count "$CANDIDATE_COUNT" \
  --argjson matched_count "$MATCHED_COUNT" \
  '{
    openapi_file: $openapi_file,
    candidate_file: $candidate_file,
    output_file: $output_file,
    candidate_count: $candidate_count,
    matched_count: $matched_count
  }'
