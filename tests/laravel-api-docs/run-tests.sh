#!/usr/bin/env bash
# laravel-api-docs：Apidog 腳本與 gen-html.sh 的模擬測試
#
# 用假的 curl（放在 PATH 最前面）模擬 Apidog，不連網、不需要 Laravel 專案。
# 執行：bash tests/laravel-api-docs/run-tests.sh
# 預設用 /bin/bash 跑腳本（macOS 為 bash 3.2），可用 BASH_BIN 覆寫。
#
# 假 curl 的行為：
#   export-openapi  回傳 $FAKE_STATE_DIR/remote-spec.json（包成 data.content 字串）
#   api-tree-list   回傳 $FAKE_STATE_DIR/tree.json
#   import-openapi  把 request body 存成 $FAKE_STATE_DIR/import-<n>.json，回傳 endpointCreated=1
#   每次呼叫記錄到 $FAKE_STATE_DIR/calls.log

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SCRIPTS="$REPO_ROOT/skills/laravel-api-docs/scripts"
BASH_BIN="${BASH_BIN:-/bin/bash}"

WORK="$(mktemp -d)"
STUB_DIR="$WORK/bin"
PROJECT="$WORK/project"
export FAKE_STATE_DIR="$WORK/state"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$STUB_DIR" "$PROJECT" "$FAKE_STATE_DIR"

# ---- 假的 curl ----
cat > "$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
state="$FAKE_STATE_DIR"
out=""
method="GET"
url=""
body=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -d) body="${2#@}"; shift 2 ;;
    -H|-w) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
echo "$method $url" >> "$state/calls.log"

case "$url" in
  *export-openapi*)
    cp "$body" "$state/export-request.json"
    jq -n --rawfile spec "$state/remote-spec.json" '{success: true, data: {content: $spec}}' > "$out"
    ;;
  *api-tree-list*)
    cp "$state/tree.json" "$out"
    ;;
  *import-openapi*)
    n=$(( $(ls "$state" | grep -c '^import-') + 1 ))
    cp "$body" "$state/import-$n.json"
    echo '{"success": true, "data": {"counters": {"endpointCreated": 1, "endpointUpdated": 0, "endpointIgnored": 0, "endpointFailed": 0}}}' > "$out"
    ;;
  *)
    echo '{}' > "$out"
    printf '404'
    exit 0
    ;;
esac
printf '200'
STUB
chmod +x "$STUB_DIR/curl"

# ---- fixtures ----
cat > "$FAKE_STATE_DIR/remote-spec.json" <<'JSON'
{
  "openapi": "3.1.0",
  "info": {"title": "Remote", "version": "1.0.0"},
  "tags": [{"name": "Order"}, {"name": "Other"}],
  "paths": {
    "/api/x": {
      "post": {
        "tags": ["Order"],
        "x-apidog-folder": "Driver/Order",
        "x-apidog-status": "released",
        "parameters": [{"name": "X-Custom", "in": "header", "required": true, "schema": {"type": "string"}}],
        "responses": {"200": {"description": "ok", "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Outer"}}}}}
      }
    },
    "/api/y": {
      "get": {
        "tags": ["Other"],
        "responses": {"200": {"description": "ok", "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Unused"}}}}}
      }
    }
  },
  "components": {
    "schemas": {
      "Outer": {"type": "object", "properties": {"inner": {"$ref": "#/components/schemas/Inner"}}},
      "Inner": {"type": "string"},
      "Unused": {"type": "integer"}
    },
    "securitySchemes": {"bearer": {"type": "http", "scheme": "bearer"}}
  }
}
JSON

cat > "$WORK/tree-ok.json" <<'JSON'
{
  "success": true,
  "data": [
    {
      "type": "apiDetailFolder", "key": "apiDetailFolder.10", "name": "Driver",
      "children": [
        {
          "type": "apiDetailFolder", "key": "apiDetailFolder.11", "name": "Order",
          "children": [{"type": "apiDetail", "api": {"method": "POST", "path": "/api/x", "folderId": 11}}]
        },
        {"type": "apiDetail", "api": {"method": "GET", "path": "/api/y", "folderId": 10}}
      ]
    },
    {"type": "apiDetail", "api": {"method": "GET", "path": "/api/new", "folderId": 0}}
  ]
}
JSON

