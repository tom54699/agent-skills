<?php

declare(strict_types=1);

require __DIR__ . '/../skills/laravel-api-docs/src/InferCandidates/bootstrap.php';

use LaravelApiDocs\InferCandidates\Analyzer;
use LaravelApiDocs\InferCandidates\AnalyzerOptions;
use LaravelApiDocs\InferCandidates\EventEmitter;
use LaravelApiDocs\InferCandidates\Shell;

function assertSameValue(mixed $expected, mixed $actual, string $message): void
{
    if ($expected !== $actual) {
        throw new RuntimeException($message . "\nExpected: " . var_export($expected, true) . "\nActual: " . var_export($actual, true));
    }
}

function assertTrueValue(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

/**
 * @return array{0:string,1:string,2:int}
 */
function runCommand(array $command, string $cwd, array $env = []): array
{
    $descriptorSpec = [
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open($command, $descriptorSpec, $pipes, $cwd, array_replace($_ENV, $env));
    if (!is_resource($process)) {
        throw new RuntimeException('Failed to start process: ' . implode(' ', $command));
    }

    $stdout = stream_get_contents($pipes[1]) ?: '';
    fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]) ?: '';
    fclose($pipes[2]);
    $code = proc_close($process);

    return [$stdout, $stderr, $code];
}

function mustRun(array $command, string $cwd, array $env = []): string
{
    [$stdout, $stderr, $code] = runCommand($command, $cwd, $env);
    if ($code !== 0) {
        throw new RuntimeException(sprintf(
            "Command failed (%d): %s\nSTDOUT:\n%s\nSTDERR:\n%s",
            $code,
            implode(' ', $command),
            $stdout,
            $stderr,
        ));
    }

    return $stdout;
}

function writeFile(string $path, string $content): void
{
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0777, true) && !is_dir($directory)) {
        throw new RuntimeException('Failed to create directory: ' . $directory);
    }

    file_put_contents($path, $content);
}

function removeDirectory(string $directory): void
{
    if (!is_dir($directory)) {
        return;
    }

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );

    /** @var SplFileInfo $item */
    foreach ($iterator as $item) {
        if ($item->isDir()) {
            rmdir($item->getPathname());
            continue;
        }

        unlink($item->getPathname());
    }

    rmdir($directory);
}

function createArtisan(string $repo): void
{
    $artisan = <<<'PHP'
<?php

if (($argv[1] ?? null) === 'route:list' && ($argv[2] ?? null) === '--json') {
    readfile(__DIR__ . '/route-list.json');
    exit(0);
}

fwrite(STDERR, "Unsupported artisan command\n");
exit(1);
PHP;

    writeFile($repo . '/artisan', $artisan . "\n");
}

