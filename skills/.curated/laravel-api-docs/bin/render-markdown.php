<?php

declare(strict_types=1);

if ($argc < 2) {
    fwrite(STDERR, "Usage: php render-markdown.php <markdown-file>\n");
    exit(1);
}

$file = $argv[1];
if (!is_file($file)) {
    fwrite(STDERR, "Markdown file not found: {$file}\n");
    exit(1);
}

$lines = preg_split("/\r\n|\n|\r/", (string) file_get_contents($file));
$count = count($lines);
$index = 0;
$html = [];

while ($index < $count) {
    $line = rtrim($lines[$index]);
    $trimmed = trim($line);

    if ($trimmed === '') {
        $index++;
        continue;
    }

    if (preg_match('/^```/', $trimmed)) {
        $language = trim((string) preg_replace('/^```/', '', $trimmed));
        $index++;
        $codeLines = [];
        while ($index < $count && !preg_match('/^```/', trim($lines[$index]))) {
            $codeLines[] = rtrim($lines[$index], "\r");
            $index++;
        }
        if ($index < $count) {
            $index++;
        }
        $codeClass = $language !== '' ? ' class="language-' . escape_attr($language) . '"' : '';
        $html[] = '<pre><code' . $codeClass . '>' . escape_html(implode("\n", $codeLines)) . '</code></pre>';
        continue;
    }

    if (preg_match('/^(#{1,3})\s+(.*)$/', $trimmed, $matches)) {
        $level = strlen($matches[1]);
        $html[] = '<h' . $level . '>' . render_inline($matches[2]) . '</h' . $level . '>';
        $index++;
        continue;
    }

    if (is_table_start($lines, $index)) {
        [$tableHtml, $nextIndex] = render_table($lines, $index);
        $html[] = $tableHtml;
        $index = $nextIndex;
        continue;
    }

    if (preg_match('/^- /', $trimmed)) {
        $items = [];
        while ($index < $count) {
            $candidate = trim((string) $lines[$index]);
            if ($candidate === '' || !preg_match('/^- /', $candidate)) {
                break;
            }
            $items[] = '<li>' . render_inline(substr($candidate, 2)) . '</li>';
            $index++;
        }
        $html[] = '<ul>' . implode('', $items) . '</ul>';
        continue;
    }

    $paragraph = [$trimmed];
    $index++;
    while ($index < $count) {
        $candidate = trim((string) $lines[$index]);
        if ($candidate === '' || preg_match('/^(#{1,3})\s+/', $candidate) || preg_match('/^- /', $candidate) || preg_match('/^```/', $candidate) || is_table_start($lines, $index)) {
            break;
        }
        $paragraph[] = $candidate;
        $index++;
    }

    $html[] = '<p>' . render_inline(implode(' ', $paragraph)) . '</p>';
}

echo implode("\n", $html);

function render_table(array $lines, int $start): array
{
    $header = parse_table_row(trim((string) $lines[$start]));
    $index = $start + 2;
    $rows = [];

    while ($index < count($lines)) {
        $trimmed = trim((string) $lines[$index]);
        if ($trimmed === '' || strpos($trimmed, '|') === false) {
            break;
        }
        $rows[] = parse_table_row($trimmed);
        $index++;
    }

    $thead = '<thead><tr>' . implode('', array_map(
        static fn(string $cell): string => '<th>' . render_inline($cell) . '</th>',
        $header
    )) . '</tr></thead>';

    $tbodyRows = [];
    foreach ($rows as $row) {
        $cells = [];
        foreach ($row as $cell) {
            $cells[] = '<td>' . render_inline($cell) . '</td>';
        }
        $tbodyRows[] = '<tr>' . implode('', $cells) . '</tr>';
    }

    return ['<table>' . $thead . '<tbody>' . implode('', $tbodyRows) . '</tbody></table>', $index];
}

function parse_table_row(string $line): array
{
    $trimmed = trim($line);
    $trimmed = preg_replace('/^\|/', '', $trimmed);
    $trimmed = preg_replace('/\|$/', '', (string) $trimmed);
    return array_map(
        static fn(string $cell): string => trim($cell),
        explode('|', (string) $trimmed)
    );
}

function is_table_start(array $lines, int $index): bool
{
    if (!isset($lines[$index + 1])) {
        return false;
    }

    $current = trim((string) $lines[$index]);
    $next = trim((string) $lines[$index + 1]);

    return strpos($current, '|') !== false
        && preg_match('/^\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?$/', $next) === 1;
}

function render_inline(string $text): string
{
    $escaped = escape_html($text);
    $escaped = preg_replace('/`([^`]+)`/', '<code>$1</code>', $escaped);
    $escaped = preg_replace('/\*\*([^*]+)\*\*/', '<strong>$1</strong>', $escaped);
    return (string) $escaped;
}

function escape_html(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function escape_attr(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