# POST /api/x 落在 Driver（10）而不是 Driver/Order（11），且沒有 GET /api/new
cat > "$WORK/tree-bad.json" <<'JSON'
{
  "success": true,
  "data": [
    {
      "type": "apiDetailFolder", "key": "apiDetailFolder.10", "name": "Driver",
      "children": [{"type": "apiDetail", "api": {"method": "POST", "path": "/api/x", "folderId": 10}}]
    }
  ]
}
JSON

cat > "$PROJECT/openapi.yaml" <<'YAML'
openapi: 3.1.0
info:
  title: Local
  version: 1.0.0
paths:
  /api/x:
    post:
      x-apidog-folder: Driver/Order
      x-apidog-status: released
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Outer"
  /api/new:
    get:
      x-apidog-folder: Somewhere
      responses:
        "200":
          description: ok
components:
  schemas:
    Outer:
      type: object
      properties:
        inner:
          $ref: "#/components/schemas/Inner"
    Inner:
      type: string
    Unused:
      type: integer
YAML

cat > "$PROJECT/targets.json" <<'JSON'
[
  {"method": "POST", "path": "/api/x", "folder_id": 11},
  {"method": "get", "path": "/api/new", "folder_id": 0}
]
JSON

ENV_FILE_CONTENT='APIDOG_ACCESS_TOKEN=test-token
APIDOG_PROJECT_ID=123'

# ---- helpers ----
PASS=0
FAIL=0
LOG="$WORK/last.log"
OUT="$WORK/last.out"

reset_state() {
  rm -f "$FAKE_STATE_DIR"/calls.log "$FAKE_STATE_DIR"/import-*.json "$FAKE_STATE_DIR"/export-request.json
  cp "$WORK/tree-ok.json" "$FAKE_STATE_DIR/tree.json"
  printf '%s\n' "$ENV_FILE_CONTENT" > "$PROJECT/.env.agents"
}

run_script() { # run_script <script> [args...]；印出 exit code，stdout 寫到 $OUT，stderr 寫到 $LOG
  local script="$1"
  shift
  (cd "$PROJECT" && env -u APIDOG_ACCESS_TOKEN -u APIDOG_PROJECT_ID PATH="$STUB_DIR:$PATH" \
    "$BASH_BIN" "$SCRIPTS/$script" ${1+"$@"} > "$OUT" 2> "$LOG")
  echo $?
}

call_count() { [ -f "$FAKE_STATE_DIR/calls.log" ] && wc -l < "$FAKE_STATE_DIR/calls.log" | tr -d ' ' || echo 0; }

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
jq_true() { jq -e "$1" "$2" >/dev/null 2>&1; }

scenario() { printf '\n%s\n' "$1"; }

