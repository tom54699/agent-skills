#!/bin/bash
# Apidog 腳本共用函式，由 export-remote.sh、list-folders.sh、upload-apidog.sh source。
# 需在 Laravel 專案根目錄執行；憑證從 .env.agents 讀取。

APIDOG_API_VERSION="2024-03-28"

# jq 共用函式：在 jq filter 前面接上 "$JQ_DEFS"。
JQ_DEFS='
def method_keys: ["get", "put", "post", "delete", "options", "head", "patch", "trace"];
def is_method_key: . as $k | method_keys | any(. == $k);

# 收集所有指向 #/components/ 的 $ref。
def component_refs:
  [.. | objects | ."$ref"? | strings | select(startswith("#/components/"))] | unique;

def ref_path:
  ltrimstr("#/components/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~"));

# 從 $refs 出發，把 components 之間的間接引用也收進來，直到不再增加。
def ref_closure($all; $refs):
  ([$refs[] as $r | ($all | getpath($r | ref_path)) // empty | component_refs[]] + $refs | unique) as $next
  | if ($next | length) == ($refs | length) then $refs else ref_closure($all; $next) end;

# 只保留被引用到的 components；securitySchemes 以名稱引用，整段保留。
def prune_components:
  if (.components | type) != "object" then .
  else
    .components as $all
    | ref_closure($all; (del(.components) | component_refs)) as $refs
    | .components = (
        reduce $refs[] as $r ({};
          ($r | ref_path) as $p
          | ($all | getpath($p)) as $v
          | if $v != null then setpath($p; $v) else . end)
        + (if $all.securitySchemes then {securitySchemes: $all.securitySchemes} else {} end)
      )
  end;

# 只保留 $eps（[{method, path}]，method 小寫）列出的 operation，並同步過濾 tags。
def filter_endpoints($eps):
  .paths = ((.paths // {}) | with_entries(
      .key as $p
      | ($eps | map(select(.path == $p) | .method)) as $ms
      | .value |= with_entries(select((.key | is_method_key | not) or (.key as $k | $ms | any(. == $k))))
      | select([.value | keys[] | select(is_method_key)] | length > 0)
    ))
  | ([.paths[][] | objects | .tags? // [] | .[]] | unique) as $used
  | if (.tags | type) == "array" then .tags |= map(select(.name as $n | $used | any(. == $n))) else . end;

def strip_apidog_folder:
  .paths |= map_values(with_entries(
    if (.key | is_method_key) and (.value | type) == "object" then .value |= del(."x-apidog-folder") else . end));

# 把 api-tree-list 回應攤平成 {folders: [{id, path}], apis: [{method, path, folder_id, folder_path}]}。
def flatten_tree:
  def node_type: (.type // .nodeType // "");
  def node_key: ((.key // .id // "") | tostring);
  def is_folder: node_type == "apiDetailFolder" or (node_key | startswith("apiDetailFolder."));
  def is_api: node_type == "apiDetail" or ((.api? | type) == "object" and ((.api.path? // "") != ""));
  def folder_id: ((node_key | capture("(?<id>[0-9]+)$") | .id | tonumber) // .folder.id? // null);
  def folder_name: (.name // .folder.name? // .title // "");
  def children: (.children // .items // .list // []);
  def walk_node($fid; $fpath):
    if is_folder then
      folder_id as $id
      | (if $fpath == "" then folder_name else $fpath + "/" + folder_name end) as $p
      | {kind: "folder", id: $id, path: $p}, (children[]? | walk_node($id; $p))
    elif is_api then
      {
        kind: "api",
        method: ((.api.method // .method // "") | ascii_downcase),
        path: (.api.path // .path // ""),
        folder_id: ((.api.folderId // .folderId // $fid) | if type == "string" then (tonumber? // .) else . end),
        folder_path: $fpath
      }
    else
      children[]? | walk_node($fid; $fpath)
    end;
  (if type == "array" then .
   elif (.data | type) == "array" then .data
   elif (.data | type) == "object" then [.data]
   else [] end) as $roots
  | [$roots[] | walk_node(0; "")] as $nodes
  | {
      folders: [$nodes[] | select(.kind == "folder") | {id, path}],
      apis: [$nodes[] | select(.kind == "api") | {method, path, folder_id, folder_path}]
    };
'

fail() {
  echo "錯誤：$*" >&2
  exit 1
}

load_apidog_env() {
  if [ -f .env.agents ]; then
    # shellcheck disable=SC1091
    . ./.env.agents
  fi
  [ -n "${APIDOG_ACCESS_TOKEN:-}" ] || fail "找不到 APIDOG_ACCESS_TOKEN，請在專案根目錄的 .env.agents 設定"
  [ -n "${APIDOG_PROJECT_ID:-}" ] || fail "找不到 APIDOG_PROJECT_ID，請在專案根目錄的 .env.agents 設定"
}

# 用法：apidog_request <GET|POST> <url> <output_file> [body_file]
apidog_request() {
  local method="$1"
  local url="$2"
  local output_file="$3"
  local body_file="${4:-}"
  local http_code
  local args=(-s -w "%{http_code}" -o "$output_file" -X "$method" "$url"
    -H "Authorization: Bearer $APIDOG_ACCESS_TOKEN"
    -H "X-Apidog-Api-Version: $APIDOG_API_VERSION")

  if [ -n "$body_file" ]; then
    args+=(-H "Content-Type: application/json" -d @"$body_file")
  fi

  http_code="$(curl "${args[@]}")" || fail "無法連線 Apidog：$url"
  case "$http_code" in
    200|201)
      return 0
      ;;
  esac

  cat "$output_file" >&2 || true
  echo >&2
  fail "Apidog 回應 HTTP ${http_code}：$url"
}

# YAML 或 JSON spec 轉成單行 JSON；無法解析時失敗。
spec_to_json() {
  local input_file="$1"
  local output_file="$2"

  [ -f "$input_file" ] || fail "找不到 spec 檔：$input_file"
  if jq -e 'type == "object"' "$input_file" >/dev/null 2>&1; then
    jq -c . "$input_file" >"$output_file"
    return 0
  fi
  if yq -o=json '.' "$input_file" 2>/dev/null | jq -e 'type == "object"' >/dev/null 2>&1; then
    yq -o=json '.' "$input_file" | jq -c . >"$output_file"
    return 0
  fi
  fail "無法解析 spec 檔：$input_file"
}

# 匯出整個專案的 OpenAPI（含 Apidog extensions），輸出單行 JSON。
export_remote_spec() {
  local output_file="$1"
  local request_file
  local response_file
  request_file="$(mktemp)"
  response_file="$(mktemp)"

  jq -n '{
    scope: {type: "ALL"},
    options: {includeApidogExtensionProperties: true, addFoldersToTags: false},
    oasVersion: "3.1",
    exportFormat: "JSON"
  }' >"$request_file"

  apidog_request POST "https://api.apidog.com/v1/projects/$APIDOG_PROJECT_ID/export-openapi?locale=en-US" "$response_file" "$request_file"
  rm -f "$request_file"

  if jq -e '.data.content? | type == "string"' "$response_file" >/dev/null 2>&1; then
    jq -r '.data.content' "$response_file" | jq -c . >"$output_file"
  elif jq -e '.data.content? | type == "object"' "$response_file" >/dev/null 2>&1; then
    jq -c '.data.content' "$response_file" >"$output_file"
  elif jq -e '.data.openapi? | type == "object"' "$response_file" >/dev/null 2>&1; then
    jq -c '.data.openapi' "$response_file" >"$output_file"
  elif jq -e '.openapi? != null or .paths? != null' "$response_file" >/dev/null 2>&1; then
    jq -c . "$response_file" >"$output_file"
  else
    cat "$response_file" >&2 || true
    rm -f "$response_file"
    fail "Apidog export-openapi 回應格式無法辨識"
  fi
  rm -f "$response_file"
}

# 抓 API tree 並攤平（見 JQ_DEFS 的 flatten_tree）。api-tree-list 必須用 /api/v1/ 前綴。
fetch_flat_tree() {
  local output_file="$1"
  local response_file
  response_file="$(mktemp)"

  apidog_request GET "https://api.apidog.com/api/v1/projects/$APIDOG_PROJECT_ID/api-tree-list" "$response_file"
  if ! jq -e '(type == "array") or (.data != null)' "$response_file" >/dev/null 2>&1; then
    cat "$response_file" >&2 || true
    rm -f "$response_file"
    fail "Apidog API tree 回應格式無法辨識"
  fi

  jq -c "$JQ_DEFS flatten_tree" "$response_file" >"$output_file"
  rm -f "$response_file"
}
