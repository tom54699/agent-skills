#!/usr/bin/env bash
# deploy.sh — docker-server-deploy template v1
#
# 位置：<DEPLOY_ROOT>/releases/<tag>/deploy.sh（CI 每次部署都同步到新的 release 目錄）
#
# 用法：
#   deploy.sh [<tag>]     部署指定的 release（預設 tag = 這個腳本所在的目錄名稱，例如 sha-<commit>）
#   deploy.sh rollback    把 current 切回 previous；不跑 migration，資料庫不會回滾
#
# Exit code：
#   0   成功
#   1   失敗：沒有做任何變更，或已經自動回滾到上一版
#   2   回滾也失敗，需要人工處理
#   75  另一個部署正在執行，等待逾時
#
# 目錄結構：
#   <DEPLOY_ROOT>/releases/<tag>/   每次部署的設定（compose、這個腳本）
#   <DEPLOY_ROOT>/current           指向目前執行中的 release
#   <DEPLOY_ROOT>/previous          指向上一個成功的 release
#   <DEPLOY_ROOT>/shared/.env       只放在 server 上的設定（權限 600，不進 git）
#   <DEPLOY_ROOT>/shared/logs/      部署 log
#
# 相容 bash 3.2（macOS 內建版本），方便在本機測試。
set -euo pipefail

# ---- 專案設定：建立部署時依專案修改，也可以用環境變數覆寫 ----
# CI 建置、使用 RELEASE_TAG 的服務；health check 只檢查這些服務
APP_SERVICES="${APP_SERVICES:-api web}"
# 一次性 migration 服務（compose 裡放在 jobs profile）；專案沒有 migration 就設成空字串
MIGRATE_SERVICE="${MIGRATE_SERVICE-migrate}"

# ---- 一般設定 ----
KEEP_RELEASES="${KEEP_RELEASES:-5}"     # 保留最近幾次部署嘗試的 release 目錄
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}" # 秒
HEALTH_INTERVAL="${HEALTH_INTERVAL:-2}" # 秒
LOCK_WAIT="${LOCK_WAIT:-600}"           # 秒
KEEP_LOGS="${KEEP_LOGS:-50}"            # 保留最近幾份部署 log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEPLOY_ROOT="${DEPLOY_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd -P)}"
RELEASES_DIR="$DEPLOY_ROOT/releases"
SHARED_DIR="$DEPLOY_ROOT/shared"
ENV_FILE="${ENV_FILE:-$SHARED_DIR/.env}"
LOCK_DIR="$DEPLOY_ROOT/.deploy.lock"
HISTORY_FILE="$DEPLOY_ROOT/.release-history"

log() { printf '[deploy %s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "$*"; exit 1; }

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

setup_logging() {
  mkdir -p "$SHARED_DIR/logs"
  local log_file
  { ls -1t "$SHARED_DIR"/logs/deploy-*.log 2>/dev/null || true; } | tail -n +"$KEEP_LOGS" | while read -r old; do
    rm -f "$old"
  done
  log_file="$SHARED_DIR/logs/deploy-$(date '+%Y%m%d-%H%M%S')-$$.log"
  exec > >(tee -a "$log_file") 2>&1
}

# ---- 部署鎖：mkdir 是原子操作；持有者的 pid 不存在時視為殘留鎖 ----
release_lock() { rm -rf "$LOCK_DIR"; }

acquire_lock() {
  local waited=0 holder
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    holder="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      log "移除殘留的部署鎖（pid $holder 已經不存在）"
      rm -rf "$LOCK_DIR"
      continue
    fi
    if [ "$waited" -ge "$LOCK_WAIT" ]; then
      log "另一個部署正在執行（pid ${holder:-unknown}），等待 ${LOCK_WAIT} 秒後放棄，沒有做任何變更"
      exit 75
    fi
    sleep 1
    waited=$((waited + 1))
  done
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  date '+%Y-%m-%dT%H:%M:%S' > "$LOCK_DIR/started_at"
  trap release_lock EXIT
}

# ---- 小工具 ----
check_tag() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) die "release tag 不合法：'$1'" ;;
  esac
}

compose() { # compose <tag> <docker compose 參數...>
  local tag="$1"
  shift
  RELEASE_TAG="$tag" docker compose -f "$RELEASES_DIR/$tag/docker-compose.yml" --env-file "$ENV_FILE" "$@"
}

link_tag() { # link_tag current|previous → 印出 tag，沒有連結時印空字串
  if [ -L "$DEPLOY_ROOT/$1" ]; then
    basename "$(readlink "$DEPLOY_ROOT/$1")"
  fi
}

set_link() { # set_link current|previous <tag>
  ln -sfn "releases/$2" "$DEPLOY_ROOT/$1"
}

env_value() { # 從 .env 讀單一個值，不 source 整個檔案
  sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

check_env() {
  [ -f "$ENV_FILE" ] || die "找不到 $ENV_FILE，請先在 server 上建立（權限 600）。沒有做任何變更"
}

show_logs() {
  compose "$1" logs --tail 80 || true
}

# ---- 啟動與驗證 ----
start_release() {
  compose "$1" up -d --remove-orphans
}

service_ok() { # service_ok <tag> <service>
  local tag="$1" svc="$2" cid state image
  cid="$(compose "$tag" ps -q "$svc" 2>/dev/null | head -n 1)"
  [ -n "$cid" ] || return 1
  state="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
  case "$state" in
    healthy|running) ;;
    *) return 1 ;;
  esac
  image="$(docker inspect -f '{{.Config.Image}}' "$cid" 2>/dev/null || true)"
  case "$image" in
    *":$tag") return 0 ;;
    *) return 1 ;;
  esac
}

