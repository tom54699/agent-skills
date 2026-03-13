#!/bin/bash
set -euo pipefail

# guided-sync 的統一前置檢查入口
# 成功時輸出 JSON，失敗時輸出錯誤到 stderr 並以非零退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

PROJECT_ROOT="$(pwd)"
ENV_FILE=".env.agents"
GITIGNORE_FILE=".gitignore"
PROGRESS_ENABLED=1
PRECHECK_TOTAL=12
PRECHECK_DONE=0
GUIDED_TIMING_FILE="$(mktemp)"

REQUIRED_DIRS=(
  "docs/api-docs"
  "docs/api-docs/history"
  "docs/api-docs/candidates"
  "docs/api-docs/conflicts"
  "docs/api-docs/reviews"
  "docs/api-docs/redoc"
)

fail() {
  echo "錯誤：$*" >&2
  exit 1
}

complete_check() {
  PRECHECK_DONE=$((PRECHECK_DONE + 1))
  guided_progress_emit "preflight" "checks" "in_progress" "$PRECHECK_DONE" "$PRECHECK_TOTAL" "$1"
}

check_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

check_php_n() {
  php -n -r 'echo 1;' >/dev/null 2>&1
}

check_route_list_json() {
  local tmp_file
  tmp_file="$(mktemp)"
  if ! php -n artisan route:list --json >"$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    return 1
  fi

  if ! jq -e . "$tmp_file" >/dev/null 2>&1; then
    rm -f "$tmp_file"
    return 1
  fi

  rm -f "$tmp_file"
  return 0
}

has_env_key() {
  local key="$1"
  local file="$2"
  [ -f "$file" ] || return 1
  grep -Eq "^[[:space:]]*(export[[:space:]]+)?${key}=" "$file"
}

check_gitignore_rule() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -Eq '(^|[[:space:]])\.env\.agents($|[[:space:]])' "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-progress)
      PROGRESS_ENABLED=0
      shift
      ;;
    -h|--help)
      echo "Usage: preflight.sh [--no-progress]" >&2
      exit 0
      ;;
    *)
      fail "未知參數：$1"
      ;;
  esac
done

guided_progress_set_enabled "$PROGRESS_ENABLED"
trap 'rm -f "$GUIDED_TIMING_FILE"' EXIT

guided_progress_emit "preflight" "checks" "in_progress" 0 "$PRECHECK_TOTAL" "starting preflight"
guided_timing_begin "preflight_total"

if [ ! -f "artisan" ]; then
  fail "此目錄不是 Laravel 專案，缺少 artisan"
fi
complete_check "artisan ready"

if [ ! -d "routes" ]; then
  fail "此目錄不是 Laravel 專案，缺少 routes/"
fi
complete_check "routes directory ready"

if [ ! -f "$ENV_FILE" ]; then
  fail "缺少 $ENV_FILE"
fi
complete_check ".env.agents found"

if ! has_env_key "APIDOG_ACCESS_TOKEN" "$ENV_FILE"; then
  fail "$ENV_FILE 缺少 APIDOG_ACCESS_TOKEN"
fi
complete_check "APIDOG_ACCESS_TOKEN found"

if ! has_env_key "APIDOG_PROJECT_ID" "$ENV_FILE"; then
  fail "$ENV_FILE 缺少 APIDOG_PROJECT_ID"
fi
complete_check "APIDOG_PROJECT_ID found"

if ! check_gitignore_rule "$GITIGNORE_FILE"; then
  fail "$GITIGNORE_FILE 缺少 .env.agents 規則"
fi
complete_check ".gitignore rule ready"

if ! check_command "jq"; then
  fail "找不到 jq"
fi
complete_check "jq available"

if ! check_command "yq"; then
  fail "找不到 yq"
fi
complete_check "yq available"

if ! check_command "php"; then
  fail "找不到 php；guided-sync 目前需要 PHP analyzer / generator"
fi
complete_check "php available"

if ! check_php_n; then
  fail "php -n 無法執行；guided-sync 需要 clean PHP runtime"
fi
complete_check "php -n available"

if ! check_route_list_json; then
  fail "php -n artisan route:list --json 執行失敗或輸出非合法 JSON"
fi
complete_check "route:list json ready"

CREATED_DIRS_JSON='[]'
for dir_path in "${REQUIRED_DIRS[@]}"; do
  mkdir -p "$dir_path"
  CREATED_DIRS_JSON="$(echo "$CREATED_DIRS_JSON" | jq --arg dir "$dir_path" '. + [$dir]')"
done
complete_check "required directories prepared"

guided_timing_end "preflight" "preflight_total" "checks=$PRECHECK_TOTAL"
TIMINGS_JSON="$(guided_timing_json)"
guided_progress_emit "preflight" "checks" "done" "$PRECHECK_TOTAL" "$PRECHECK_TOTAL" "preflight complete"

jq -n \
  --arg project_root "$PROJECT_ROOT" \
  --arg env_file "$ENV_FILE" \
  --arg gitignore_file "$GITIGNORE_FILE" \
  --argjson created_dirs "$CREATED_DIRS_JSON" \
  --argjson timings "$TIMINGS_JSON" \
  '{
    project_root: $project_root,
    env_file: $env_file,
    gitignore_file: $gitignore_file,
    checks: {
      artisan: true,
      routes_dir: true,
      env_agents: true,
      apidog_access_token: true,
      apidog_project_id: true,
      gitignore_env_agents: true,
      jq: true,
      yq: true,
      php: true,
      php_n: true,
      route_list_json: true
    },
    created_dirs: $created_dirs,
    timings: $timings,
    ready: true
  }'
