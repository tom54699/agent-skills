#!/usr/bin/env bash
# docker-server-deploy：deploy.sh 範本的整合測試（B）
#
# 用真的 Docker 跑一遍：本機 registry、推幾個測試 tag，再用 deploy.sh 部署。
# 需要 Docker daemon 與網路（會拉 registry:2 和 busybox）。發佈前手動執行：
#
#   bash tests/docker-server-deploy/integration-test.sh
#
# 可以用環境變數換 port：REGISTRY_PORT（預設 5055）、APP_PORT（預設 18080）
# 結束時會清掉測試用的 container、image 與暫存目錄。

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMPLATE="${DEPLOY_TEMPLATE:-$REPO_ROOT/skills/docker-server-deploy/assets/templates/deploy.sh}"
REGISTRY_PORT="${REGISTRY_PORT:-5055}"
APP_PORT="${APP_PORT:-18080}"
PROJECT="kbdeploy-it"
REGISTRY_NAME="kbdeploy-it-registry"
IMAGE="localhost:$REGISTRY_PORT/kbdeploy-it-app"
TAGS="sha-a sha-b sha-c sha-d"

WORK="$(mktemp -d)"
ROOT="$WORK/srv/app"
LOG="$WORK/last.log"
PASS=0
FAIL=0

cleanup() {
  docker compose -p "$PROJECT" down --remove-orphans >/dev/null 2>&1 || true
  docker rm -f "$REGISTRY_NAME" >/dev/null 2>&1 || true
  for tag in base $TAGS; do docker image rm "$IMAGE:$tag" >/dev/null 2>&1 || true; done
  rm -rf "$WORK"
}
trap cleanup EXIT

if ! docker info >/dev/null 2>&1; then
  echo "需要 Docker daemon（例如先打開 Docker Desktop）"
  exit 2
fi

step() { printf '\n%s\n' "$1"; }
check() {
  local desc="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1)); printf '  ok    %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$desc"
    sed 's/^/        | /' "$LOG" | tail -n 25
  fi
}
eq() { [ "$1" = "$2" ]; }
link() { if [ -L "$ROOT/$1" ]; then basename "$(readlink "$ROOT/$1")"; fi; }
running_image() {
  local cid
  cid="$(docker compose -p "$PROJECT" ps -q api 2>/dev/null | head -n 1)"
  [ -n "$cid" ] && docker inspect -f '{{.Config.Image}}' "$cid"
}
app_healthy() { curl -fsS --max-time 5 -o /dev/null "http://127.0.0.1:$APP_PORT/health"; }

make_release() { # make_release <tag> <api command (JSON)> <migration exit code>
  local dir="$ROOT/releases/$1"
  mkdir -p "$dir"
  cp "$TEMPLATE" "$dir/deploy.sh"
  cat > "$dir/docker-compose.yml" <<YAML
name: $PROJECT
services:
  api:
    image: $IMAGE:\${RELEASE_TAG:?RELEASE_TAG is required}
    command: $2
    ports:
      - "127.0.0.1:\${APP_PORT}:8080"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8080/health"]
      interval: 2s
      timeout: 2s
      retries: 2
      start_period: 1s
  migrate:
    image: $IMAGE:\${RELEASE_TAG:?RELEASE_TAG is required}
    profiles: ["jobs"]
    restart: "no"
    command: ["sh", "-c", "exit $3"]
YAML
}

deploy() { # deploy <script path> [args...]；印出 exit code
  local script="$1"
  shift
  APP_SERVICES=api HEALTH_TIMEOUT=25 HEALTH_INTERVAL=1 LOCK_WAIT=5 \
    bash "$script" ${1+"$@"} > "$LOG" 2>&1
  echo $?
}

HEALTHY='["httpd", "-f", "-p", "8080", "-h", "/www"]'
BROKEN='["sleep", "3600"]'

