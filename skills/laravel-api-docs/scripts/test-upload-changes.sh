#!/bin/bash
# 測試 upload-apidog.sh 的新增功能：
#   - build_delta_spec（delta 過濾）
#   - check_path_strategy_alignment（path strategy 比對）
#
# 使用方式：
#   bash scripts/test-upload-changes.sh
#
# 不需要 Apidog 憑證，純本地 mock 測試。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD_SCRIPT="$SCRIPT_DIR/upload-apidog.sh"

PASS=0
FAIL=0

c_green='\033[0;32m'
c_red='\033[0;31m'
c_reset='\033[0m'

pass() { echo -e "${c_green}PASS${c_reset} $1"; PASS=$((PASS + 1)); }
fail_test() { echo -e "${c_red}FAIL${c_reset} $1"; FAIL=$((FAIL + 1)); }

# ── 載入函式（只萃取函式定義，不執行主流程）────────────────────────────────────
# 用 awk 抽出所有 "name() {" ... "^}" 區塊，eval 到目前 shell
eval "$(awk '
  /^[a-z_][a-z_0-9]*\(\) \{$/ { in_func=1; buf=$0 ORS; next }
  in_func && /^\}$/ { buf=buf $0 ORS; printf "%s\n", buf; in_func=0; buf=""; next }
  in_func { buf=buf $0 ORS }
' "$UPLOAD_SCRIPT")"

# check_path_strategy_alignment 呼叫 fail()，改成 return 1 讓測試可繼續
fail() { return 1; }

# ── fixtures ─────────────────────────────────────────────────────────────────
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

FULL_SPEC="$TMPDIR_TEST/full.json"
cat > "$FULL_SPEC" <<'JSON'
{
  "openapi": "3.1.0",
  "info": { "title": "Test API", "version": "1.0.0" },
  "servers": [{ "url": "https://api.example.com" }],
  "components": { "schemas": { "Error": { "type": "object" } } },
  "tags": [{ "name": "Users" }, { "name": "Orders" }],
  "paths": {
    "/users":       {
      "get":  { "summary": "List users",   "tags": ["Users"] },
      "post": { "summary": "Create user",  "tags": ["Users"] }
    },
    "/users/{id}":  { "get": { "summary": "Get user",     "tags": ["Users"] } },
    "/orders":      { "get": { "summary": "List orders",  "tags": ["Orders"] } },
    "/orders/{id}": { "put": { "summary": "Update order", "tags": ["Orders"] } },
    "/products":    { "get": { "summary": "List products" } }
  }
}
JSON

CANDIDATE_NEW_UPDATED="$TMPDIR_TEST/candidates_new_updated.json"
cat > "$CANDIDATE_NEW_UPDATED" <<'JSON'
{
  "meta": { "path_strategy": "keep-full-path" },
  "candidates": [
    { "status": "new",     "method": "GET", "path": "/users" },
    { "status": "updated", "method": "PUT", "path": "/orders/{id}" }
  ]
}
JSON

CANDIDATE_DELETED_ONLY="$TMPDIR_TEST/candidates_deleted.json"
cat > "$CANDIDATE_DELETED_ONLY" <<'JSON'
{
  "candidates": [
    { "status": "deleted", "method": "GET", "path": "/products" }
  ]
}
JSON

CANDIDATE_MISMATCH="$TMPDIR_TEST/candidates_mismatch.json"
cat > "$CANDIDATE_MISMATCH" <<'JSON'
{
  "candidates": [
    { "status": "new", "method": "GET", "path": "/api/users" }
  ]
}
JSON

REMOTE_KEEP_FULL="$TMPDIR_TEST/remote_keep_full.json"
cat > "$REMOTE_KEEP_FULL" <<'JSON'
{
  "openapi": "3.1.0",
  "paths": {
    "/api/users":  { "get": {} },
    "/api/orders": { "get": {} }
  }
}
JSON

REMOTE_STRIP="$TMPDIR_TEST/remote_strip.json"
cat > "$REMOTE_STRIP" <<'JSON'
{
  "openapi": "3.1.0",
  "paths": {
    "/users":  { "get": {} },
    "/orders": { "get": {} }
  }
}
JSON

