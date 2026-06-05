#!/bin/bash
set -euo pipefail

# 產出互動式 HTML 文件（Redoc，多頁版）
# 預設：
# - 輸入：docs/api-docs/openapi.yaml（若不存在且 docs/openapi.yaml 存在則回退）
# - 輸出：docs/api-docs/redoc/index.html 與 docs/api-docs/redoc/api-docs.html

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/progress-lib.sh"

OPENAPI_FILE="docs/api-docs/openapi.yaml"
DEFAULT_OUTPUT_FILE="docs/api-docs/redoc/api-docs.html"
OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
EXTRA_FILE="docs/api-docs/redoc/extra.md"
VERSION_ROOT="docs/api-docs/versions"
WITH_EXTRA=false
PROGRESS_ENABLED=1
GUIDED_TIMING_FILE="$(mktemp)"
MARKDOWN_RENDERER="$SCRIPT_DIR/../bin/render-markdown.php"
VERSION_DIR=""
VERSION_EXTRA_FILE=""
EXTRA_RENDER_FILE=""

usage() {
  cat <<'USAGE'
Usage: gen-html.sh [options]

Options:
  --openapi FILE   OpenAPI YAML file path
  --output FILE    API reference HTML path (default: docs/api-docs/redoc/api-docs.html)
  --with-extra     Render docs/api-docs/redoc/extra.md into the summary home page
  --extra-file FILE  Override extra markdown file path
  --no-progress    Disable progress output
  -h, --help       Show help
USAGE
}

create_version_dir() {
  local version_id
  local candidate
  local counter

  version_id="$(date '+%Y%m%d-%H%M%S')"
  candidate="$VERSION_ROOT/$version_id"
  counter=2

  while [ -e "$candidate" ]; do
    candidate="$VERSION_ROOT/${version_id}-${counter}"
    counter=$((counter + 1))
  done

  mkdir -p "$candidate/redoc"
  printf '%s' "$candidate"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      OPENAPI_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --with-extra)
      WITH_EXTRA=true
      shift
      ;;
    --extra-file)
      EXTRA_FILE="$2"
      WITH_EXTRA=true
      shift 2
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
      echo "未知參數：$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

guided_progress_set_enabled "$PROGRESS_ENABLED"
trap 'rm -f "$GUIDED_TIMING_FILE" "$EXTRA_RENDER_FILE"' EXIT

guided_progress_emit "generate_html" "validate_input" "in_progress" 0 3 "starting html generation"
guided_timing_begin "html_total"

if [ ! -f "$OPENAPI_FILE" ] && [ "$OPENAPI_FILE" = "docs/api-docs/openapi.yaml" ] && [ -f "docs/openapi.yaml" ]; then
  OPENAPI_FILE="docs/openapi.yaml"
fi

if [ ! -f "$OPENAPI_FILE" ]; then
  echo "錯誤：找不到 $OPENAPI_FILE" >&2
  echo "請先執行 gen-openapi.sh 產出 OpenAPI 文件" >&2
  exit 1
fi

if [ "$WITH_EXTRA" = true ]; then
  if [ ! -f "$MARKDOWN_RENDERER" ]; then
    echo "錯誤：找不到 Markdown renderer：$MARKDOWN_RENDERER" >&2
    exit 1
  fi

  if [ ! -f "$EXTRA_FILE" ]; then
    echo "錯誤：找不到額外內容檔案 $EXTRA_FILE" >&2
    exit 1
  fi

  EXTRA_RENDER_FILE="$(mktemp)"
  cp "$EXTRA_FILE" "$EXTRA_RENDER_FILE"
fi

echo "正在產出互動式 HTML 文件..." >&2
guided_progress_emit "generate_html" "validate_input" "in_progress" 1 3 "openapi ready"
guided_timing_begin "render_html"
OPENAPI_JSON="$(yq -o=json '.' "$OPENAPI_FILE" | jq -c .)"
EXTRA_HTML=""
HOME_FILE="$(dirname "$OUTPUT_FILE")/index.html"
if [ "$WITH_EXTRA" = true ]; then
  EXTRA_HTML="$(php -n "$MARKDOWN_RENDERER" "$EXTRA_RENDER_FILE")"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
TEMP_OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$GUIDED_TIMING_FILE" "$TEMP_OUTPUT_FILE" "$EXTRA_RENDER_FILE"' EXIT

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
        <p>這頁只保留純 API 規格。若有同步摘要、錯誤碼整理或閱讀導覽，請改看首頁。</p>
      </div>
      <div class="reference-actions">
        <a href="./index.html">返回摘要首頁</a>
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

mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"

