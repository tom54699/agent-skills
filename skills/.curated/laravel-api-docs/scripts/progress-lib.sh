#!/bin/bash

# guided-sync 共用進度與耗時輸出
# - 所有訊息都走 stderr，避免污染既有 JSON stdout 契約
# - checklist 依 guided-sync 固定步驟順序無狀態推導

GUIDED_PROGRESS_ENABLED="${GUIDED_PROGRESS_ENABLED:-1}"
GUIDED_TIMING_FILE="${GUIDED_TIMING_FILE:-}"

guided_progress_set_enabled() {
  local enabled="${1:-1}"
  GUIDED_PROGRESS_ENABLED="$enabled"
}

guided_progress_is_enabled() {
  [ "${GUIDED_PROGRESS_ENABLED:-1}" = "1" ]
}

guided_progress_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

guided_progress_now_ms() {
  perl -MTime::HiRes=time -e 'printf("%.0f\n", time()*1000)'
}

guided_progress_step_order() {
  case "$1" in
    preflight) echo 1 ;;
    infer_candidates) echo 2 ;;
    confirm_candidate_list) echo 3 ;;
    update_openapi) echo 4 ;;
    upload_apidog) echo 5 ;;
    generate_html) echo 6 ;;
    *) echo 999 ;;
  esac
}

guided_progress_step_label() {
  case "$1" in
    preflight) echo "Preflight" ;;
    infer_candidates) echo "Infer Candidates" ;;
    confirm_candidate_list) echo "Confirm Candidate List" ;;
    update_openapi) echo "Update OpenAPI" ;;
    upload_apidog) echo "Upload Apidog" ;;
    generate_html) echo "Generate HTML" ;;
    *) echo "$1" ;;
  esac
}

guided_progress_percent() {
  local current="${1:-0}"
  local total="${2:-0}"

  if [ "$total" -le 0 ]; then
    echo 0
    return 0
  fi

  if [ "$current" -lt 0 ]; then
    current=0
  fi
  if [ "$current" -gt "$total" ]; then
    current="$total"
  fi

  echo $(( current * 100 / total ))
}

guided_progress_bar() {
  local percent="${1:-0}"
  local width="${2:-18}"
  local filled=0
  local empty=0
  local bar=""

  if [ "$percent" -lt 0 ]; then
    percent=0
  fi
  if [ "$percent" -gt 100 ]; then
    percent=100
  fi

  filled=$(( percent * width / 100 ))
  empty=$(( width - filled ))

  while [ "$filled" -gt 0 ]; do
    bar="${bar}#"
    filled=$((filled - 1))
  done
  while [ "$empty" -gt 0 ]; do
    bar="${bar}-"
    empty=$((empty - 1))
  done

  printf '[%s]' "$bar"
}

guided_progress_render_checklist() {
  local current_step="$1"
  local current_status="$2"
  local current_percent="${3:-0}"
  local current_message="${4:-}"
  local current_order=0
  local step=""
  local step_order=0
  local marker=" "
  local percent=0
  local detail=""
  local bar=""

  guided_progress_is_enabled || return 0

  current_order="$(guided_progress_step_order "$current_step")"
  echo "[guided-progress] workflow=guided-sync" >&2

  for step in preflight infer_candidates confirm_candidate_list update_openapi upload_apidog generate_html; do
    step_order="$(guided_progress_step_order "$step")"
    if [ "$step_order" -lt "$current_order" ]; then
      marker="x"
      percent=100
      detail=""
    elif [ "$step_order" -eq "$current_order" ]; then
      if [ "$current_status" = "done" ]; then
        marker="x"
        percent=100
      else
        marker="~"
        percent="$current_percent"
      fi
      detail="$current_message"
    else
      marker=" "
      percent=0
      detail=""
    fi

    bar="$(guided_progress_bar "$percent" 16)"
    if [ -n "$detail" ] && [ "$step_order" -eq "$current_order" ]; then
      echo "[$marker] $(guided_progress_step_label "$step") $bar ${percent}% ${detail}" >&2
    else
      echo "[$marker] $(guided_progress_step_label "$step") $bar ${percent}%" >&2
    fi
  done
}

guided_progress_emit() {
  local step="$1"
  local stage="$2"
  local status="$3"
  local current="${4:-0}"
  local total="${5:-0}"
  local message="${6:-}"
  local percent=0

  guided_progress_is_enabled || return 0

  if [ "$status" = "done" ]; then
    percent=100
  else
    percent="$(guided_progress_percent "$current" "$total")"
  fi

  echo "[guided-progress] step=$step stage=$stage status=$status percent=$percent current=$current total=$total message=\"$(guided_progress_escape "$message")\"" >&2
  guided_progress_render_checklist "$step" "$status" "$percent" "$message"
}

guided_timing_begin() {
  local stage="$1"
  local var_name="GUIDED_TIMER_${stage//[^A-Za-z0-9_]/_}"
  printf -v "$var_name" '%s' "$(guided_progress_now_ms)"
}

guided_timing_end() {
  local script_name="$1"
  local stage="$2"
  local detail="${3:-}"
  local var_name="GUIDED_TIMER_${stage//[^A-Za-z0-9_]/_}"
  local start_ms="${!var_name:-}"
  local end_ms=0
  local duration_ms=0

  [ -n "$start_ms" ] || return 0

  end_ms="$(guided_progress_now_ms)"
  duration_ms=$(( end_ms - start_ms ))

  if [ -n "${GUIDED_TIMING_FILE:-}" ]; then
    printf '%s\t%s\t%s\n' "$stage" "$duration_ms" "$detail" >> "$GUIDED_TIMING_FILE"
  fi

  echo "[guided-timing] script=$script_name stage=$stage duration_ms=$duration_ms detail=\"$(guided_progress_escape "$detail")\"" >&2
}

guided_timing_record() {
  local script_name="$1"
  local stage="$2"
  local duration_ms="${3:-0}"
  local detail="${4:-}"

  if [ -n "${GUIDED_TIMING_FILE:-}" ]; then
    printf '%s\t%s\t%s\n' "$stage" "$duration_ms" "$detail" >> "$GUIDED_TIMING_FILE"
  fi

  echo "[guided-timing] script=$script_name stage=$stage duration_ms=$duration_ms detail=\"$(guided_progress_escape "$detail")\"" >&2
}

guided_timing_json() {
  if [ -z "${GUIDED_TIMING_FILE:-}" ] || [ ! -f "$GUIDED_TIMING_FILE" ] || [ ! -s "$GUIDED_TIMING_FILE" ]; then
    echo '{}'
    return 0
  fi

  jq -Rn '
    reduce inputs as $line ({};
      ($line | split("\t")) as $parts
      | . + {
          ($parts[0]): {
            duration_ms: (($parts[1] // "0") | tonumber),
            detail: ($parts[2] // "")
          }
        }
    )
  ' < "$GUIDED_TIMING_FILE"
}