REMOTE_EMPTY="$TMPDIR_TEST/remote_empty.json"
cat > "$REMOTE_EMPTY" <<'JSON'
{ "openapi": "3.1.0", "paths": {} }
JSON

# ── build_delta_spec ─────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " build_delta_spec 測試"
echo "═══════════════════════════════════════"

OUT1="$TMPDIR_TEST/out1.json"
build_delta_spec "$FULL_SPEC" "$CANDIDATE_NEW_UPDATED" "$OUT1" 2>/dev/null

path_count=$(jq '(.paths // {}) | length' "$OUT1")
[ "$path_count" -eq 2 ] \
  && pass "Test 1: delta 只含 2 個 candidate paths" \
  || fail_test "Test 1: 期待 2 paths，得到 $path_count"

has_users=$(jq '.paths | has("/users")' "$OUT1")
has_orders=$(jq '.paths | has("/orders/{id}")' "$OUT1")
[ "$has_users" = "true" ] && [ "$has_orders" = "true" ] \
  && pass "Test 2: delta 包含 /users 與 /orders/{id}" \
  || fail_test "Test 2: /users=$has_users /orders/{id}=$has_orders"

has_products=$(jq '.paths | has("/products")' "$OUT1")
[ "$has_products" = "false" ] \
  && pass "Test 3: delta 排除非 candidate path /products" \
  || fail_test "Test 3: /products 不應出現在 delta"

has_components=$(jq 'has("components")' "$OUT1")
has_servers=$(jq 'has("servers")' "$OUT1")
has_info=$(jq 'has("info")' "$OUT1")
[ "$has_components" = "true" ] && [ "$has_servers" = "true" ] && [ "$has_info" = "true" ] \
  && pass "Test 4: delta 保留 info / servers / components 共用節點" \
  || fail_test "Test 4: info=$has_info servers=$has_servers components=$has_components"

has_user_post=$(jq '.paths["/users"] | has("post")' "$OUT1")
[ "$has_user_post" = "false" ] \
  && pass "Test 4.1: delta 只保留 candidate method，不帶入同 path 其他 method" \
  || fail_test "Test 4.1: /users post 不應出現在 delta"

# deleted-only → fallback 全量
OUT5="$TMPDIR_TEST/out5.json"
build_delta_spec "$FULL_SPEC" "$CANDIDATE_DELETED_ONLY" "$OUT5" 2>/dev/null
path_count5=$(jq '(.paths // {}) | length' "$OUT5")
[ "$path_count5" -eq 5 ] \
  && pass "Test 5: deleted-only candidate → fallback 全量（5 paths）" \
  || fail_test "Test 5: 期待 5 paths，得到 $path_count5"

# path mismatch → return 1（阻擋上傳）
OUT6="$TMPDIR_TEST/out6.json"
if build_delta_spec "$FULL_SPEC" "$CANDIDATE_MISMATCH" "$OUT6" 2>/dev/null; then
  fail_test "Test 6: path mismatch 應回傳非 0，但成功了"
else
  pass "Test 6: path mismatch → 正確回傳非 0（阻擋上傳）"
fi

# ── folder-aware mapping ─────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " folder-aware mapping 測試"
echo "═══════════════════════════════════════"

APIDOG_TREE="$TMPDIR_TEST/apidog_tree.json"
cat > "$APIDOG_TREE" <<'JSON'
{
  "success": true,
  "data": [
    {
      "type": "apiDetailFolder",
      "key": "apiDetailFolder.1417834",
      "children": [
        {
          "type": "apiDetail",
          "api": { "method": "GET", "path": "/api/admin/users", "folderId": 1417834 }
        },
        {
          "type": "apiDetail",
          "api": { "method": "POST", "path": "/api/admin/orders" }
        }
      ]
    },
    {
      "type": "apiDetailFolder",
      "key": "folder_without_numeric_id",
      "children": [
        {
          "type": "apiDetail",
          "api": { "method": "GET", "path": "/api/skipped/no-folder" }
        }
      ]
    }
  ]
}
JSON

FOLDER_MAPPING="$TMPDIR_TEST/folder_mapping.json"
build_apidog_folder_mapping "$APIDOG_TREE" "$FOLDER_MAPPING"

