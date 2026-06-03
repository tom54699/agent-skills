#!/bin/bash
set -euo pipefail

# 上傳 OpenAPI 文件至 Apidog，成功後自動寫入 sync history
# 若提供 confirmed candidate file，會先對 updated endpoints 做本地/遠端衝突檢查

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

OPENAPI_FILE="docs/api-docs/openapi.yaml"
HISTORY_FILE="docs/api-docs/history/apidog-sync-history.jsonl"
CANDIDATE_FILE=""
REVIEW_FILE=""
REVIEW_DECISION_FILE=""
REMOTE_OPENAPI_FILE=""
CONFLICT_FILE=""
CONFLICT_STRATEGY="keep_remote"
PATH_STRATEGY=""
CONFLICT_COUNT=0
FROM_TIME=""
TO_TIME=""
SKIP_HISTORY=false
NO_DELTA=false
FOLDER_AWARE=true
ALLOW_ROOT_FOLDER_FALLBACK=false
APIDOG_TREE_FILE=""
APIDOG_TREE_OUTPUT=""
FOLDER_MAPPING_FILE=""
FOLDER_DECISION_FILE=""
SKIP_ALIGNMENT_CHECK=false
PROGRESS_ENABLED=1
GUIDED_TIMING_FILE="$(mktemp)"
UPDATED_CANDIDATE_COUNT=0
VERIFY_MISSING_COUNT=0
VERIFY_MISSING_SAMPLE=""

usage() {
  cat <<'USAGE'
Usage: upload-apidog.sh [options]

Options:
  --openapi FILE            OpenAPI file path
  --history FILE            Sync history JSONL path
  --candidate-file FILE     Confirmed candidate JSON path
  --path-strategy STRATEGY  keep-full-path | strip-api-prefix-to-server
  --review-file FILE        Unresolved review artifact JSON path
  --review-decision-file FILE Review decision artifact JSON path
  --remote-openapi FILE     Override remote OpenAPI source for conflict compare
  --conflict-file FILE      Conflict output path
  --from-time UTC_ISO8601   Candidate range start time
  --to-time UTC_ISO8601     Candidate range end time
  --conflict-count N        Deprecated placeholder; actual count comes from conflict result
  --conflict STRATEGY       keep_remote | use_local | manual_merge (default: keep_remote)
  --skip-history            Do not append history after upload
  --no-delta                Upload full spec instead of filtering to confirmed candidates
  --no-folder-aware         Disable folder-aware delta upload grouping
  --allow-root-folder-fallback
                            Allow unmapped candidates to upload to root folder 0
  --apidog-tree-file FILE   Use an existing Apidog API tree JSON file
  --apidog-tree-output FILE Save fetched Apidog API tree JSON to FILE
  --folder-mapping-file FILE
                            Save parsed folder mapping JSON to FILE
  --folder-decision-file FILE
                            Save resolved candidate folder decisions JSON to FILE
  --skip-alignment-check    Skip path strategy alignment check before upload
  --no-progress             Disable progress output
  -h, --help                Show help
USAGE
}

fail() {
  echo "錯誤：$*" >&2
  exit 1
}

is_non_negative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