# ---- 情境 ----
scenario "1. 所有腳本語法正確"
for f in "$SCRIPTS"/*.sh; do
  check "bash -n $(basename "$f")" "$BASH_BIN" -n "$f"
done

scenario "2. export-remote：缺少憑證時失敗，不送任何請求"
reset_state
rm -f "$PROJECT/.env.agents"
rc="$(run_script export-remote.sh --endpoint "POST /api/x" --output "$PROJECT/remote-base.json")"
check "exit 1" eq "$rc" 1
check "訊息提到 APIDOG_ACCESS_TOKEN" grep -q "APIDOG_ACCESS_TOKEN" "$LOG"
check "沒有呼叫 curl" eq "$(call_count)" 0

scenario "3. export-remote：只匯出指定 API，保留 extensions，components 含間接引用"
reset_state
rc="$(run_script export-remote.sh --endpoint "POST /api/x" --endpoint "DELETE /api/missing" --output "$PROJECT/remote-base.json")"
check "exit 0" eq "$rc" 0
check "request 帶 includeApidogExtensionProperties: true" jq_true '.options.includeApidogExtensionProperties == true' "$FAKE_STATE_DIR/export-request.json"
check "只有 /api/x" jq_true '(.paths | keys) == ["/api/x"]' "$PROJECT/remote-base.json"
check "保留 x-apidog-status 與自訂 header" jq_true '.paths["/api/x"].post["x-apidog-status"] == "released" and .paths["/api/x"].post.parameters[0].name == "X-Custom"' "$PROJECT/remote-base.json"
check "components 含 Outer 與間接引用的 Inner，不含 Unused" jq_true '(.components.schemas | keys) == ["Inner", "Outer"]' "$PROJECT/remote-base.json"
check "保留 securitySchemes" jq_true '.components.securitySchemes.bearer != null' "$PROJECT/remote-base.json"
check "tags 只剩用到的 Order" jq_true '.tags == [{"name": "Order"}]' "$PROJECT/remote-base.json"
check "found 列出 POST /api/x" jq_true '.found == ["POST /api/x"]' "$OUT"
check "missing 列出 DELETE /api/missing" jq_true '.missing == ["DELETE /api/missing"]' "$OUT"

scenario "4. list-folders：列出資料夾與每支 API 所在位置"
reset_state
rc="$(run_script list-folders.sh)"
check "exit 0" eq "$rc" 0
check "Driver → 10" grep -qx "Driver → 10" "$OUT"
check "Driver/Order → 11" grep -qx "Driver/Order → 11" "$OUT"
rc="$(run_script list-folders.sh --apis)"
check "--apis exit 0" eq "$rc" 0
check "POST /api/x → Driver/Order (11)" grep -qx "POST /api/x → Driver/Order (11)" "$OUT"
check "根目錄顯示 (root) (0)" grep -qx "GET /api/new → (root) (0)" "$OUT"
rc="$(run_script list-folders.sh --json)"
check "--json 輸出 folders 與 apis" jq_true '(.folders | length) == 2 and (.apis | length) == 3' "$OUT"

scenario "5. upload：target 不在 spec 中，不送任何請求"
reset_state
echo '[{"method": "post", "path": "/api/nope", "folder_id": 1}]' > "$PROJECT/bad-targets.json"
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/bad-targets.json")"
check "exit 1" eq "$rc" 1
check "指出 POST /api/nope 不在 spec 中" grep -q "POST /api/nope 不在 spec 中" "$LOG"
check "沒有呼叫 curl" eq "$(call_count)" 0

scenario "6. upload：folder_id 不是整數，不送任何請求"
reset_state
echo '[{"method": "post", "path": "/api/x", "folder_id": "11"}]' > "$PROJECT/bad-targets.json"
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/bad-targets.json")"
check "exit 1" eq "$rc" 1
check "指出 folder_id 必須是非負整數" grep -q "folder_id 必須是非負整數" "$LOG"
check "沒有呼叫 curl" eq "$(call_count)" 0

scenario "7. upload：重複的 target，不送任何請求"
reset_state
echo '[{"method": "post", "path": "/api/x", "folder_id": 11}, {"method": "POST", "path": "/api/x", "folder_id": 10}]' > "$PROJECT/bad-targets.json"
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/bad-targets.json")"
check "exit 1" eq "$rc" 1
check "指出重複的 target" grep -q "重複的 target：POST /api/x" "$LOG"
check "沒有呼叫 curl" eq "$(call_count)" 0

scenario "8. upload：輸入正確但缺少憑證，不送任何請求"
reset_state
rm -f "$PROJECT/.env.agents"
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/targets.json")"
check "exit 1" eq "$rc" 1
check "沒有呼叫 curl" eq "$(call_count)" 0

scenario "9. upload：依資料夾分批、移除 x-apidog-folder、驗證通過"
reset_state
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/targets.json")"
check "exit 0" eq "$rc" 0
check "上傳兩批" eq "$(ls "$FAKE_STATE_DIR" | grep -c '^import-')" 2
check "第 1 批是 folder 0，只有 GET /api/new" jq_true '.options.targetEndpointFolderId == 0 and ((.input | fromjson | .paths | keys) == ["/api/new"])' "$FAKE_STATE_DIR/import-1.json"
check "第 2 批是 folder 11，只有 POST /api/x" jq_true '.options.targetEndpointFolderId == 11 and ((.input | fromjson | .paths | keys) == ["/api/x"])' "$FAKE_STATE_DIR/import-2.json"
check "兩批都沒有 x-apidog-folder" not grep -q "x-apidog-folder" "$FAKE_STATE_DIR/import-1.json" "$FAKE_STATE_DIR/import-2.json"
check "保留 x-apidog-status" jq_true '.input | fromjson | .paths["/api/x"].post["x-apidog-status"] == "released"' "$FAKE_STATE_DIR/import-2.json"
check "第 2 批 components 只有 Inner、Outer" jq_true '.input | fromjson | (.components.schemas | keys) == ["Inner", "Outer"]' "$FAKE_STATE_DIR/import-2.json"
check "第 1 批沒有用到的 schema" jq_true '.input | fromjson | (.components.schemas // {}) == {}' "$FAKE_STATE_DIR/import-1.json"
check "updateFolderOfChangedEndpoint 為 true" jq_true '.options.updateFolderOfChangedEndpoint == true' "$FAKE_STATE_DIR/import-2.json"
check "結果 verified、created=2" jq_true '.verified == true and .created == 2 and .batches == 2' "$OUT"

scenario "10. upload：上傳後資料夾不符或找不到 API，回報差異並失敗"
reset_state
cp "$WORK/tree-bad.json" "$FAKE_STATE_DIR/tree.json"
rc="$(run_script upload-apidog.sh --openapi "$PROJECT/openapi.yaml" --targets "$PROJECT/targets.json")"
check "exit 1" eq "$rc" 1
check "指出 POST /api/x 預期 11、實際在 Driver (10)" grep -q "POST /api/x：預期 folder_id 11，實際在 Driver (10)" "$LOG"
check "指出 GET /api/new 找不到" grep -q "GET /api/new：上傳後在 Apidog 找不到" "$LOG"

scenario "11. gen-html：產出首頁與 API 規格頁"
cat > "$PROJECT/business.md" <<'MD'
# 司機訂單調整

## 目的
說明目的。

## 需求
- 需求一

## 業務邏輯
### 哪些資料會出現
- 欄位 `status`

### 什麼時候出現或消失
| 情境 | 結果 |
|---|---|
| 訂單取消 | 不顯示 |

## 前端要改什麼
- TODO：確認畫面
MD
rc="$(run_script gen-html.sh --openapi "$PROJECT/openapi.yaml" --business-md "$PROJECT/business.md" --output-dir "$PROJECT/out")"
check "exit 0" eq "$rc" 0
check "產出 index.html" test -f "$PROJECT/out/index.html"
check "產出 api-docs.html" test -f "$PROJECT/out/api-docs.html"
check "首頁標題取自 business.md" grep -q "<h1>司機訂單調整</h1>" "$PROJECT/out/index.html"
check "首頁列出本次 API" grep -q "<code>POST</code> /api/x" "$PROJECT/out/index.html"
check "首頁含業務邏輯表格" grep -q "<td>訂單取消</td>" "$PROJECT/out/index.html"
check "API 規格頁內嵌 spec" grep -q '"/api/new"' "$PROJECT/out/api-docs.html"
check "結果 endpoint_count=2" jq_true '.endpoint_count == 2' "$OUT"

scenario "12. gen-html：缺少 business.md 時失敗"
rc="$(run_script gen-html.sh --openapi "$PROJECT/openapi.yaml" --business-md "$PROJECT/nope.md" --output-dir "$PROJECT/out2")"
check "exit 1" eq "$rc" 1
check "沒有產出資料夾" not test -d "$PROJECT/out2"

printf '\n結果：%s 通過，%s 失敗\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