exact_user_folder=$(jq -r '.exact[] | select(.method == "get" and .path == "/api/admin/users") | .folder_id' "$FOLDER_MAPPING")
[ "$exact_user_folder" = "1417834" ] \
  && pass "Test 12: apiDetail exact mapping 解析 folderId" \
  || fail_test "Test 12: exact folderId 期待 1417834，得到 $exact_user_folder"

inherited_order_folder=$(jq -r '.exact[] | select(.method == "post" and .path == "/api/admin/orders") | .folder_id' "$FOLDER_MAPPING")
[ "$inherited_order_folder" = "1417834" ] \
  && pass "Test 13: apiDetailFolder numeric key 可供 child API 繼承 folderId" \
  || fail_test "Test 13: inherited folderId 期待 1417834，得到 $inherited_order_folder"

skipped_bad_folder=$(jq '[.exact[] | select(.path == "/api/skipped/no-folder")] | length' "$FOLDER_MAPPING")
[ "$skipped_bad_folder" -eq 0 ] \
  && pass "Test 14: 無 numeric suffix 的 folder key 不推導 folderId" \
  || fail_test "Test 14: 無效 folder key 不應產生 mapping"

CANDIDATE_FOLDER="$TMPDIR_TEST/candidates_folder.json"
cat > "$CANDIDATE_FOLDER" <<'JSON'
{
  "candidates": [
    { "status": "updated", "method": "GET", "path": "/api/admin/users" },
    { "status": "new", "method": "GET", "path": "/api/admin/users/export" },
    { "status": "new", "method": "POST", "path": "/api/admin/invoices", "folder_id": 1417999 },
    { "status": "new", "method": "GET", "path": "/api/unknown" },
    { "status": "deleted", "method": "DELETE", "path": "/api/admin/users/{id}" }
  ]
}
JSON

FOLDER_DECISIONS="$TMPDIR_TEST/folder_decisions.json"
resolve_candidate_folder_decisions "$CANDIDATE_FOLDER" "$FOLDER_MAPPING" false "$FOLDER_DECISIONS"

unmapped_count=$(jq '.unmapped | length' "$FOLDER_DECISIONS")
[ "$unmapped_count" -eq 1 ] \
  && pass "Test 15: unmapped candidate 會被列出且不靜默 root fallback" \
  || fail_test "Test 15: unmapped_count 期待 1，得到 $unmapped_count"

explicit_folder=$(jq -r '.decisions[] | select(.path == "/api/admin/invoices") | .resolved_folder_id' "$FOLDER_DECISIONS")
explicit_source=$(jq -r '.decisions[] | select(.path == "/api/admin/invoices") | .folder_source' "$FOLDER_DECISIONS")
[ "$explicit_folder" = "1417999" ] && [ "$explicit_source" = "candidate.folder_id" ] \
  && pass "Test 16: candidate folder_id override 優先" \
  || fail_test "Test 16: explicit folder=$explicit_folder source=$explicit_source"

prefix_folder=$(jq -r '.decisions[] | select(.path == "/api/admin/users/export") | .resolved_folder_id' "$FOLDER_DECISIONS")
prefix_source=$(jq -r '.decisions[] | select(.path == "/api/admin/users/export") | .folder_source' "$FOLDER_DECISIONS")
[ "$prefix_folder" = "1417834" ] && [ "$prefix_source" = "api_tree_prefix" ] \
  && pass "Test 17: 新 endpoint 可用 longest-prefix mapping" \
  || fail_test "Test 17: prefix folder=$prefix_folder source=$prefix_source"

FOLDER_DECISIONS_ROOT="$TMPDIR_TEST/folder_decisions_root.json"
resolve_candidate_folder_decisions "$CANDIDATE_FOLDER" "$FOLDER_MAPPING" true "$FOLDER_DECISIONS_ROOT"
root_source=$(jq -r '.decisions[] | select(.path == "/api/unknown") | .folder_source' "$FOLDER_DECISIONS_ROOT")
root_folder=$(jq -r '.decisions[] | select(.path == "/api/unknown") | .resolved_folder_id' "$FOLDER_DECISIONS_ROOT")
[ "$root_folder" = "0" ] && [ "$root_source" = "root_fallback" ] \
  && pass "Test 18: 明確允許時才使用 root fallback" \
  || fail_test "Test 18: root folder=$root_folder source=$root_source"

