#!/usr/bin/env bash
# docker-server-deploy：deploy.sh 範本的模擬測試（A）
#
# 用假的 docker / curl（放在 PATH 最前面）模擬各種結果，不需要 Docker。
# 執行：bash tests/docker-server-deploy/run-tests.sh
#
# 假指令的行為由環境變數控制：
#   FAKE_PULL_FAIL_TAG      pull 這個 tag 時失敗
#   FAKE_MIGRATE_FAIL_TAG   這個 tag 的 migration 失敗
#   FAKE_UNHEALTHY_TAGS     執行中的 tag 在清單裡時，container 回報 unhealthy（空白分隔）
#   FAKE_WRONG_IMAGE_TAG    執行中的 tag 是這個時，container 回報舊的 image
#   FAKE_CURL_FAIL_TAG      執行中的 tag 是這個時，外部 health URL 失敗

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMPLATE="${DEPLOY_TEMPLATE:-$REPO_ROOT/skills/docker-server-deploy/assets/templates/deploy.sh}"

WORK="$(mktemp -d)"
STUB_DIR="$WORK/bin"
ROOT="$WORK/srv/app"
export FAKE_STATE_DIR="$WORK/state"
HOLDER_PID=""

cleanup() {
  if [ -n "$HOLDER_PID" ]; then kill "$HOLDER_PID" 2>/dev/null || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$STUB_DIR" "$ROOT/releases" "$ROOT/shared" "$FAKE_STATE_DIR"
printf 'APP_ENV=test\n' > "$ROOT/shared/.env"

# ---- 假的 docker ----
cat > "$STUB_DIR/docker" <<'STUB'
#!/usr/bin/env bash
state="$FAKE_STATE_DIR"
printf '%s | RELEASE_TAG=%s\n' "docker $*" "${RELEASE_TAG:-}" >> "$state/calls.log"
running="$(cat "$state/running" 2>/dev/null || true)"
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

if [ "$1" = "compose" ]; then
  shift
  profile=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--env-file) shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      *) break ;;
    esac
  done
  sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    config)
      case "${1:-}" in
        --services) printf 'api\nweb\n'; [ "$profile" = "jobs" ] && printf 'migrate\n' ;;
        --images) printf 'example/app-api:%s\nexample/app-web:%s\npostgres:17\n' "$RELEASE_TAG" "$RELEASE_TAG" ;;
      esac
      exit 0 ;;
    pull)
      if [ "${FAKE_PULL_FAIL_TAG:-}" = "$RELEASE_TAG" ]; then echo "fake: pull failed" >&2; exit 1; fi
      echo "$RELEASE_TAG" >> "$state/pulled"; exit 0 ;;
    run)
      if [ "${FAKE_MIGRATE_FAIL_TAG:-}" = "$RELEASE_TAG" ]; then echo "fake: migration failed" >&2; exit 1; fi
      echo "$RELEASE_TAG" >> "$state/migrated"; exit 0 ;;
    up)
      echo "$RELEASE_TAG" > "$state/running"
      echo "$RELEASE_TAG" >> "$state/started"; exit 0 ;;
    ps)
      for last in "$@"; do :; done
      echo "cid-$last"; exit 0 ;;
    logs) echo "fake: logs for $RELEASE_TAG"; exit 0 ;;
  esac
  exit 0
fi

if [ "$1" = "inspect" ]; then
  fmt="$3"
  cid="$4"
  svc="${cid#cid-}"
  case "$fmt" in
    *Health*)
      if in_list "$running" "${FAKE_UNHEALTHY_TAGS:-}"; then echo "unhealthy"; else echo "healthy"; fi ;;
    *Config.Image*)
      if [ "${FAKE_WRONG_IMAGE_TAG:-}" = "$running" ]; then echo "example/app-$svc:stale"; else echo "example/app-$svc:$running"; fi ;;
  esac
  exit 0
fi

if [ "$1" = "image" ]; then
  echo "$*" >> "$state/image-rm"; exit 0
fi
exit 0
STUB

