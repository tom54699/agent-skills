#!/bin/bash
set -euo pipefail

# 產出本次的 Redoc 文件：
# - index.html：業務邏輯首頁（由 business.md 產生）
# - api-docs.html：本次 API 的 Redoc 規格頁

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKDOWN_RENDERER="$SCRIPT_DIR/../bin/render-markdown.php"

OPENAPI_FILE=""
BUSINESS_FILE=""
OUTPUT_DIR=""

usage() {
  cat <<'USAGE'
Usage: gen-html.sh --openapi FILE --business-md FILE --output-dir DIR

Options:
  --openapi FILE      本次的 spec（YAML 或 JSON）
  --business-md FILE  首頁內容（目的、需求、業務邏輯、前端要改什麼）
  --output-dir DIR    輸出資料夾，產出 index.html 與 api-docs.html
  -h, --help          Show help
USAGE
}

fail() {
  echo "錯誤：$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      [ $# -ge 2 ] || fail "--openapi 需要值"
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --business-md)
      [ $# -ge 2 ] || fail "--business-md 需要值"
      BUSINESS_FILE="$2"
      shift 2
      ;;
    --output-dir)
      [ $# -ge 2 ] || fail "--output-dir 需要值"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "未知參數：$1"
      ;;
  esac
done

[ -n "$OPENAPI_FILE" ] && [ -f "$OPENAPI_FILE" ] || fail "找不到 --openapi 指定的 spec：${OPENAPI_FILE:-（未指定）}"
[ -n "$BUSINESS_FILE" ] && [ -f "$BUSINESS_FILE" ] || fail "找不到 --business-md 指定的首頁內容：${BUSINESS_FILE:-（未指定）}"
[ -n "$OUTPUT_DIR" ] || fail "需要 --output-dir"
[ -f "$MARKDOWN_RENDERER" ] || fail "找不到 Markdown renderer：$MARKDOWN_RENDERER"

if jq -e 'type == "object"' "$OPENAPI_FILE" >/dev/null 2>&1; then
  OPENAPI_JSON="$(jq -c . "$OPENAPI_FILE")"
else
  OPENAPI_JSON="$(yq -o=json '.' "$OPENAPI_FILE" | jq -c .)" || fail "無法解析 spec：$OPENAPI_FILE"
fi

API_ENDPOINT_COUNT="$(printf '%s' "$OPENAPI_JSON" | jq '[.paths // {} | to_entries[] | .value | to_entries[] | select(.key | test("^(get|put|post|delete|options|head|patch|trace)$"))] | length')"
API_LIST_HTML="$(printf '%s' "$OPENAPI_JSON" | jq -r '
  [.paths // {} | to_entries[] | .key as $path | .value | to_entries[]
    | select(.key | test("^(get|put|post|delete|options|head|patch|trace)$"))
    | "          <li><code>\(.key | ascii_upcase)</code> \($path | @html)"
      + (if (.value.summary // "") != "" then " — \(.value.summary | @html)" else "" end)
      + "</li>"]
  | join("\n")')"
PAGE_TITLE="$(awk '/^# /{sub(/^# +/, ""); print; exit}' "$BUSINESS_FILE")"
[ -n "$PAGE_TITLE" ] || PAGE_TITLE="API 文件"
PAGE_TITLE_HTML="$(printf '%s' "$PAGE_TITLE" | jq -Rr @html)"
BUSINESS_HTML="$(php -n "$MARKDOWN_RENDERER" "$BUSINESS_FILE")"

mkdir -p "$OUTPUT_DIR"
API_DOCS_FILE="$OUTPUT_DIR/api-docs.html"
HOME_FILE="$OUTPUT_DIR/index.html"
TEMP_OUTPUT_FILE="$(mktemp)"
HOME_TEMP_OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$TEMP_OUTPUT_FILE" "$HOME_TEMP_OUTPUT_FILE"' EXIT

echo "產出 Redoc 文件..." >&2

cat > "$TEMP_OUTPUT_FILE" <<'REDOC_HEAD'
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API 文件</title>
  <style>
    * {
      box-sizing: border-box;
    }
    html, body {
      min-height: 100%;
    }
    body {
      margin: 0;
      background: linear-gradient(180deg, #f5f7fb 0%, #eef2f8 100%);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Microsoft JhengHei", sans-serif;
      color: #0f172a;
    }
    .reference-shell {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    .reference-head {
      display: flex;
      justify-content: space-between;
      gap: 20px;
      align-items: center;
      padding: 18px 22px;
      border-bottom: 1px solid #dbe3f0;
      background: rgba(255, 255, 255, 0.88);
      backdrop-filter: blur(12px);
      position: sticky;
      top: 0;
      z-index: 20;
    }
    .reference-head h1 {
      margin: 0 0 4px;
      font-size: 24px;
      line-height: 1.1;
    }
    .reference-head p {
      margin: 0;
      color: #64748b;
      font-size: 13px;
      line-height: 1.6;
    }
    .reference-actions {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    .reference-actions a {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      text-decoration: none;
      padding: 10px 14px;
      border-radius: 999px;
      border: 1px solid #cbd5e1;
      background: #ffffff;
      color: #0f172a;
      font-size: 13px;
      font-weight: 600;
      box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
    }
    #redoc-root {
      min-height: calc(100vh - 82px);
    }
    @media (max-width: 780px) {
      .reference-head {
        flex-direction: column;
        align-items: flex-start;
      }
    }
  </style>
</head>
<body>
REDOC_HEAD

cat >> "$TEMP_OUTPUT_FILE" <<'REDOC_BODY'
  <div class="reference-shell">
    <header class="reference-head">
      <div>
        <h1>API Reference</h1>
        <p>這頁只放本次的 API 規格；目的、需求與業務邏輯請看首頁。</p>
      </div>
      <div class="reference-actions">
        <a href="./index.html">返回首頁</a>
      </div>
    </header>
    <div id="redoc-root"></div>
  </div>

  <!-- 使用固定版本的 Redoc v2.1.3，確保穩定性 -->
  <script src="https://cdn.redoc.ly/redoc/v2.1.3/bundles/redoc.standalone.js"></script>
  <script>
    // 內嵌 OpenAPI spec
    const spec = 
REDOC_BODY

printf '%s' "$OPENAPI_JSON" >> "$TEMP_OUTPUT_FILE"

cat >> "$TEMP_OUTPUT_FILE" <<'REDOC_TAIL'
;

    Redoc.init(spec, {
      scrollYOffset: 50,
      hideDownloadButton: false,
      theme: {
        colors: {
          primary: {
            main: '#3b82f6'
          }
        },
        typography: {
          fontSize: '14px',
          fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Microsoft JhengHei", sans-serif',
          headings: {
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Microsoft JhengHei", sans-serif'
          }
        }
      },
      // 支援 Markdown 擴充功能
      expandResponses: '200,201',
      jsonSampleExpandLevel: 2,
      hideSingleRequestSampleTab: true,
      menuToggle: true,
      nativeScrollbars: false,
      pathInMiddlePanel: false,
      requiredPropsFirst: true,
      sortPropsAlphabetically: false
    }, document.querySelector('#redoc-root'));
  </script>
</body>
</html>
REDOC_TAIL

mv "$TEMP_OUTPUT_FILE" "$API_DOCS_FILE"

cat > "$HOME_TEMP_OUTPUT_FILE" <<'HOME_HEAD'
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>API 文件首頁</title>
  <style>
    :root {
      --paper: #f7f2ea;
      --surface: rgba(255, 252, 247, 0.88);
      --line: #d9d0c3;
      --ink: #1f2937;
      --muted: #64748b;
      --accent: #0f766e;
      --accent-soft: #d8f2ee;
      --shadow: 0 18px 42px rgba(15, 23, 42, 0.08);
      --code-bg: #efe7db;
      --table-head: #eee5d8;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(255, 255, 255, 0.72), transparent 28%),
        linear-gradient(180deg, #f8f3ec 0%, #f1ece3 100%);
      font-family: "Avenir Next", "PingFang TC", "Microsoft JhengHei", sans-serif;
    }
    .page-shell {
      max-width: 1320px;
      margin: 0 auto;
      padding: 28px 20px 48px;
    }
    .hero {
      display: grid;
      grid-template-columns: minmax(0, 1.2fr) minmax(280px, 0.8fr);
      gap: 18px;
      align-items: stretch;
      margin-bottom: 24px;
    }
    .hero-main,
    .hero-side {
      border: 1px solid var(--line);
      border-radius: 28px;
      background: var(--surface);
      box-shadow: var(--shadow);
      overflow: hidden;
    }
    .hero-main {
      padding: 28px;
      background:
        linear-gradient(135deg, rgba(15, 118, 110, 0.12) 0%, rgba(255, 255, 255, 0) 46%),
        linear-gradient(180deg, rgba(255, 255, 255, 0.82) 0%, rgba(255, 252, 247, 0.94) 100%);
    }
    .hero-side {
      padding: 24px;
      display: grid;
      gap: 14px;
      align-content: start;
    }
    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      background: var(--accent-soft);
      color: #115e59;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .hero-main h1 {
      margin: 18px 0 10px;
      font-size: 48px;
      line-height: 0.98;
      letter-spacing: -0.04em;
      font-family: "Iowan Old Style", "Palatino Linotype", "Noto Serif TC", serif;
    }
    .hero-main p {
      margin: 0;
      max-width: 60ch;
      color: #475569;
      line-height: 1.8;
      font-size: 15px;
    }
    .hero-actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      margin-top: 20px;
    }
    .hero-actions a {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 12px 16px;
      border-radius: 999px;
      text-decoration: none;
      font-weight: 700;
      font-size: 14px;
    }
    .hero-actions .primary {
      background: #0f766e;
      color: #ffffff;
    }
    .hero-actions .secondary {
      border: 1px solid #cbd5e1;
      background: #ffffff;
      color: #0f172a;
    }
    .stat-card {
      padding: 14px;
      border-radius: 18px;
      border: 1px solid rgba(217, 208, 195, 0.9);
      background: rgba(255, 255, 255, 0.72);
    }
    .stat-card strong {
      display: block;
      margin-bottom: 6px;
      font-size: 28px;
      line-height: 1;
      font-family: "Avenir Next Condensed", "Avenir Next", "PingFang TC", sans-serif;
    }
    .stat-card span {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
    }
    .api-list {
      margin: 0;
      padding-left: 18px;
      color: #475569;
      font-size: 13px;
      line-height: 1.7;
      overflow-wrap: anywhere;
    }
    .api-list code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
      font-weight: 700;
      color: #115e59;
    }
    .content-shell {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 280px;
      gap: 18px;
    }
    .content-main,
    .content-nav {
      border: 1px solid var(--line);
      border-radius: 28px;
      background: var(--surface);
      box-shadow: var(--shadow);
    }
    .content-main {
      padding: 28px;
    }
    .content-nav {
      padding: 22px 20px;
      position: sticky;
      top: 20px;
      align-self: start;
    }
    .content-nav h2 {
      margin: 0 0 12px;
      font-size: 15px;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: #475569;
    }
    .content-nav a {
      display: block;
      padding: 10px 12px;
      border-radius: 14px;
      text-decoration: none;
      color: #0f172a;
      background: rgba(255, 255, 255, 0.68);
      border: 1px solid rgba(217, 208, 195, 0.8);
      margin-bottom: 10px;
      font-size: 14px;
      line-height: 1.5;
    }
    .content-main h1,
    .content-main h2,
    .content-main h3 {
      font-family: "Iowan Old Style", "Palatino Linotype", "Noto Serif TC", serif;
      letter-spacing: -0.02em;
      color: #111827;
    }
    .content-main h1 {
      display: none;
    }
    .content-main h2 {
      margin: 28px 0 14px;
      font-size: 28px;
    }
    .content-main h3 {
      margin: 22px 0 10px;
      font-size: 22px;
    }
    .content-main p,
    .content-main li {
      color: #475569;
      line-height: 1.8;
      font-size: 15px;
    }
    .content-main ul {
      padding-left: 18px;
    }
    .content-main code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
      background: var(--code-bg);
      color: #0f172a;
      border-radius: 999px;
      padding: 3px 8px;
      font-size: 13px;
    }
    .content-main pre {
      padding: 16px;
      overflow-x: auto;
      border-radius: 18px;
      background: #0f172a;
      color: #e2e8f0;
    }
    .content-main pre code {
      background: transparent;
      color: inherit;
      padding: 0;
      border-radius: 0;
    }
    .content-main table {
      width: 100%;
      border-collapse: collapse;
      margin: 14px 0 24px;
      overflow: hidden;
      border-radius: 18px;
      border: 1px solid rgba(217, 208, 195, 0.8);
    }
    .content-main th,
    .content-main td {
      padding: 12px 14px;
      text-align: left;
      vertical-align: top;
      border-bottom: 1px solid rgba(217, 208, 195, 0.7);
      font-size: 13px;
      line-height: 1.65;
    }
    .content-main th {
      background: var(--table-head);
      color: #334155;
      text-transform: uppercase;
      font-size: 11px;
      letter-spacing: 0.04em;
    }
    .content-main tr:nth-child(even) td {
      background: rgba(255, 255, 255, 0.58);
    }
    @media (max-width: 1080px) {
      .hero,
      .content-shell {
        grid-template-columns: 1fr;
      }
      .content-nav {
        position: relative;
        top: 0;
      }
    }
    @media (max-width: 720px) {
      .page-shell {
        padding: 14px 12px 28px;
      }
      .hero-main,
      .hero-side,
      .content-main,
      .content-nav {
        padding-left: 16px;
        padding-right: 16px;
      }
      .hero-main h1 {
        font-size: 34px;
      }
    }
  </style>
</head>
<body>
HOME_HEAD

cat >> "$HOME_TEMP_OUTPUT_FILE" <<HOME_HERO
  <div class="page-shell">
    <section class="hero">
      <article class="hero-main">
        <span class="eyebrow">Business Logic</span>
        <h1>${PAGE_TITLE_HTML}</h1>
        <p>這頁說明本次開發的目的、需求、業務邏輯，以及前端要配合的調整。各 API 的 request／response 規格請看 API Reference。</p>
        <div class="hero-actions">
          <a class="primary" href="./api-docs.html">進入 API Reference</a>
          <a class="secondary" href="#summary-content">查看業務邏輯</a>
        </div>
      </article>
      <aside class="hero-side">
        <div class="stat-card">
          <strong>${API_ENDPOINT_COUNT}</strong>
          <span>本次 API 數量</span>
        </div>
        <ul class="api-list">
${API_LIST_HTML}
        </ul>
      </aside>
    </section>

    <section class="content-shell">
      <main class="content-main" id="summary-content">
HOME_HERO
printf '%s\n' "$BUSINESS_HTML" >> "$HOME_TEMP_OUTPUT_FILE"
cat >> "$HOME_TEMP_OUTPUT_FILE" <<'HOME_TAIL'
      </main>
      <aside class="content-nav">
        <h2>快速導覽</h2>
        <a href="#summary-content">回到業務邏輯起點</a>
        <a href="./api-docs.html">查看 API 規格</a>
      </aside>
    </section>
  </div>
</body>
</html>
HOME_TAIL

mv "$HOME_TEMP_OUTPUT_FILE" "$HOME_FILE"

echo "首頁：$HOME_FILE" >&2
echo "API 規格：$API_DOCS_FILE" >&2

jq -n \
  --arg home_file "$HOME_FILE" \
  --arg api_docs_file "$API_DOCS_FILE" \
  --argjson endpoint_count "$API_ENDPOINT_COUNT" \
  '{home_file: $home_file, api_docs_file: $api_docs_file, endpoint_count: $endpoint_count}'