FULL_FOLDER_SPEC="$TMPDIR_TEST/full_folder.json"
cat > "$FULL_FOLDER_SPEC" <<'JSON'
{
  "openapi": "3.1.0",
  "info": { "title": "Folder API", "version": "1.0.0" },
  "paths": {
    "/api/admin/users": { "get": { "summary": "List admin users" } },
    "/api/admin/users/export": { "get": { "summary": "Export admin users" } },
    "/api/admin/invoices": { "post": { "summary": "Create invoice" } },
    "/api/unknown": { "get": { "summary": "Unknown" } }
  }
}
JSON

GROUP_1417834="$(jq -c '.groups[] | select(.folder_id == 1417834) | .candidates' "$FOLDER_DECISIONS_ROOT")"
OUT_FOLDER_BATCH="$TMPDIR_TEST/out_folder_batch.json"
build_subset_spec_from_candidates_json "$FULL_FOLDER_SPEC" "$GROUP_1417834" "$OUT_FOLDER_BATCH" 2>/dev/null
batch_paths=$(jq -r '(.paths | keys) | join(",")' "$OUT_FOLDER_BATCH")
[ "$batch_paths" = "/api/admin/users,/api/admin/users/export" ] \
  && pass "Test 19: folder batch payload 只包含該 folder candidates" \
  || fail_test "Test 19: batch paths=$batch_paths"

# ── check_path_strategy_alignment ────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " check_path_strategy_alignment 測試"
echo "═══════════════════════════════════════"

LOCAL_SPEC_JSON_FILE="$FULL_SPEC"

# 策略一致
PATH_STRATEGY="keep-full-path"
SKIP_ALIGNMENT_CHECK=false
if check_path_strategy_alignment "$REMOTE_KEEP_FULL" 2>/dev/null; then
  pass "Test 7: 策略一致（keep-full-path == keep-full-path）→ 靜默通過"
else
  fail_test "Test 7: 期待 exit 0（策略一致）"
fi

# 策略不一致
PATH_STRATEGY="strip-api-prefix-to-server"
SKIP_ALIGNMENT_CHECK=false
set +e
(check_path_strategy_alignment "$REMOTE_KEEP_FULL" 2>/dev/null)
alignment_status=$?
set -uo pipefail
if [ "$alignment_status" -eq 0 ]; then
  fail_test "Test 8: 策略不一致應阻擋，但通過了"
else
  pass "Test 8: 策略不一致（strip vs keep-full）→ 正確阻擋"
fi

# remote paths 為空 → 靜默跳過
PATH_STRATEGY="keep-full-path"
SKIP_ALIGNMENT_CHECK=false
if check_path_strategy_alignment "$REMOTE_EMPTY" 2>/dev/null; then
  pass "Test 9: remote paths 為空 → 靜默跳過（全新專案）"
else
  fail_test "Test 9: remote 為空應靜默通過，但被阻擋"
fi

# SKIP_ALIGNMENT_CHECK=true → 無論策略差異都通過
PATH_STRATEGY="strip-api-prefix-to-server"
SKIP_ALIGNMENT_CHECK=true
if check_path_strategy_alignment "$REMOTE_KEEP_FULL" 2>/dev/null; then
  pass "Test 10: SKIP_ALIGNMENT_CHECK=true → 強制通過"
else
  fail_test "Test 10: 設定 skip 後應通過"
fi

# PATH_STRATEGY 未設定 → 靜默跳過
PATH_STRATEGY=""
SKIP_ALIGNMENT_CHECK=false
if check_path_strategy_alignment "$REMOTE_KEEP_FULL" 2>/dev/null; then
  pass "Test 11: PATH_STRATEGY 未設定 → 靜默跳過"
else
  fail_test "Test 11: PATH_STRATEGY 空時應靜默通過"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
printf " 結果：${c_green}%d PASS${c_reset}  ${c_red}%d FAIL${c_reset}\n" "$PASS" "$FAIL"
echo "═══════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ]