# ---- 假的 curl ----
cat > "$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
running="$(cat "$FAKE_STATE_DIR/running" 2>/dev/null || true)"
echo "curl $*" >> "$FAKE_STATE_DIR/curl.log"
if [ -n "${FAKE_CURL_FAIL_TAG:-}" ] && [ "$FAKE_CURL_FAIL_TAG" = "$running" ]; then exit 22; fi
exit 0
STUB
chmod +x "$STUB_DIR/docker" "$STUB_DIR/curl"

# ---- 測試工具 ----
PASS=0
FAIL=0
LOG="$WORK/last.log"

new_release() {
  mkdir -p "$ROOT/releases/$1"
  cp "$TEMPLATE" "$ROOT/releases/$1/deploy.sh"
  printf 'name: app\n' > "$ROOT/releases/$1/docker-compose.yml"
}

run_script() { # run_script <script path> [args...]；印出 exit code，輸出寫到 $LOG
  local script="$1"
  shift
  PATH="$STUB_DIR:$PATH" HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-2}" HEALTH_INTERVAL=1 LOCK_WAIT="${LOCK_WAIT:-2}" \
    bash "$script" ${1+"$@"} > "$LOG" 2>&1
  echo $?
}

deploy() { new_release "$1"; run_script "$ROOT/releases/$1/deploy.sh"; }

link() { if [ -L "$ROOT/$1" ]; then basename "$(readlink "$ROOT/$1")"; fi; }
running() { cat "$FAKE_STATE_DIR/running" 2>/dev/null || true; }
contains() { grep -qxF "$2" "$FAKE_STATE_DIR/$1" 2>/dev/null; }

check() { # check <說明> <指令...>
  local desc="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1)); printf '  ok    %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$desc"
    sed 's/^/        | /' "$LOG" | tail -n 20
  fi
}
eq() { [ "$1" = "$2" ]; }
not() { ! "$@"; }

scenario() { printf '\n%s\n' "$1"; }

# ---- 情境 ----
scenario "1. 缺少 shared/.env：直接失敗，什麼都沒動"
mv "$ROOT/shared/.env" "$ROOT/shared/.env.bak"
rc="$(deploy sha-1)"
check "exit 1" eq "$rc" 1
check "沒有 pull" not contains pulled sha-1
check "沒有建立 current" eq "$(link current)" ""
mv "$ROOT/shared/.env.bak" "$ROOT/shared/.env"

scenario "2. 首次部署成功"
rc="$(deploy sha-1)"
check "exit 0" eq "$rc" 0
check "current = sha-1" eq "$(link current)" sha-1
check "執行中 = sha-1" eq "$(running)" sha-1
check "有跑 migration" contains migrated sha-1
check "沒有 previous" eq "$(link previous)" ""
check "部署 log 寫進 shared/logs" test -n "$(ls "$ROOT"/shared/logs/deploy-*.log 2>/dev/null)"
check "部署鎖已釋放" not test -e "$ROOT/.deploy.lock"

scenario "3. 第二次部署成功"
rc="$(deploy sha-2)"
check "exit 0" eq "$rc" 0
check "current = sha-2" eq "$(link current)" sha-2
check "previous = sha-1" eq "$(link previous)" sha-1
check "執行中 = sha-2" eq "$(running)" sha-2

scenario "4. pull 失敗：中止，服務沒動"
rc="$(export FAKE_PULL_FAIL_TAG=sha-3; deploy sha-3)"
check "exit 1" eq "$rc" 1
check "current 還是 sha-2" eq "$(link current)" sha-2
check "沒有啟動 sha-3" not contains started sha-3
check "沒有跑 sha-3 的 migration" not contains migrated sha-3

scenario "5. migration 失敗：中止，服務沒動"
rc="$(export FAKE_MIGRATE_FAIL_TAG=sha-4; deploy sha-4)"
check "exit 1" eq "$rc" 1
check "current 還是 sha-2" eq "$(link current)" sha-2
check "沒有啟動 sha-4" not contains started sha-4
check "回報資料庫可能部分 migrate" grep -q "部分 migrate" "$LOG"