to_int_or_zero() {
  local value="$1"
  if is_non_negative_int "$value"; then
    echo "$value"
  else
    echo "0"
  fi
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

detect_path_strategy_from_openapi() {
  local spec_file="$1"
  local json_file
  json_file="$(mktemp)"
  normalize_spec_to_json_file "$spec_file" "$json_file"

  local detected
  detected="$(jq -r '
    if ((.paths | keys | map(select(. == "/api" or startswith("/api/"))) | length) > 0) then
      "keep-full-path"
    elif ((.paths | keys | length) > 0) then
      "strip-api-prefix-to-server"
    elif ((.servers // []) | map(.url // "") | map(select(test("/api(/|$)"))) | length > 0) then
      "strip-api-prefix-to-server"
    else
      ""
    end
  ' "$json_file" 2>/dev/null || true)"

  rm -f "$json_file"
  printf '%s' "$detected"
}

extract_operation_signature() {
  local spec_file="$1"
  local path="$2"
  local method="$3"

  jq -c \
    --arg path "$path" \
    --arg method "$method" \
    '
      (.paths[$path][$method] // null)
      | if . == null then
          null
        else
          {
            summary: (.summary // ""),
            description: (.description // ""),
            parameters: (
              (.parameters // [])
              | map({
                  name: (.name // ""),
                  in: (.in // ""),
                  required: (.required // false),
                  schema: (.schema // null)
                })
              | sort_by(.in, .name)
            ),
            requestBody: (.requestBody // null),
            responses: (
              (.responses // {})
              | to_entries
              | sort_by(.key)
              | from_entries
            ),
            tags: ((.tags // []) | sort)
          }
        end
    ' "$spec_file"
}

export_remote_openapi_json() {
  local output_file="$1"

  if [ -n "$REMOTE_OPENAPI_FILE" ]; then
    [ -f "$REMOTE_OPENAPI_FILE" ] || fail "找不到 --remote-openapi 指定檔案：$REMOTE_OPENAPI_FILE"
    normalize_spec_to_json_file "$REMOTE_OPENAPI_FILE" "$output_file"
    return 0
  fi

  local request_file
  local response_file
  local http_code
  request_file="$(mktemp)"
  response_file="$(mktemp)"

  jq -n '{
    scope: {
      type: "ALL"
    },
    options: {
      includeApidogExtensionProperties: false,
      addFoldersToTags: false
    },
    oasVersion: "3.1",
    exportFormat: "JSON"
  }' >"$request_file"

  http_code="$(curl -s -w "%{http_code}" -o "$response_file" \
    -X POST "https://api.apidog.com/v1/projects/$APIDOG_PROJECT_ID/export-openapi?locale=en-US" \
    -H "Authorization: Bearer $APIDOG_ACCESS_TOKEN" \
    -H "X-Apidog-Api-Version: 2024-03-28" \
    -H "Content-Type: application/json" \
    -d @"$request_file")"

  rm -f "$request_file"

  if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    cat "$response_file" >&2 || true
    rm -f "$response_file"
    fail "無法取得 Apidog 遠端 OpenAPI (HTTP ${http_code})"
  fi

  if jq -e '.data.content? | type == "string"' "$response_file" >/dev/null 2>&1; then
    jq -r '.data.content' "$response_file" | jq -c . >"$output_file"
    rm -f "$response_file"
    return 0
  fi

  if jq -e '.data.content? | type == "object"' "$response_file" >/dev/null 2>&1; then
    jq -c '.data.content' "$response_file" >"$output_file"
    rm -f "$response_file"
    return 0
  fi

  if jq -e '.data.openapi? | type == "object"' "$response_file" >/dev/null 2>&1; then
    jq -c '.data.openapi' "$response_file" >"$output_file"
    rm -f "$response_file"
    return 0
  fi

  if jq -e '.openapi? != null or .paths? != null' "$response_file" >/dev/null 2>&1; then
    jq -c . "$response_file" >"$output_file"
    rm -f "$response_file"
    return 0
  fi

  cat "$response_file" >&2 || true
  rm -f "$response_file"
  fail "Apidog export-openapi 回應格式無法辨識"
}

detect_conflicts() {
  local local_spec_file="$1"
  local remote_spec_file="$2"
  local candidate_file="$3"
  local output_file="$4"
  local updated_candidates
  local conflicts_json='[]'

  updated_candidates="$(
    jq -c '
      (.candidates // [])
      | map(select((.status // "" | ascii_downcase) == "updated"))
      | map({
          method: ((.method // "") | ascii_downcase),
          path: (.path // "")
        })
      | map(select((.method | length > 0) and (.path | length > 0)))
      | unique_by(.method, .path)
    ' "$candidate_file"
  )"

  UPDATED_CANDIDATE_COUNT="$(echo "$updated_candidates" | jq 'length')"
  if [ "$UPDATED_CANDIDATE_COUNT" -eq 0 ]; then
    CONFLICT_COUNT=0
    return 0
  fi

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue

    local method
    local path
    local local_op
    local remote_op
    local local_present
    local remote_present
    local changed_fields
    local conflict_type
    local reason
    local suggested_action
    local blocking

    method="$(echo "$candidate" | jq -r '.method')"
    path="$(echo "$candidate" | jq -r '.path')"

    local_op="$(extract_operation_signature "$local_spec_file" "$path" "$method")"
    remote_op="$(extract_operation_signature "$remote_spec_file" "$path" "$method")"

    local_present=false
    remote_present=false
    [ "$local_op" != "null" ] && local_present=true
    [ "$remote_op" != "null" ] && remote_present=true

    if [ "$local_op" = "$remote_op" ]; then
      continue
    fi

    if [ "$local_present" = true ] && [ "$remote_present" = false ]; then
      changed_fields='["remote_missing"]'
      conflict_type="missing_remote_endpoint"
      reason="遠端不存在對應 operation，但 confirmed 清單要求更新"
      suggested_action="use_local"
      blocking=false
    elif [ "$local_present" = false ] && [ "$remote_present" = true ]; then
      changed_fields='["local_missing"]'
      conflict_type="missing_local_endpoint"
      reason="本地 OpenAPI 缺少對應 operation，但遠端仍存在"
      suggested_action="keep_remote"
      blocking=true
    else
      changed_fields="$(
        jq -cn \
          --argjson local "$local_op" \
          --argjson remote "$remote_op" \
          '[
            "summary",
            "description",
            "parameters",
            "requestBody",
            "responses",
            "tags"
          ] | map(select(($local[.] // null) != ($remote[.] // null)))'
      )"
      conflict_type="operation_mismatch"
      reason="本地與遠端 operation 欄位不一致：$(echo "$changed_fields" | jq -cr 'join(", ")')"
      suggested_action="manual_merge"
      blocking=true
    fi

    conflicts_json="$(
      echo "$conflicts_json" | jq \
        --arg method "$(echo "$method" | tr '[:lower:]' '[:upper:]')" \
        --arg path "$path" \
        --arg conflict_type "$conflict_type" \
        --arg reason "$reason" \
        --arg suggested_action "$suggested_action" \
        --argjson changed_fields "$changed_fields" \
        --argjson local_present "$local_present" \
        --argjson remote_present "$remote_present" \
        --argjson blocking "$blocking" \
        '. + [{
          method: $method,
          path: $path,
          conflict_type: $conflict_type,
          reason: $reason,
          suggested_action: $suggested_action,
          changed_fields: $changed_fields,
          local_present: $local_present,
          remote_present: $remote_present,
          blocking: $blocking
        }]'
    )"
  done < <(echo "$updated_candidates" | jq -cr '.[]')

  CONFLICT_COUNT="$(echo "$conflicts_json" | jq 'length')"
  if [ "$CONFLICT_COUNT" -gt 0 ]; then
    mkdir -p "$(dirname "$output_file")"
    echo "$conflicts_json" | jq '.' >"$output_file"
  fi
}

active_candidates_json() {
  local candidate_file="$1"

  jq -c '
    (.candidates // [])
    | map(select(((.status // "" | ascii_downcase) == "new") or ((.status // "" | ascii_downcase) == "updated")))
    | map({
        method: ((.method // "") | ascii_downcase),
        path: (.path // ""),
        folder_id: (
          if has("folder_id") and (.folder_id != null) and ((.folder_id | tostring) | test("^[0-9]+$")) then
            (.folder_id | tonumber)
          else
            null
          end
        )
      })
    | map(select((.method | length > 0) and (.path | length > 0)))
    | unique_by(.method, .path)
  ' "$candidate_file"
}

fetch_apidog_tree() {
  local output_file="$1"
  local response_file
  local http_code
  response_file="$(mktemp)"

  http_code="$(curl -s -w "%{http_code}" -o "$response_file" \
    -X GET "https://api.apidog.com/api/v1/projects/$APIDOG_PROJECT_ID/api-tree-list" \
    -H "Authorization: Bearer $APIDOG_ACCESS_TOKEN" \
    -H "X-Apidog-Api-Version: 2024-03-28")"

  if [[ "$http_code" =~ ^30[0-9]$ ]]; then
    cat "$response_file" >&2 || true
    rm -f "$response_file"
    echo "錯誤：api-tree-list 收到 HTTP redirect。此 endpoint 必須使用 /api/v1/ 前綴，不可使用 /v1/。" >&2
    return 1
  fi

  if [ "$http_code" -ne 200 ]; then
    cat "$response_file" >&2 || true
    if grep -qi "No project guest privilege" "$response_file" 2>/dev/null; then
      echo "錯誤：Apidog token 或 project 權限不足，無法讀取 API tree。" >&2
    else
      echo "錯誤：無法取得 Apidog API tree (HTTP ${http_code})。" >&2
    fi
    rm -f "$response_file"
    return 1
  fi

  if ! jq -e '(.success == true and (.data != null)) or (.data != null) or (type == "array")' "$response_file" >/dev/null 2>&1; then
    cat "$response_file" >&2 || true
    rm -f "$response_file"
    echo "錯誤：Apidog API tree 回應格式無法辨識。" >&2
    return 1
  fi

  mkdir -p "$(dirname "$output_file")"
  jq '.' "$response_file" >"$output_file"
  rm -f "$response_file"
}

build_apidog_folder_mapping() {
  local tree_file="$1"
  local output_file="$2"

  jq '
    def node_type:
      (.type // .nodeType // .kind // "");

    def node_key:
      (.key // .id // "");

    def folder_id_from_key:
      (node_key | tostring) as $key
      | if ($key | test("[0-9]+$")) then
          ($key | capture("(?<id>[0-9]+)$").id | tonumber)
        else
          null
        end;

    def child_nodes:
      (.children // .items // .list // []);

    def walk_tree($folder_id):
      . as $node
      | (
          if ((node_type == "apiDetailFolder") or ((node_key | tostring) | startswith("apiDetailFolder."))) then
            (folder_id_from_key // $folder_id)
          else
            $folder_id
          end
        ) as $current_folder_id
      | (
          if ((node_type == "apiDetail") or ((.api? | type) == "object" and ((.api.path? // "") != ""))) then
            {
              method: ((.api.method // .api.httpMethod // .method // "") | tostring | ascii_downcase),
              path: ((.api.path // .path // "") | tostring),
              folder_id: (.api.folderId // .folderId // $current_folder_id)
            }
          else
            empty
          end
        ),
        (child_nodes[]? | walk_tree($current_folder_id));

    def normalize_path:
      if . == "/" then
        .
      else
        sub("/+$"; "")
      end;

    def path_prefixes:
      (.path | normalize_path | split("/") | map(select(length > 0))) as $segments
      | [
          range(0; ($segments | length)) as $i
          | ($segments[0:($i + 1)]) as $parts
          | select((($parts[0] // "") != "api") or (($parts | length) >= 2))
          | select(($parts | map(test("\\{")) | any) | not)
          | "/" + ($parts | join("/"))
        ];

    [((.data // .) | if type == "array" then .[] else . end | walk_tree(null))]
    | map(select(
        (.method | length > 0)
        and (.path | length > 0)
        and (.folder_id != null)
        and ((.folder_id | tostring) | test("^[0-9]+$"))
      ))
    | map(. + {path: (.path | normalize_path), folder_id: (.folder_id | tonumber)})
    | unique_by(.method, .path)
    | . as $exact
    | {
        exact: $exact,
        prefixes: (
          $exact
          | map(. as $entry | ($entry | path_prefixes)[] as $prefix | {prefix: $prefix, folder_id: $entry.folder_id})
          | sort_by(.prefix)
          | group_by(.prefix)
          | map({prefix: .[0].prefix, folder_id: .[0].folder_id})
          | sort_by(.prefix | length)
        )
      }
  ' "$tree_file" >"$output_file"
}

resolve_candidate_folder_decisions() {
  local candidate_file="$1"
  local mapping_file="$2"
  local allow_root_fallback="$3"
  local output_file="$4"

  jq -n \
    --slurpfile candidates "$candidate_file" \
    --slurpfile mapping "$mapping_file" \
    --argjson allow_root_fallback "$allow_root_fallback" \
    '
      def normalize_path:
        if . == "/" then
          .
        else
          sub("/+$"; "")
        end;

      def active_candidates:
        ($candidates[0].candidates // [])
        | map(select(((.status // "" | ascii_downcase) == "new") or ((.status // "" | ascii_downcase) == "updated")))
        | map({
            status: (.status // "" | ascii_downcase),
            method: ((.method // "") | ascii_downcase),
            path: ((.path // "") | normalize_path),
            folder_id: (
              if has("folder_id") and (.folder_id != null) and ((.folder_id | tostring) | test("^[0-9]+$")) then
                (.folder_id | tonumber)
              else
                null
              end
            )
          })
        | map(select((.method | length > 0) and (.path | length > 0)))
        | unique_by(.method, .path);

      def exact_folder($candidate):
        ($mapping[0].exact // [])
        | map(select(.method == $candidate.method and (.path | normalize_path) == $candidate.path))
        | .[0].folder_id // null;

      def prefix_folder($candidate):
        ($mapping[0].prefixes // [])
        | map(. as $prefix_entry | select(
            ($candidate.path == ($prefix_entry.prefix | normalize_path))
            or ($candidate.path | startswith(($prefix_entry.prefix | normalize_path) + "/"))
          ))
        | sort_by(.prefix | length)
        | reverse
        | .[0].folder_id // null;

      active_candidates
      | map(. as $candidate
        | if $candidate.folder_id != null then
            $candidate + {resolved_folder_id: $candidate.folder_id, folder_source: "candidate.folder_id"}
          elif (exact_folder($candidate) != null) then
            $candidate + {resolved_folder_id: exact_folder($candidate), folder_source: "api_tree_exact"}
          elif (prefix_folder($candidate) != null) then
            $candidate + {resolved_folder_id: prefix_folder($candidate), folder_source: "api_tree_prefix"}
          elif $allow_root_fallback then
            $candidate + {resolved_folder_id: 0, folder_source: "root_fallback"}
          else
            $candidate + {resolved_folder_id: null, folder_source: "unmapped"}
          end
      ) as $decisions
      | {
          decisions: $decisions,
          unmapped: ($decisions | map(select(.resolved_folder_id == null))),
          groups: (
            $decisions
            | map(select(.resolved_folder_id != null))
            | sort_by(.resolved_folder_id, .path, .method)
            | group_by(.resolved_folder_id)
            | map({
                folder_id: .[0].resolved_folder_id,
                candidates: map({
                  status: .status,
                  method: (.method | ascii_upcase),
                  path: .path,
                  folder_id: .resolved_folder_id,
                  folder_source: .folder_source
                })
              })
          )
        }
    ' >"$output_file"
}

review_item_count() {
  local review_file="$1"
  jq '
    [
      (.unresolved_validation_rules // [])[],
      (.unresolved_response_shape // [])[],
      (.unresolved_security // [])[],
      (.low_confidence_examples // [])[]
    ] | length
  ' "$review_file"
}

enforce_review_gate() {
  local review_file="$1"
  local decision_file="$2"

  [ -f "$review_file" ] || fail "找不到 --review-file 指定檔案：${review_file}"

  local review_count
  local missing_count
  review_count="$(review_item_count "$review_file")"

  if [ "$review_count" -eq 0 ]; then
    return 0
  fi

  [ -n "$decision_file" ] || fail "偵測到 ${review_count} 個 unresolved review items，請先確認 review artifact 後再上傳"
  [ -f "$decision_file" ] || fail "找不到 --review-decision-file 指定檔案：${decision_file}"

  missing_count="$(
    jq \
      --arg review_file "$review_file" \
      --slurpfile review "$review_file" \
      '
        if (.meta.review_file // "") != $review_file then
          -1
        else
          (
            [
              ($review[0].unresolved_validation_rules // [])[],
              ($review[0].unresolved_response_shape // [])[],
              ($review[0].unresolved_security // [])[],
              ($review[0].low_confidence_examples // [])[]
            ]
            | map(.id)
          ) as $review_ids
          | (
              (.decisions // [])
              | map(select((.action // "" | ascii_downcase) == "accept"))
              | map(.id)
            ) as $accepted_ids
          | ($review_ids - $accepted_ids | length)
        end
      ' "$decision_file"
  )"

  if [ "$missing_count" -lt 0 ]; then
    fail "review decision artifact 與 review artifact 不一致"
  fi

  if [ "$missing_count" -gt 0 ]; then
    fail "review decision 尚未覆蓋所有 unresolved items（尚缺 ${missing_count} 項）"
  fi
}

verify_remote_upload_result() {
  local remote_spec_file="$1"
  local candidate_file="$2"
  local missing_json='[]'
  VERIFY_MISSING_COUNT=0
  VERIFY_MISSING_SAMPLE=""

  if [ -n "$candidate_file" ]; then
    local active_candidates
    active_candidates="$(active_candidates_json "$candidate_file")"

    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue

      local method
      local path
      local remote_op

      method="$(echo "$candidate" | jq -r '.method')"
      path="$(echo "$candidate" | jq -r '.path')"
      remote_op="$(extract_operation_signature "$remote_spec_file" "$path" "$method")"
      if [ "$remote_op" != "null" ]; then
        continue
      fi

      missing_json="$(
        echo "$missing_json" | jq \
          --arg method "$(echo "$method" | tr '[:lower:]' '[:upper:]')" \
          --arg path "$path" \
          '. + [{method: $method, path: $path}]'
      )"
    done < <(echo "$active_candidates" | jq -cr '.[]')

    VERIFY_MISSING_COUNT="$(echo "$missing_json" | jq 'length')"
    VERIFY_MISSING_SAMPLE="$(echo "$missing_json" | jq -r '.[0:5] | map(.method + " " + .path) | join(", ")')"
    [ "$VERIFY_MISSING_COUNT" -eq 0 ]
    return $?
  fi

  if jq -e '((.paths // {}) | type == "object") and (((.paths // {}) | keys | length) > 0)' "$remote_spec_file" >/dev/null 2>&1; then
    return 0
  fi

  VERIFY_MISSING_COUNT=1
  VERIFY_MISSING_SAMPLE="remote export has empty paths"
  return 1
}

apply_keep_remote_strategy() {
  local local_spec_file="$1"
  local remote_spec_file="$2"
  local conflict_file="$3"
  local output_file="$4"

  cp "$local_spec_file" "$output_file"

  while IFS= read -r conflict; do
    [ -n "$conflict" ] || continue

    local method
    local path
    local remote_present
    local blocking
    local remote_op
    local tmp_file

    method="$(echo "$conflict" | jq -r '.method | ascii_downcase')"
    path="$(echo "$conflict" | jq -r '.path')"
    remote_present="$(echo "$conflict" | jq -r '.remote_present')"
    blocking="$(echo "$conflict" | jq -r 'if has("blocking") then .blocking else true end')"

    if [ "$blocking" != "true" ]; then
      continue
    fi

    tmp_file="$(mktemp)"

    if [ "$remote_present" = "true" ]; then
      remote_op="$(extract_operation_signature "$remote_spec_file" "$path" "$method")"
      jq \
        --arg path "$path" \
        --arg method "$method" \
        --argjson op "$remote_op" \
        '.paths[$path][$method] = $op' \
        "$output_file" >"$tmp_file"
    else
      jq \
        --arg path "$path" \
        --arg method "$method" \
        'del(.paths[$path][$method]) | if ((.paths[$path] // {}) | length) == 0 then del(.paths[$path]) else . end' \
        "$output_file" >"$tmp_file"
    fi

    mv "$tmp_file" "$output_file"
  done < <(jq -cr '.[]' "$conflict_file")
}

build_subset_spec_from_candidates_json() {
  local full_spec_file="$1"
  local candidates_json="$2"
  local output_file="$3"

  local candidate_count
  candidate_count="$(echo "$candidates_json" | jq 'length')"

  local delta_operation_count
  delta_operation_count="$(jq --argjson candidates "$candidates_json" '
    def method_keys: ["get", "put", "post", "delete", "options", "head", "patch", "trace"];
    . as $spec
    |
    [
      $candidates[]
      | (.path // "") as $candidate_path
      | ((.method // "") | ascii_downcase) as $candidate_method
      | select($candidate_path != "" and $candidate_method != "")
      | select((($spec.paths[$candidate_path] // {}) | has($candidate_method)))
    ] | length
  ' "$full_spec_file")"

  if [ "$delta_operation_count" -eq 0 ]; then
    echo "錯誤：candidate operations 與 local spec 的 path/method 無任何匹配" >&2
    echo "  candidate operations: $(echo "$candidates_json" | jq -r 'map((.method // "") + " " + (.path // "")) | join(", ")')" >&2
    echo "  請確認 path_strategy 是否與 local spec 一致" >&2
    return 1
  fi

  jq --argjson candidates "$candidates_json" '
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
  ' "$full_spec_file" > "$output_file"
  echo "Delta 模式：從 local spec 過濾出 ${delta_operation_count}/${candidate_count} 個 candidate endpoint 上傳" >&2
}

build_delta_spec() {
  local full_spec_file="$1"
  local candidate_file="$2"
  local output_file="$3"

  local candidates_json
  candidates_json="$(active_candidates_json "$candidate_file")"

  local candidate_count
  candidate_count="$(echo "$candidates_json" | jq 'length')"

  if [ "$candidate_count" -eq 0 ]; then
    echo "警告：candidate file 中無 new/updated 項目，跳過 delta 過濾，改用全量上傳" >&2
    cp "$full_spec_file" "$output_file"
    return 0
  fi

  build_subset_spec_from_candidates_json "$full_spec_file" "$candidates_json" "$output_file"
}

check_path_strategy_alignment() {
  local remote_spec_file="$1"

  [ "$SKIP_ALIGNMENT_CHECK" = true ] && return 0
  [ -z "$PATH_STRATEGY" ] && return 0

  local remote_path_count
  remote_path_count="$(jq '(.paths // {}) | length' "$remote_spec_file" 2>/dev/null || echo 0)"
  [ "$remote_path_count" -eq 0 ] && return 0

  local remote_strategy
  remote_strategy="$(detect_path_strategy_from_openapi "$remote_spec_file")"
  [ -z "$remote_strategy" ] && return 0

  if [ "$PATH_STRATEGY" != "$remote_strategy" ]; then
    local remote_sample
    remote_sample="$(jq -r '(.paths // {}) | keys | .[0:3] | join(", ")' "$remote_spec_file" 2>/dev/null || true)"
    local local_sample
    local_sample="$(jq -r '(.paths // {}) | keys | .[0:3] | join(", ")' "$LOCAL_SPEC_JSON_FILE" 2>/dev/null || true)"

    echo "" >&2
    echo "[Alignment Check] Path strategy 不一致，上傳中止" >&2
    echo "  本地 path_strategy : $PATH_STRATEGY（例：$local_sample）" >&2
    echo "  Apidog 偵測 strategy: $remote_strategy（例：$remote_sample）" >&2
    echo "" >&2
    echo "  可能導致 endpoint 重複或錯位。" >&2
    echo "  請確認後以 --skip-alignment-check 繼續，或調整 path_strategy。" >&2
    fail "Path strategy 不一致"
    return 1
  fi

  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --history)
      HISTORY_FILE="$2"
      shift 2
      ;;
    --candidate-file)
      CANDIDATE_FILE="$2"
      shift 2
      ;;
    --path-strategy)
      PATH_STRATEGY="$2"
      shift 2
      ;;
    --review-file)
      REVIEW_FILE="$2"
      shift 2
      ;;
    --review-decision-file)
      REVIEW_DECISION_FILE="$2"
      shift 2
      ;;
    --remote-openapi)
      REMOTE_OPENAPI_FILE="$2"
      shift 2
      ;;
    --conflict-file)
      CONFLICT_FILE="$2"
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
    --conflict-count)
      CONFLICT_COUNT="$2"
      shift 2
      ;;
    --conflict)
      CONFLICT_STRATEGY="$2"
      shift 2
      ;;
    --skip-history)
      SKIP_HISTORY=true
      shift
      ;;
    --no-delta)
      NO_DELTA=true
      shift
      ;;
    --no-folder-aware)
      FOLDER_AWARE=false
      shift
      ;;
    --allow-root-folder-fallback)
      ALLOW_ROOT_FOLDER_FALLBACK=true
      shift
      ;;
    --apidog-tree-file)
      APIDOG_TREE_FILE="$2"
      shift 2
      ;;
    --apidog-tree-output)
      APIDOG_TREE_OUTPUT="$2"
      shift 2
      ;;
    --folder-mapping-file)
      FOLDER_MAPPING_FILE="$2"
      shift 2
      ;;
    --folder-decision-file)
      FOLDER_DECISION_FILE="$2"
      shift 2
      ;;
    --skip-alignment-check)
      SKIP_ALIGNMENT_CHECK=true
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
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$PATH_STRATEGY" ] && [ -n "$CANDIDATE_FILE" ] && [ -f "$CANDIDATE_FILE" ]; then
  PATH_STRATEGY="$(jq -r '.meta.path_strategy // ""' "$CANDIDATE_FILE" 2>/dev/null || true)"
fi

if [ -z "$PATH_STRATEGY" ] && [ -f "$OPENAPI_FILE" ]; then
  PATH_STRATEGY="$(detect_path_strategy_from_openapi "$OPENAPI_FILE")"
fi

guided_progress_set_enabled "$PROGRESS_ENABLED"
trap 'rm -f "$GUIDED_TIMING_FILE"' EXIT

guided_progress_emit "upload_apidog" "validate_input" "in_progress" 0 7 "starting apidog upload"
guided_timing_begin "upload_total"

if ! is_non_negative_int "$CONFLICT_COUNT"; then
  fail "--conflict-count 必須為非負整數"
fi

case "$CONFLICT_STRATEGY" in
  keep_remote|use_local|manual_merge)
    ;;
  *)
    fail "--conflict 必須為 keep_remote、use_local 或 manual_merge"
    ;;
esac

if [ -f .env.agents ]; then
  source .env.agents
fi

[ -n "${APIDOG_ACCESS_TOKEN:-}" ] || fail "找不到 APIDOG_ACCESS_TOKEN"
[ -n "${APIDOG_PROJECT_ID:-}" ] || fail "找不到 APIDOG_PROJECT_ID"

if [ ! -f "$OPENAPI_FILE" ] && [ "$OPENAPI_FILE" = "docs/api-docs/openapi.yaml" ] && [ -f "docs/openapi.yaml" ]; then
  OPENAPI_FILE="docs/openapi.yaml"
fi

[ -f "$OPENAPI_FILE" ] || fail "找不到 ${OPENAPI_FILE}，請先產出 OpenAPI 文件"

if [ -n "$CANDIDATE_FILE" ] && [ ! -f "$CANDIDATE_FILE" ]; then
  fail "找不到 --candidate-file 指定檔案：${CANDIDATE_FILE}"
fi

if [ -n "$APIDOG_TREE_FILE" ] && [ ! -f "$APIDOG_TREE_FILE" ]; then
  fail "找不到 --apidog-tree-file 指定檔案：${APIDOG_TREE_FILE}"
fi

if [ -n "$REVIEW_FILE" ]; then
  enforce_review_gate "$REVIEW_FILE" "$REVIEW_DECISION_FILE"
fi

if [ -z "$CONFLICT_FILE" ]; then
  ts="$(date -u +"%Y%m%dT%H%M%SZ")"
  CONFLICT_FILE="docs/api-docs/conflicts/${ts}.json"
fi

echo "正在上傳至 Apidog..." >&2
guided_progress_emit "upload_apidog" "validate_input" "in_progress" 1 7 "input validated"

LOCAL_SPEC_JSON_FILE="$(mktemp)"
REMOTE_SPEC_JSON_FILE="$(mktemp)"
UPLOAD_SPEC_JSON_FILE="$(mktemp)"
FOLDER_BATCHES_FILE="$(mktemp)"
TEMP_REQUEST="$(mktemp)"
TEMP_RESPONSE="$(mktemp)"
trap 'rm -f "$LOCAL_SPEC_JSON_FILE" "$REMOTE_SPEC_JSON_FILE" "$UPLOAD_SPEC_JSON_FILE" "$FOLDER_BATCHES_FILE" "$TEMP_REQUEST" "$TEMP_RESPONSE" "$GUIDED_TIMING_FILE"' EXIT

normalize_spec_to_json_file "$OPENAPI_FILE" "$LOCAL_SPEC_JSON_FILE"
cp "$LOCAL_SPEC_JSON_FILE" "$UPLOAD_SPEC_JSON_FILE"

if [ -n "$CANDIDATE_FILE" ]; then
  guided_timing_begin "fetch_remote_openapi"
  export_remote_openapi_json "$REMOTE_SPEC_JSON_FILE"
  guided_timing_end "upload-apidog" "fetch_remote_openapi" "candidate_file=$CANDIDATE_FILE"
  guided_progress_emit "upload_apidog" "fetch_remote_openapi" "in_progress" 2 7 "remote openapi fetched"

  check_path_strategy_alignment "$REMOTE_SPEC_JSON_FILE" \
    || fail "Path strategy 不一致，請確認後以 --skip-alignment-check 繼續"

  guided_timing_begin "detect_conflicts"
  detect_conflicts "$LOCAL_SPEC_JSON_FILE" "$REMOTE_SPEC_JSON_FILE" "$CANDIDATE_FILE" "$CONFLICT_FILE"
  guided_timing_end "upload-apidog" "detect_conflicts" "updated=$UPDATED_CANDIDATE_COUNT conflicts=$CONFLICT_COUNT"
  guided_progress_emit "upload_apidog" "detect_conflicts" "in_progress" 3 7 "conflicts evaluated"

  if [ "$CONFLICT_COUNT" -gt 0 ]; then
    case "$CONFLICT_STRATEGY" in
      manual_merge)
        fail "偵測到 ${CONFLICT_COUNT} 個衝突，已輸出 ${CONFLICT_FILE}，manual_merge 模式停止自動同步"
        ;;
      keep_remote)
        apply_keep_remote_strategy "$LOCAL_SPEC_JSON_FILE" "$REMOTE_SPEC_JSON_FILE" "$CONFLICT_FILE" "$UPLOAD_SPEC_JSON_FILE"
        ;;
      use_local)
        cp "$LOCAL_SPEC_JSON_FILE" "$UPLOAD_SPEC_JSON_FILE"
        ;;
    esac
  fi

  if [ "$NO_DELTA" = false ]; then
    if [ "$FOLDER_AWARE" = true ]; then
      ACTIVE_CANDIDATE_COUNT="$(active_candidates_json "$CANDIDATE_FILE" | jq 'length')"
      if [ "$ACTIVE_CANDIDATE_COUNT" -eq 0 ]; then
        DELTA_SPEC_FILE="$(mktemp)"
        build_delta_spec "$UPLOAD_SPEC_JSON_FILE" "$CANDIDATE_FILE" "$DELTA_SPEC_FILE"
        mv "$DELTA_SPEC_FILE" "$UPLOAD_SPEC_JSON_FILE"
        jq -n '[{folder_id: 0, candidates: null}]' >"$FOLDER_BATCHES_FILE"
      else
      ts="${ts:-$(date -u +"%Y%m%dT%H%M%SZ")}"

      if [ -z "$APIDOG_TREE_OUTPUT" ]; then
        APIDOG_TREE_OUTPUT="docs/api-docs/apidog-tree/${ts}.json"
      fi

      if [ -z "$FOLDER_MAPPING_FILE" ]; then
        FOLDER_MAPPING_FILE="docs/api-docs/apidog-tree/${ts}.mapping.json"
      fi

      if [ -z "$FOLDER_DECISION_FILE" ]; then
        FOLDER_DECISION_FILE="docs/api-docs/apidog-tree/${ts}.decisions.json"
      fi

      mkdir -p "$(dirname "$APIDOG_TREE_OUTPUT")" "$(dirname "$FOLDER_MAPPING_FILE")" "$(dirname "$FOLDER_DECISION_FILE")"

      if [ -n "$APIDOG_TREE_FILE" ]; then
        cp "$APIDOG_TREE_FILE" "$APIDOG_TREE_OUTPUT"
      elif ! fetch_apidog_tree "$APIDOG_TREE_OUTPUT"; then
        if [ "$ALLOW_ROOT_FOLDER_FALLBACK" = true ]; then
          echo "警告：無法取得 Apidog API tree，已因 --allow-root-folder-fallback 改用 root folder 0。" >&2
          jq -n '{exact: [], prefixes: []}' >"$FOLDER_MAPPING_FILE"
        else
          fail "無法取得 Apidog API tree；請補 candidate folder_id、提供 --apidog-tree-file，或明確加 --allow-root-folder-fallback"
        fi
      fi

      if [ ! -f "$FOLDER_MAPPING_FILE" ] || ! jq -e '.exact? and .prefixes?' "$FOLDER_MAPPING_FILE" >/dev/null 2>&1; then
        build_apidog_folder_mapping "$APIDOG_TREE_OUTPUT" "$FOLDER_MAPPING_FILE"
      fi

      resolve_candidate_folder_decisions "$CANDIDATE_FILE" "$FOLDER_MAPPING_FILE" "$ALLOW_ROOT_FOLDER_FALLBACK" "$FOLDER_DECISION_FILE"
      UNMAPPED_COUNT="$(jq '.unmapped | length' "$FOLDER_DECISION_FILE")"
      if [ "$UNMAPPED_COUNT" -gt 0 ]; then
        echo "無法 mapping folder 的 candidates：" >&2
        jq -r '.unmapped[] | "  - " + (.method | ascii_upcase) + " " + .path' "$FOLDER_DECISION_FILE" >&2
        fail "存在 ${UNMAPPED_COUNT} 個 unmapped candidates；請在 confirmed JSON 補 folder_id，或明確加 --allow-root-folder-fallback"
      fi

      jq '.groups' "$FOLDER_DECISION_FILE" >"$FOLDER_BATCHES_FILE"
      fi
    else
      DELTA_SPEC_FILE="$(mktemp)"
      if build_delta_spec "$UPLOAD_SPEC_JSON_FILE" "$CANDIDATE_FILE" "$DELTA_SPEC_FILE"; then
        mv "$DELTA_SPEC_FILE" "$UPLOAD_SPEC_JSON_FILE"
      else
        rm -f "$DELTA_SPEC_FILE"
        fail "Delta 過濾失敗：candidate paths 與 local spec 無匹配，上傳中止"
      fi
      jq -n '[{folder_id: 0, candidates: null}]' >"$FOLDER_BATCHES_FILE"
    fi
  else
    jq -n '[{folder_id: 0, candidates: null}]' >"$FOLDER_BATCHES_FILE"
  fi
else
  guided_progress_emit "upload_apidog" "fetch_remote_openapi" "in_progress" 2 7 "no candidate file, remote compare skipped"
  guided_progress_emit "upload_apidog" "detect_conflicts" "in_progress" 3 7 "conflict detection skipped"
  CONFLICT_COUNT=0
  jq -n '[{folder_id: 0, candidates: null}]' >"$FOLDER_BATCHES_FILE"
fi

API_URL="https://api.apidog.com/v1/projects/$APIDOG_PROJECT_ID/import-openapi?locale=en-US"
IMPORTED_COUNT=0
UPDATED_COUNT=0
SKIPPED_COUNT=0
BATCH_COUNT="$(jq 'length' "$FOLDER_BATCHES_FILE")"
[ "$BATCH_COUNT" -gt 0 ] || fail "沒有可上傳的 folder batch"

guided_timing_begin "build_request"
BATCH_INDEX=0
while IFS= read -r folder_batch; do
  [ -n "$folder_batch" ] || continue
  BATCH_INDEX=$((BATCH_INDEX + 1))

  TARGET_FOLDER_ID="$(echo "$folder_batch" | jq -r '.folder_id')"
  BATCH_CANDIDATES="$(echo "$folder_batch" | jq -c '.candidates')"
  BATCH_SPEC_FILE="$(mktemp)"

  if [ "$BATCH_CANDIDATES" = "null" ]; then
    cp "$UPLOAD_SPEC_JSON_FILE" "$BATCH_SPEC_FILE"
    UPDATE_FOLDER_OF_CHANGED_ENDPOINT=false
  else
    if ! build_subset_spec_from_candidates_json "$UPLOAD_SPEC_JSON_FILE" "$BATCH_CANDIDATES" "$BATCH_SPEC_FILE"; then
      rm -f "$BATCH_SPEC_FILE"
      fail "Folder batch ${TARGET_FOLDER_ID} 的 delta payload 產生失敗"
    fi
    UPDATE_FOLDER_OF_CHANGED_ENDPOINT=true
  fi

  OPENAPI_SPEC="$(jq -c . "$BATCH_SPEC_FILE")"
  jq -n \
    --argjson spec "$OPENAPI_SPEC" \
    --argjson target_folder_id "$TARGET_FOLDER_ID" \
    --argjson update_folder "$UPDATE_FOLDER_OF_CHANGED_ENDPOINT" \
    '{
      input: ($spec | tostring),
      options: {
        targetEndpointFolderId: $target_folder_id,
        targetSchemaFolderId: 0,
        endpointOverwriteBehavior: "OVERWRITE_EXISTING",
        schemaOverwriteBehavior: "OVERWRITE_EXISTING",
        updateFolderOfChangedEndpoint: $update_folder,
        prependBasePath: false
      }
    }' >"$TEMP_REQUEST"

  if [ "$BATCH_INDEX" -eq 1 ]; then
    guided_timing_end "upload-apidog" "build_request" "openapi=$OPENAPI_FILE strategy=$CONFLICT_STRATEGY batches=$BATCH_COUNT"
    guided_progress_emit "upload_apidog" "build_request" "in_progress" 4 7 "request payload ready"
    guided_timing_begin "upload_request"
  fi

  echo "上傳 folder batch ${BATCH_INDEX}/${BATCH_COUNT}（targetEndpointFolderId=${TARGET_FOLDER_ID}）..." >&2
  HTTP_CODE="$(curl -s -w "%{http_code}" -o "$TEMP_RESPONSE" \
    -X POST "$API_URL" \
    -H "Authorization: Bearer $APIDOG_ACCESS_TOKEN" \
    -H "X-Apidog-Api-Version: 2024-03-28" \
    -H "Content-Type: application/json" \
    -d @"$TEMP_REQUEST")"

  rm -f "$BATCH_SPEC_FILE"

  if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
    echo "回應內容：" >&2
    cat "$TEMP_RESPONSE" >&2
    fail "無法上傳至 Apidog (HTTP ${HTTP_CODE})"
  fi

  RESPONSE="$(cat "$TEMP_RESPONSE")"
  BATCH_IMPORTED_COUNT="$(echo "$RESPONSE" | jq -r '.data.counters.endpointCreated // .data.imported // .data.created // .imported // 0')"
  BATCH_UPDATED_COUNT="$(echo "$RESPONSE" | jq -r '.data.counters.endpointUpdated // .data.updated // .data.modified // .updated // .modified // 0')"
  BATCH_SKIPPED_COUNT="$(echo "$RESPONSE" | jq -r '.data.counters.endpointIgnored // .data.skipped // .skipped // 0')"

  IMPORTED_COUNT=$((IMPORTED_COUNT + $(to_int_or_zero "$BATCH_IMPORTED_COUNT")))
  UPDATED_COUNT=$((UPDATED_COUNT + $(to_int_or_zero "$BATCH_UPDATED_COUNT")))
  SKIPPED_COUNT=$((SKIPPED_COUNT + $(to_int_or_zero "$BATCH_SKIPPED_COUNT")))
done < <(jq -cr '.[]' "$FOLDER_BATCHES_FILE")

guided_timing_end "upload-apidog" "upload_request" "batches=$BATCH_COUNT"

SYNCED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
[ -n "$TO_TIME" ] || TO_TIME="$SYNCED_AT"
guided_progress_emit "upload_apidog" "upload_request" "in_progress" 5 7 "upload finished"

guided_timing_begin "verify_remote_upload"
export_remote_openapi_json "$REMOTE_SPEC_JSON_FILE"
if ! verify_remote_upload_result "$REMOTE_SPEC_JSON_FILE" "$CANDIDATE_FILE"; then
  guided_timing_end "upload-apidog" "verify_remote_upload" "missing=$VERIFY_MISSING_COUNT"
  fail "Apidog 匯入後驗證失敗：遠端仍缺少 ${VERIFY_MISSING_COUNT} 個 endpoint${VERIFY_MISSING_SAMPLE:+，例如：${VERIFY_MISSING_SAMPLE}}"
fi
guided_timing_end "upload-apidog" "verify_remote_upload" "missing=0"
guided_progress_emit "upload_apidog" "verify_remote_upload" "in_progress" 6 7 "remote export verified"

if [ "$SKIP_HISTORY" = false ]; then
  guided_timing_begin "append_history"
  if ! "$SCRIPT_DIR/append-sync-history.sh" \
    --history "$HISTORY_FILE" \
    --openapi "$OPENAPI_FILE" \
    --synced-at "$SYNCED_AT" \
    --from-time "$FROM_TIME" \
    --to-time "$TO_TIME" \
    --path-strategy "$PATH_STRATEGY" \
    --status "success" \
    --apidog-project-id "$APIDOG_PROJECT_ID" \
    --imported-count "$IMPORTED_COUNT" \
    --updated-count "$UPDATED_COUNT" \
    --skipped-count "$SKIPPED_COUNT" \
    --conflict-count "$CONFLICT_COUNT" >/dev/null; then
    fail "Apidog 已同步成功，但寫入 history 失敗"
  fi
  guided_timing_end "upload-apidog" "append_history" "history=$HISTORY_FILE"
  guided_progress_emit "upload_apidog" "append_history" "in_progress" 7 7 "history appended"
else
  guided_progress_emit "upload_apidog" "append_history" "in_progress" 7 7 "history skipped"
fi

guided_timing_end "upload-apidog" "upload_total" "imported=$IMPORTED_COUNT updated=$UPDATED_COUNT skipped=$SKIPPED_COUNT conflicts=$CONFLICT_COUNT"
TIMINGS_JSON="$(guided_timing_json)"
guided_progress_emit "upload_apidog" "complete" "done" 7 7 "apidog upload complete"
echo "上傳完成" >&2
echo "  新增：$IMPORTED_COUNT 個 endpoint" >&2
echo "  更新：$UPDATED_COUNT 個 endpoint" >&2
echo "  略過：$SKIPPED_COUNT 個 endpoint（已存在於 Apidog）" >&2
echo "  衝突：$CONFLICT_COUNT 個 endpoint" >&2
if [ "$CONFLICT_COUNT" -gt 0 ]; then
echo "  衝突檔案：${CONFLICT_FILE}" >&2
fi

jq -n \
  --arg openapi_file "$OPENAPI_FILE" \
  --arg history_file "$HISTORY_FILE" \
  --arg candidate_file "$CANDIDATE_FILE" \
  --arg review_file "$REVIEW_FILE" \
  --arg review_decision_file "$REVIEW_DECISION_FILE" \
  --arg apidog_tree_file "$APIDOG_TREE_OUTPUT" \
  --arg folder_mapping_file "$FOLDER_MAPPING_FILE" \
  --arg folder_decision_file "$FOLDER_DECISION_FILE" \
  --arg conflict_file "$(if [ "$CONFLICT_COUNT" -gt 0 ]; then echo "$CONFLICT_FILE"; fi)" \
  --arg conflict_strategy "$CONFLICT_STRATEGY" \
  --argjson imported_count "$IMPORTED_COUNT" \
  --argjson updated_count "$UPDATED_COUNT" \
  --argjson skipped_count "$SKIPPED_COUNT" \
  --argjson conflict_count "$CONFLICT_COUNT" \
  --arg synced_at "$SYNCED_AT" \
  --argjson timings "$TIMINGS_JSON" \
  --arg message "已同步至 Apidog" \
  '{
    openapi_file: $openapi_file,
    history_file: $history_file,
    candidate_file: (if $candidate_file == "" then null else $candidate_file end),
    review_file: (if $review_file == "" then null else $review_file end),
    review_decision_file: (if $review_decision_file == "" then null else $review_decision_file end),
    apidog_tree_file: (if $apidog_tree_file == "" then null else $apidog_tree_file end),
    folder_mapping_file: (if $folder_mapping_file == "" then null else $folder_mapping_file end),
    folder_decision_file: (if $folder_decision_file == "" then null else $folder_decision_file end),
    conflict_file: (if $conflict_file == "" then null else $conflict_file end),
    conflict_strategy: $conflict_strategy,
    imported_count: $imported_count,
    updated_count: $updated_count,
    skipped_count: $skipped_count,
    conflict_count: $conflict_count,
    synced_at: $synced_at,
    timings: $timings,
    message: $message
  }'