step "準備：本機 registry 與測試 image"
docker rm -f "$REGISTRY_NAME" >/dev/null 2>&1 || true
docker run -d --name "$REGISTRY_NAME" -p "127.0.0.1:$REGISTRY_PORT:5000" registry:2 >/dev/null || exit 1
for _ in $(seq 1 30); do
  curl -fsS "http://127.0.0.1:$REGISTRY_PORT/v2/" >/dev/null 2>&1 && break
  sleep 1
done
printf 'FROM busybox:1.36\nRUN mkdir -p /www && echo ok > /www/health\nCMD ["httpd", "-f", "-p", "8080", "-h", "/www"]\n' \
  | docker build -q -t "$IMAGE:base" - >/dev/null || exit 1
for tag in $TAGS; do
  docker tag "$IMAGE:base" "$IMAGE:$tag"
  docker push "$IMAGE:$tag" >/dev/null || exit 1
  docker image rm "$IMAGE:$tag" >/dev/null   # 刪掉本機的 tag，部署時才會真的 pull
done
mkdir -p "$ROOT/shared"
printf 'APP_PORT=%s\nHEALTH_URL=http://127.0.0.1:%s/health\n' "$APP_PORT" "$APP_PORT" > "$ROOT/shared/.env"
chmod 600 "$ROOT/shared/.env"
echo "  ok    registry 在 localhost:$REGISTRY_PORT，已推送 $TAGS"

step "1. 首次部署成功"
make_release sha-a "$HEALTHY" 0
rc="$(deploy "$ROOT/releases/sha-a/deploy.sh")"
check "exit 0" eq "$rc" 0
check "current = sha-a" eq "$(link current)" sha-a
check "container 跑 sha-a" eq "$(running_image)" "$IMAGE:sha-a"
check "對外 health 正常" app_healthy

step "2. 第二次部署成功"
make_release sha-b "$HEALTHY" 0
rc="$(deploy "$ROOT/releases/sha-b/deploy.sh")"
check "exit 0" eq "$rc" 0
check "current = sha-b" eq "$(link current)" sha-b
check "previous = sha-a" eq "$(link previous)" sha-a
check "container 跑 sha-b" eq "$(running_image)" "$IMAGE:sha-b"

step "3. pull 失敗（registry 沒有這個 tag）"
make_release sha-missing "$HEALTHY" 0
rc="$(deploy "$ROOT/releases/sha-missing/deploy.sh")"
check "exit 1" eq "$rc" 1
check "current 還是 sha-b" eq "$(link current)" sha-b
check "container 還是 sha-b" eq "$(running_image)" "$IMAGE:sha-b"

step "4. migration 失敗"
make_release sha-c "$HEALTHY" 1
rc="$(deploy "$ROOT/releases/sha-c/deploy.sh")"
check "exit 1" eq "$rc" 1
check "current 還是 sha-b" eq "$(link current)" sha-b
check "container 還是 sha-b" eq "$(running_image)" "$IMAGE:sha-b"
check "服務持續正常" app_healthy

step "5. health check 失敗：自動回滾"
make_release sha-d "$BROKEN" 0
rc="$(deploy "$ROOT/releases/sha-d/deploy.sh")"
check "exit 1" eq "$rc" 1
check "current 回到 sha-b" eq "$(link current)" sha-b
check "container 回到 sha-b" eq "$(running_image)" "$IMAGE:sha-b"
check "回滾後對外 health 正常" app_healthy

step "6. 手動回滾"
rc="$(deploy "$ROOT/current/deploy.sh" rollback)"
check "exit 0" eq "$rc" 0
check "current = sha-a" eq "$(link current)" sha-a
check "previous = sha-b" eq "$(link previous)" sha-b
check "container 跑 sha-a" eq "$(running_image)" "$IMAGE:sha-a"
check "對外 health 正常" app_healthy

printf '\n結果：%s 通過，%s 失敗\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