HOME_TEMP_OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$GUIDED_TIMING_FILE" "$TEMP_OUTPUT_FILE" "$HOME_TEMP_OUTPUT_FILE" "$EXTRA_RENDER_FILE"' EXIT

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
    .stat-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
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
      .stat-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="page-shell">
    <section class="hero">
      <article class="hero-main">
        <span class="eyebrow">Sync Summary</span>
        <h1>API 文件首頁</h1>
        <p>這頁專門承接同步摘要、錯誤碼整理、變更說明與對接提醒。API 規格本體拆到另一頁，避免 Redoc 參考文件與補充說明混在同一條閱讀流。</p>
        <div class="hero-actions">
          <a class="primary" href="./api-docs.html">進入 API Reference</a>
          <a class="secondary" href="#summary-content">查看本次摘要</a>
        </div>
      </article>
      <aside class="hero-side">
        <div class="stat-grid">
          <div class="stat-card">
            <strong>26</strong>
            <span>本輪同步 API 數量</span>
          </div>
          <div class="stat-card">
            <strong>22</strong>
            <span>本次新增錯誤碼</span>
          </div>
          <div class="stat-card">
            <strong>3</strong>
            <span>錯誤碼功能分段</span>
          </div>
          <div class="stat-card">
            <strong>2</strong>
            <span>文件頁：首頁 + API Reference</span>
          </div>
        </div>
      </aside>
    </section>

    <section class="content-shell">
      <main class="content-main" id="summary-content">
HOME_HEAD
if [ "$WITH_EXTRA" = true ]; then
  printf '%s\n' "$EXTRA_HTML" >> "$HOME_TEMP_OUTPUT_FILE"
else
  cat >> "$HOME_TEMP_OUTPUT_FILE" <<'HOME_EMPTY'
        <h2>本次摘要</h2>
        <p>這次沒有額外補充內容。首頁保留成為固定入口頁，讓分享時始終有一致的 landing page；若要補充同步摘要、錯誤碼整理、認證方式或對接提醒，可在下一次生成前提供補充內容。</p>
        <ul>
          <li>這裡適合放：同步摘要、錯誤碼整理、Base URL、認證方式、對接提醒。</li>
          <li>完整 request / response / schema / security 規格，請進入 API Reference。</li>
        </ul>
HOME_EMPTY
fi
cat >> "$HOME_TEMP_OUTPUT_FILE" <<'HOME_TAIL'
      </main>
      <aside class="content-nav">
        <h2>快速導覽</h2>
        <a href="#summary-content">回到摘要起點</a>
        <a href="./api-docs.html">查看完整 API 規格</a>
      </aside>
    </section>
  </div>
</body>
</html>
HOME_TAIL

mv "$HOME_TEMP_OUTPUT_FILE" "$HOME_FILE"

if [ "$OUTPUT_FILE" = "$DEFAULT_OUTPUT_FILE" ]; then
  VERSION_DIR="$(create_version_dir)"
  cp "$OPENAPI_FILE" "$VERSION_DIR/openapi.yaml"
  cp "$HOME_FILE" "$VERSION_DIR/redoc/index.html"
  cp "$OUTPUT_FILE" "$VERSION_DIR/redoc/api-docs.html"
  if [ "$WITH_EXTRA" = true ]; then
    VERSION_EXTRA_FILE="$VERSION_DIR/redoc/extra.md"
    cp "$EXTRA_RENDER_FILE" "$VERSION_EXTRA_FILE"
  fi
fi

guided_timing_end "gen-html" "render_html" "output=$OUTPUT_FILE"
guided_progress_emit "generate_html" "render_html" "in_progress" 2 3 "html rendered"
guided_timing_end "gen-html" "html_total" "output=$OUTPUT_FILE"
TIMINGS_JSON="$(guided_timing_json)"
guided_progress_emit "generate_html" "complete" "done" 3 3 "html generation complete"
echo "HTML 文件已產出：$OUTPUT_FILE" >&2
echo "首頁文件已產出：$HOME_FILE" >&2
echo "  - 使用 Redoc v2.1.3（固定版本，確保穩定）" >&2
echo "  - 支援 Markdown 擴充（可在 description 加入流程圖、圖片）" >&2
if [ "$WITH_EXTRA" = true ]; then
  echo "  - 已載入額外內容：$EXTRA_FILE" >&2
else
  echo "  - 未提供額外內容，首頁以固定導覽版型輸出" >&2
fi
if [ -n "$VERSION_DIR" ]; then
  echo "  - 已建立版本備份：$VERSION_DIR" >&2
  if [ -n "$VERSION_EXTRA_FILE" ]; then
    echo "  - 已建立額外內容版本備份：$VERSION_EXTRA_FILE" >&2
  fi
else
  echo "  - 自訂輸出路徑不建立正式版本備份" >&2
fi
echo "  - 可直接用瀏覽器開啟，無需啟動伺服器" >&2

jq -n \
  --arg file "$OUTPUT_FILE" \
  --arg home_file "$HOME_FILE" \
  --arg extra_file "$EXTRA_FILE" \
  --arg version_dir "$VERSION_DIR" \
  --arg version_extra_file "$VERSION_EXTRA_FILE" \
  --argjson with_extra "$(if [ "$WITH_EXTRA" = true ]; then echo true; else echo false; fi)" \
  --argjson timings "$TIMINGS_JSON" \
  '{
    file: $file,
    home_file: $home_file,
    extra_file: (if $with_extra then $extra_file else null end),
    version_dir: (if $version_dir == "" then null else $version_dir end),
    version_extra_file: (if $version_extra_file == "" then null else $version_extra_file end),
    with_extra: $with_extra,
    timings: $timings,
    message: "已產出摘要首頁與 Redoc API 文件"
  }'