function writeRouteFiles(string $repo): void
{
    writeFile($repo . '/routes/api.php', <<<'PHP'
<?php

use App\Http\Controllers\ReportController;
use Illuminate\Support\Facades\Route;

Route::get('reports', [ReportController::class, 'index']);
PHP
        . "\n");

    writeFile($repo . '/route-list.json', json_encode([
        [
            'method' => 'GET|HEAD',
            'uri' => 'api/reports',
            'action' => 'App\\Http\\Controllers\\ReportController@index',
        ],
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
}

function writeOpenApiBaseline(string $repo): void
{
    writeFile($repo . '/docs/api-docs/openapi.yaml', <<<'YAML'
openapi: 3.0.0
info:
  title: Contract Test API
  version: 1.0.0
paths:
  /reports:
    get:
      summary: index
      responses:
        '200':
          description: ok
YAML
        . "\n");
}

function writeDomainFiles(
    string $repo,
    string $description,
    string $serviceBody,
    string $exceptionMessage,
    string $docExtra = '',
    string $controllerBodyExtra = ''
): void
{
    writeFile($repo . '/app/Exceptions/ReportException.php', <<<PHP
<?php

namespace App\Exceptions;

class ReportException extends \RuntimeException
{
    public function __construct()
    {
        parent::__construct('{$exceptionMessage}', 422);
    }
}
PHP
        . "\n");

    writeFile($repo . '/app/Services/ReportService.php', <<<PHP
<?php

namespace App\Services;

class ReportService
{
    public function find(): array
    {
{$serviceBody}
    }
}
PHP
        . "\n");

    writeFile($repo . '/app/Http/Controllers/ReportController.php', <<<PHP
<?php

namespace App\Http\Controllers;

use App\Exceptions\ReportException;
use App\Services\ReportService;

class ReportController
{
    /**
     * {$description}
     * @queryParam status string 篩選狀態
{$docExtra}
     */
    public function index()
    {
        \$reportService = new ReportService();
        \$reportService->find();
{$controllerBodyExtra}

        throw new ReportException();
    }
}
PHP
        . "\n");
}

function gitCommit(string $repo, string $message, string $isoTime): string
{
    mustRun(['git', 'add', '.'], $repo);
    mustRun(
        ['git', 'commit', '-m', $message],
        $repo,
        [
            'GIT_AUTHOR_DATE' => $isoTime,
            'GIT_COMMITTER_DATE' => $isoTime,
        ]
    );

    return trim(mustRun(['git', 'rev-parse', 'HEAD'], $repo));
}

function commitTime(string $repo, string $commit): string
{
    return gmdate('Y-m-d\TH:i:s\Z', (int) trim(mustRun(['git', 'show', '-s', '--format=%ct', $commit], $repo)));
}

function writeHistoryRecord(string $repo, string $fileName, string $syncedAt, ?string $gitHeadCommit): string
{
    $record = [
        'sync_id' => 'sync-test',
        'synced_at' => $syncedAt,
        'from_time' => $syncedAt,
        'to_time' => $syncedAt,
        'git_head_commit' => $gitHeadCommit,
        'git_branch' => 'main',
        'path_strategy' => 'strip-api-prefix-to-server',
        'openapi_sha256' => 'test',
        'apidog_project_id' => '123',
        'imported_count' => 0,
        'updated_count' => 0,
        'skipped_count' => 0,
        'conflict_count' => 0,
        'status' => 'success',
    ];

    $path = $repo . '/docs/api-docs/history/' . $fileName;
    writeFile($path, json_encode($record, JSON_UNESCAPED_SLASHES) . "\n");

    return $path;
}

/**
 * @return array<string,mixed>
 */
function runAnalyzer(string $repo, string $historyFile = 'docs/api-docs/history/apidog-sync-history.jsonl'): array
{
    $options = new AnalyzerOptions(
        historyFile: $historyFile,
        openApiFile: 'docs/api-docs/openapi.yaml',
        fromCommit: null,
        pathStrategy: null,
        analysisMode: 'fast',
        lookbackCommits: 50,
        scanRoots: ['app'],
        debug: false,
        outputFile: null,
        progressEnabled: false,
        projectRoot: $repo,
    );

    $analyzer = new Analyzer($options, new EventEmitter(false, false), new Shell($repo));

    return $analyzer->run();
}

function findCandidate(array $result, string $status, string $method, string $path): ?array
{
    foreach ($result['candidates'] as $candidate) {
        if (
            ($candidate['status'] ?? null) === $status
            && ($candidate['method'] ?? null) === $method
            && ($candidate['path'] ?? null) === $path
        ) {
            return $candidate;
        }
    }

    return null;
}

function createFixtureRepository(): array
{
    $repo = sys_get_temp_dir() . '/laravel-api-docs-contract-test-' . bin2hex(random_bytes(4));
    if (!mkdir($repo, 0777, true) && !is_dir($repo)) {
        throw new RuntimeException('Failed to create temp repo');
    }

    createArtisan($repo);
    writeRouteFiles($repo);
    writeOpenApiBaseline($repo);
    writeDomainFiles(
        $repo,
        '初始報表查詢說明',
        "        \$cacheKey = 'report-cache';\n\n        return ['cache' => \$cacheKey];",
        '原始錯誤訊息'
    );

    mustRun(['git', 'init'], $repo);
    mustRun(['git', 'config', 'user.name', 'Test Runner'], $repo);
    mustRun(['git', 'config', 'user.email', 'test@example.com'], $repo);

    $commit1 = gitCommit($repo, 'baseline', '2026-03-18T01:00:00Z');
    $history1 = writeHistoryRecord($repo, 'apidog-sync-history.jsonl', commitTime($repo, $commit1), $commit1);

    return [
        'repo' => $repo,
        'commit1' => $commit1,
        'history1' => $history1,
    ];
}

$fixture = createFixtureRepository();
$repo = $fixture['repo'];

try {
    writeDomainFiles(
        $repo,
        '初始報表查詢說明',
        "        \$cacheKey = 'report-cache-v2';\n        \$normalized = strtoupper(\$cacheKey);\n\n        return ['cache' => \$normalized];",
        '原始錯誤訊息'
    );
    $commit2 = gitCommit($repo, 'service internal change', '2026-03-18T01:05:00Z');
    $internalOnly = runAnalyzer($repo, 'docs/api-docs/history/apidog-sync-history.jsonl');
    assertSameValue(0, $internalOnly['candidate_count'], 'internal-only service change must not create updated candidates');

    writeHistoryRecord($repo, 'after-service.jsonl', commitTime($repo, $commit2), $commit2);
    writeDomainFiles(
        $repo,
        '初始報表查詢說明',
        "        \$cacheKey = 'report-cache-v2';\n        \$normalized = strtoupper(\$cacheKey);\n\n        return ['cache' => \$normalized];",
        '原始錯誤訊息',
        '',
        "\n        \$displayLabel = 'report-v2';"
    );
    $commit3 = gitCommit($repo, 'controller body only change', '2026-03-18T01:10:00Z');
    $controllerBodyOnly = runAnalyzer($repo, 'docs/api-docs/history/after-service.jsonl');
    assertSameValue(0, $controllerBodyOnly['candidate_count'], 'controller body-only refactor must not create updated candidates');

    writeHistoryRecord($repo, 'after-controller-body.jsonl', commitTime($repo, $commit3), $commit3);
    writeDomainFiles(
        $repo,
        '更新後的報表查詢說明',
        "        \$cacheKey = 'report-cache-v2';\n        \$normalized = strtoupper(\$cacheKey);\n\n        return ['cache' => \$normalized];",
        '原始錯誤訊息',
        "     * @response 200 {\"message\":\"ok\"}"
    );
    $commit4 = gitCommit($repo, 'doc change', '2026-03-18T01:15:00Z');
    $docSurface = runAnalyzer($repo, 'docs/api-docs/history/after-controller-body.jsonl');
    $docCandidate = findCandidate($docSurface, 'updated', 'GET', '/reports');
    assertTrueValue($docCandidate !== null, 'function documentation annotation change should emit updated candidate');
    assertSameValue(true, $docCandidate['signals']['documentation_annotation_hit'] ?? null, 'doc change should be marked as documentation annotation hit');
    assertTrueValue(in_array('documentation_annotation', $docCandidate['signals']['strong_signal_types'] ?? [], true), 'doc change should be classified as strong documentation signal');

    writeHistoryRecord($repo, 'after-doc.jsonl', commitTime($repo, $commit4), $commit4);
    writeDomainFiles(
        $repo,
        '更新後的報表查詢說明',
        "        \$cacheKey = 'report-cache-v2';\n        \$normalized = strtoupper(\$cacheKey);\n\n        return ['cache' => \$normalized];",
        '新的錯誤訊息'
    );
    gitCommit($repo, 'exception contract change', '2026-03-18T01:20:00Z');
    $exceptionChange = runAnalyzer($repo, 'docs/api-docs/history/after-doc.jsonl');
    $exceptionCandidate = findCandidate($exceptionChange, 'updated', 'GET', '/reports');
    assertTrueValue($exceptionCandidate !== null, 'exception contract change should still emit updated candidate');
    assertSameValue(true, $exceptionCandidate['signals']['exception_flow_hit'] ?? null, 'exception contract change should keep exception flow signal');

    fwrite(STDOUT, "All contract-surface analyzer tests passed.\n");
} finally {
    removeDirectory($repo);
}