scenario "6. health 逾時：自動回滾"
rc="$(export FAKE_UNHEALTHY_TAGS=sha-5; deploy sha-5)"
check "exit 1" eq "$rc" 1
check "current 回到 sha-2" eq "$(link current)" sha-2
check "執行中回到 sha-2" eq "$(running)" sha-2
check "previous 維持 sha-1" eq "$(link previous)" sha-1
check "log 有回滾訊息" grep -q "已回滾到 sha-2" "$LOG"

scenario "7. container 跑的不是新版 image：自動回滾"
rc="$(export FAKE_WRONG_IMAGE_TAG=sha-6; deploy sha-6)"
check "exit 1" eq "$rc" 1
check "current 回到 sha-2" eq "$(link current)" sha-2

scenario "8. 外部 health URL 失敗：自動回滾"
printf 'HEALTH_URL="https://app.example.com/health"\n' >> "$ROOT/shared/.env"
rc="$(export FAKE_CURL_FAIL_TAG=sha-7; deploy sha-7)"
check "exit 1" eq "$rc" 1
check "current 回到 sha-2" eq "$(link current)" sha-2
check "有檢查 .env 裡的 HEALTH_URL" grep -q "https://app.example.com/health" "$FAKE_STATE_DIR/curl.log"
printf 'APP_ENV=test\n' > "$ROOT/shared/.env"

scenario "9. 回滾也失敗：exit 2"
rc="$(export FAKE_UNHEALTHY_TAGS="sha-8 sha-2"; deploy sha-8)"
check "exit 2" eq "$rc" 2
check "current 指回 sha-2" eq "$(link current)" sha-2

scenario "10. 手動回滾（從 current 這個 symlink 執行）"
rc="$(run_script "$ROOT/current/deploy.sh" rollback)"
check "exit 0" eq "$rc" 0
check "current = sha-1" eq "$(link current)" sha-1
check "previous = sha-2" eq "$(link previous)" sha-2
check "執行中 = sha-1" eq "$(running)" sha-1
check "手動回滾不跑 migration" eq "$(grep -c '^sha-1$' "$FAKE_STATE_DIR/migrated")" 1

scenario "11. 部署鎖被佔用：等待逾時，exit 75"
sleep 30 &
HOLDER_PID=$!
mkdir "$ROOT/.deploy.lock"
echo "$HOLDER_PID" > "$ROOT/.deploy.lock/pid"
rc="$(export LOCK_WAIT=1; deploy sha-9)"
check "exit 75" eq "$rc" 75
check "current 還是 sha-1" eq "$(link current)" sha-1
check "沒有動到別人的鎖" test -f "$ROOT/.deploy.lock/pid"
kill "$HOLDER_PID" 2>/dev/null
wait "$HOLDER_PID" 2>/dev/null
HOLDER_PID=""
rm -rf "$ROOT/.deploy.lock"

scenario "12. 殘留的部署鎖（持有者已不存在）：移除後繼續部署"
sh -c 'exit 0' &
dead_pid=$!
wait "$dead_pid"
mkdir "$ROOT/.deploy.lock"
echo "$dead_pid" > "$ROOT/.deploy.lock/pid"
rc="$(deploy sha-9)"
check "exit 0" eq "$rc" 0
check "current = sha-9" eq "$(link current)" sha-9
check "log 有移除殘留鎖的訊息" grep -q "移除殘留的部署鎖" "$LOG"
check "部署鎖已釋放" not test -e "$ROOT/.deploy.lock"

scenario "13. 專案沒有 migration（MIGRATE_SERVICE 為空）"
rc="$(export MIGRATE_SERVICE=""; deploy sha-10)"
check "exit 0" eq "$rc" 0
check "沒有跑 migration" not contains migrated sha-10

scenario "14. 清理舊 release（KEEP_RELEASES=2），不動還沒部署過的目錄"
new_release sha-99
rc="$(export KEEP_RELEASES=2; deploy sha-11)"
check "exit 0" eq "$rc" 0
check "剩下 sha-10、sha-11、sha-99" eq "$(ls "$ROOT/releases" | tr '\n' ' ')" "sha-10 sha-11 sha-99 "
check "移除了舊 release 的 image" grep -q "example/app-api:sha-1$" "$FAKE_STATE_DIR/image-rm"

printf '\n結果：%s 通過，%s 失敗\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