wait_healthy() { # wait_healthy <tag>
  local tag="$1" url deadline all_ok svc
  url="${HEALTH_URL:-$(env_value HEALTH_URL)}"
  deadline=$((SECONDS + HEALTH_TIMEOUT))
  while :; do
    all_ok=1
    for svc in $APP_SERVICES; do
      if ! service_ok "$tag" "$svc"; then
        all_ok=0
        break
      fi
    done
    if [ "$all_ok" -eq 1 ] && [ -n "$url" ]; then
      curl -fsS --max-time 10 -o /dev/null "$url" || all_ok=0
    fi
    if [ "$all_ok" -eq 1 ]; then
      log "health check 通過：$tag"
      return 0
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      log "health check 逾時（${HEALTH_TIMEOUT} 秒）：$tag"
      return 1
    fi
    sleep "$HEALTH_INTERVAL"
  done
}

# ---- 清理：只清理曾經嘗試部署過的 release，剛同步上來還沒部署的目錄不會被刪 ----
prune_releases() {
  local cur prev keep dir tag img
  cur="$(link_tag current)"
  prev="$(link_tag previous)"
  keep="$(tail -n "$KEEP_RELEASES" "$HISTORY_FILE" 2>/dev/null || true)"
  for dir in "$RELEASES_DIR"/*/; do
    [ -d "$dir" ] || continue
    tag="$(basename "$dir")"
    if [ "$tag" = "$cur" ] || [ "$tag" = "$prev" ]; then
      continue
    fi
    if printf '%s\n' "$keep" | grep -qxF "$tag"; then
      continue
    fi
    if ! grep -qxF "$tag" "$HISTORY_FILE" 2>/dev/null; then
      continue
    fi
    { compose "$tag" config --images 2>/dev/null || true; } | while read -r img; do
      case "$img" in
        *":$tag") docker image rm "$img" >/dev/null 2>&1 || log "警告：無法移除 image $img" ;;
      esac
    done
    rm -rf "$dir"
    log "已清理舊 release：$tag"
  done
}

# ---- 指令 ----
cmd_deploy() {
  local tag="$1" old
  check_tag "$tag"
  [ -f "$RELEASES_DIR/$tag/docker-compose.yml" ] || die "找不到 $RELEASES_DIR/$tag/docker-compose.yml"
  acquire_lock
  check_env
  printf '%s\n' "$tag" >> "$HISTORY_FILE"
  log "開始部署：$tag"

  compose "$tag" config --quiet || die "compose 設定無效，沒有做任何變更"
  compose "$tag" pull || die "pull 失敗，沒有做任何變更"

  if [ -n "$MIGRATE_SERVICE" ]; then
    if ! compose "$tag" --profile jobs config --services | grep -qxF "$MIGRATE_SERVICE"; then
      die "compose 裡沒有 migration 服務 '$MIGRATE_SERVICE'；專案沒有 migration 的話，把 MIGRATE_SERVICE 設成空字串"
    fi
    log "執行 migration：$MIGRATE_SERVICE"
    compose "$tag" --profile jobs run --rm "$MIGRATE_SERVICE" \
      || die "migration 失敗，服務沒有變更；資料庫可能已經部分 migrate，請檢查"
  fi

  old="$(link_tag current)"
  set_link current "$tag"
  if start_release "$tag" && wait_healthy "$tag"; then
    if [ -n "$old" ] && [ "$old" != "$tag" ]; then
      set_link previous "$old"
    fi
    prune_releases
    log "部署成功：$tag"
    return 0
  fi

  log "新版本啟動或 health check 失敗：$tag"
  show_logs "$tag"
  if [ -z "$old" ] || [ "$old" = "$tag" ]; then
    log "沒有可以回滾的上一版"
    exit 1
  fi

  log "自動回滾到 $old（只切換 image 與設定，資料庫不會回滾）"
  set_link current "$old"
  if start_release "$old" && wait_healthy "$old"; then
    log "已回滾到 $old，這次部署失敗"
    exit 1
  fi
  show_logs "$old"
  log "回滾到 $old 也失敗，需要人工處理"
  exit 2
}

cmd_rollback() {
  local cur prev
  acquire_lock
  check_env
  cur="$(link_tag current)"
  prev="$(link_tag previous)"
  if [ -z "$prev" ] || [ ! -f "$RELEASES_DIR/$prev/docker-compose.yml" ]; then
    die "沒有可以回滾的上一版"
  fi
  log "手動回滾：${cur:-（無）} → $prev（不跑 migration，資料庫不會回滾）"
  set_link current "$prev"
  if [ -n "$cur" ]; then
    set_link previous "$cur"
  fi
  if start_release "$prev" && wait_healthy "$prev"; then
    log "已回滾到 $prev"
    return 0
  fi
  show_logs "$prev"
  log "回滾後 health check 失敗，需要人工處理"
  exit 2
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac
  setup_logging
  case "${1:-}" in
    rollback) cmd_rollback ;;
    '') cmd_deploy "$(basename "$SCRIPT_DIR")" ;;
    *) cmd_deploy "$1" ;;
  esac
}

main "$@"
