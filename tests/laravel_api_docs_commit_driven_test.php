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

function assertStringContainsValue(string $needle, string $actual, string $message): void
{
    if (!str_contains($actual, $needle)) {
        throw new RuntimeException($message . "\nExpected substring: " . $needle . "\nActual: " . $actual);
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

/**
 * @param list<array{method:string,path:string,controller:string,action:string}> $routes
 */
function setRouteState(string $repo, array $routes): void
{
    $uses = [];
    $routeLines = [];
    $controllers = [];
    $routeList = [];

    foreach ($routes as $route) {
        $fqcn = 'App\\Http\\Controllers\\' . $route['controller'];
        $uses[$route['controller']] = "use {$fqcn};";
        $routeLines[] = sprintf(
            "Route::%s('%s', [%s::class, '%s']);",
            strtolower($route['method']),
            $route['path'],
            $route['controller'],
            $route['action']
        );
        $controllers[$route['controller']][$route['action']] = true;
        $routeList[] = [
            'method' => strtoupper($route['method']),
            'uri' => 'api/' . ltrim($route['path'], '/'),
            'action' => $fqcn . '@' . $route['action'],
        ];
    }

    $controllers['UserController']['index'] = true;
    $controllers['UserController']['store'] = true;
    $controllers['HealthController']['show'] = true;

    ksort($uses);
    ksort($controllers);

    $apiPhp = "<?php\n\n" . implode("\n", $uses) . "\n\n" . implode("\n", $routeLines) . "\n";
    writeFile($repo . '/routes/api.php', $apiPhp);
    writeFile($repo . '/route-list.json', json_encode($routeList, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");

    foreach ($controllers as $controller => $actions) {
        $methods = [];
        foreach (array_keys($actions) as $action) {
            $methods[] = "    public function {$action}()\n    {\n        return [];\n    }";
        }
        $controllerPhp = "<?php\n\nnamespace App\\Http\\Controllers;\n\nclass {$controller}\n{\n" . implode("\n\n", $methods) . "\n}\n";
        writeFile($repo . '/app/Http/Controllers/' . $controller . '.php', $controllerPhp);
    }
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

function createOpenApiBaseline(string $repo): void
{
    $yaml = <<<'YAML'
openapi: 3.0.0
info:
  title: Test API
  version: 1.0.0
paths:
  /users:
    get:
      summary: index
      responses:
        '200':
          description: ok
YAML;

    writeFile($repo . '/docs/api-docs/openapi.yaml', $yaml . "\n");
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
        'git_branch' => 'main',
        'openapi_sha256' => 'test',
        'apidog_project_id' => '123',
        'imported_count' => 0,
        'updated_count' => 0,
        'skipped_count' => 0,
        'conflict_count' => 0,
        'status' => 'success',
        'path_strategy' => 'strip-api-prefix-to-server',
    ];
    if ($gitHeadCommit !== null) {
        $record['git_head_commit'] = $gitHeadCommit;
    }

    $path = $repo . '/docs/api-docs/history/' . $fileName;
    writeFile($path, json_encode($record, JSON_UNESCAPED_SLASHES) . "\n");

    return $path;
}

/**
 * @return array<string,mixed>
 */
function runAnalyzer(
    string $repo,
    string $historyFile = 'docs/api-docs/history/apidog-sync-history.jsonl',
    ?string $fromCommit = null,
    ?string $pathStrategy = null
): array
{
    $options = new AnalyzerOptions(
        historyFile: $historyFile,
        openApiFile: 'docs/api-docs/openapi.yaml',
        fromCommit: $fromCommit,
        pathStrategy: $pathStrategy,
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

function createFixtureRepository(): array
{
    $repo = sys_get_temp_dir() . '/laravel-api-docs-test-' . bin2hex(random_bytes(4));
    if (!mkdir($repo, 0777, true) && !is_dir($repo)) {
        throw new RuntimeException('Failed to create temp repo');
    }

    createArtisan($repo);
    createOpenApiBaseline($repo);
    writeFile($repo . '/README.md', "# test repo\n");

    mustRun(['git', 'init'], $repo);
    mustRun(['git', 'config', 'user.name', 'Test Runner'], $repo);
    mustRun(['git', 'config', 'user.email', 'test@example.com'], $repo);

    setRouteState($repo, [
        ['method' => 'GET', 'path' => '/users', 'controller' => 'UserController', 'action' => 'index'],
        ['method' => 'GET', 'path' => '/health', 'controller' => 'HealthController', 'action' => 'show'],
    ]);

    $commit1 = gitCommit($repo, 'baseline', '2026-03-18T00:00:00Z');
    $syncedAt1 = commitTime($repo, $commit1);
    writeHistoryRecord($repo, 'apidog-sync-history.jsonl', $syncedAt1, $commit1);

    writeFile($repo . '/README.md', "# test repo\n\nnon api change\n");
    $commit2 = gitCommit($repo, 'docs change', '2026-03-18T00:05:00Z');
    $syncedAt2 = commitTime($repo, $commit2);
    $historyWithoutCommit = writeHistoryRecord($repo, 'legacy-history.jsonl', $syncedAt1, null);

    return [
        'repo' => $repo,
        'commit1' => $commit1,
        'commit2' => $commit2,
        'synced_at_1' => $syncedAt1,
        'synced_at_2' => $syncedAt2,
        'legacy_history' => $historyWithoutCommit,
    ];
}

function createInitializationFixtureRepository(): array
{
    $repo = sys_get_temp_dir() . '/laravel-api-docs-init-test-' . bin2hex(random_bytes(4));
    if (!mkdir($repo, 0777, true) && !is_dir($repo)) {
        throw new RuntimeException('Failed to create temp repo');
    }

    createArtisan($repo);
    createOpenApiBaseline($repo);
    writeFile($repo . '/README.md', "# init test repo\n");

    mustRun(['git', 'init'], $repo);
    mustRun(['git', 'config', 'user.name', 'Test Runner'], $repo);
    mustRun(['git', 'config', 'user.email', 'test@example.com'], $repo);

    setRouteState($repo, [
        ['method' => 'GET', 'path' => '/users', 'controller' => 'UserController', 'action' => 'index'],
    ]);
    $commit1 = gitCommit($repo, 'baseline', '2026-03-18T01:00:00Z');

    setRouteState($repo, [
        ['method' => 'GET', 'path' => '/users', 'controller' => 'UserController', 'action' => 'index'],
        ['method' => 'POST', 'path' => '/users', 'controller' => 'UserController', 'action' => 'store'],
    ]);
    $commit2 = gitCommit($repo, 'add route', '2026-03-18T01:05:00Z');

    return [
        'repo' => $repo,
        'commit1' => $commit1,
        'commit2' => $commit2,
    ];
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

$fixture = createFixtureRepository();
$repo = $fixture['repo'];
$initFixture = createInitializationFixtureRepository();
$initRepo = $initFixture['repo'];

try {
$dailyNoApi = runAnalyzer($repo);
    assertSameValue('daily', $dailyNoApi['meta']['init_mode'], 'daily mode should be selected when success history exists');
    assertSameValue('last_success_commit', $dailyNoApi['meta']['diff_range_source'], 'daily mode should use commit baseline');
    assertSameValue($fixture['commit1'] . '..HEAD', $dailyNoApi['meta']['diff_range'], 'daily diff range should start from last successful commit');
    assertSameValue('strip-api-prefix-to-server', $dailyNoApi['meta']['path_strategy'], 'daily mode should expose persisted path strategy');
    assertSameValue(0, $dailyNoApi['candidate_count'], 'non-api changes with thin baseline must not create bulk new candidates');
    assertSameValue(1, $dailyNoApi['indexes']['baseline_gap_route_keys'], 'baseline gap should remain diagnostic-only');

$fallback = runAnalyzer($repo, $fixture['legacy_history']);
    assertSameValue('history_time_window_fallback', $fallback['meta']['range_source'], 'legacy history should fall back to time-window mode');
    assertSameValue('missing_git_head_commit', $fallback['meta']['range_fallback_reason'], 'fallback reason should explain missing commit baseline');
    assertSameValue(0, $fallback['candidate_count'], 'fallback run without api changes must not create candidates');

writeHistoryRecord($repo, 'post-docs-history.jsonl', $fixture['synced_at_2'], $fixture['commit2']);
setRouteState($repo, [
    ['method' => 'GET', 'path' => '/users', 'controller' => 'UserController', 'action' => 'index'],
    ['method' => 'POST', 'path' => '/users', 'controller' => 'UserController', 'action' => 'store'],
    ['method' => 'GET', 'path' => '/health', 'controller' => 'HealthController', 'action' => 'show'],
]);
$commit3 = gitCommit($repo, 'add route', '2026-03-18T00:10:00Z');
$newRoute = runAnalyzer($repo, 'docs/api-docs/history/post-docs-history.jsonl');
    assertSameValue('last_success_commit', $newRoute['meta']['diff_range_source'], 'route-addition run should use commit baseline');
    $newCandidate = findCandidate($newRoute, 'new', 'POST', '/users');
    assertTrueValue($newCandidate !== null, 'route addition should produce a new candidate');
    assertSameValue(1, $newRoute['candidate_count'], 'baseline gaps must not inflate route-addition candidates');

writeHistoryRecord($repo, 'post-add-route-history.jsonl', commitTime($repo, $commit3), $commit3);
setRouteState($repo, [
    ['method' => 'POST', 'path' => '/users', 'controller' => 'UserController', 'action' => 'store'],
    ['method' => 'GET', 'path' => '/health', 'controller' => 'HealthController', 'action' => 'show'],
]);
gitCommit($repo, 'remove route', '2026-03-18T00:15:00Z');
$deletedRoute = runAnalyzer($repo, 'docs/api-docs/history/post-add-route-history.jsonl');
    $deletedCandidate = findCandidate($deletedRoute, 'deleted', 'GET', '/users');
    assertTrueValue($deletedCandidate !== null, 'route removal should still emit deleted candidate when baseline exists');

$inclusiveInitialization = runAnalyzer($initRepo, 'docs/api-docs/history/missing.jsonl', $initFixture['commit2'], 'keep-full-path');
    assertSameValue('initialization', $inclusiveInitialization['meta']['init_mode'], 'missing history with from-commit should use initialization mode');
    assertSameValue($initFixture['commit1'] . '..HEAD', $inclusiveInitialization['meta']['diff_range'], 'initialization diff range should include the selected commit itself');
    assertTrueValue(in_array('routes/api.php', $inclusiveInitialization['changed_files'], true), 'inclusive initialization should include files changed in the selected commit');
    $inclusiveCandidate = findCandidate($inclusiveInitialization, 'new', 'POST', '/api/users');
    assertTrueValue($inclusiveCandidate !== null, 'selected initialization commit should contribute its route addition');

    try {
        runAnalyzer($initRepo, 'docs/api-docs/history/missing.jsonl', $initFixture['commit1'], 'keep-full-path');
        throw new RuntimeException('root commit should not be accepted as initialization from-commit');
    } catch (RuntimeException $exception) {
        assertStringContainsValue('沒有 parent', $exception->getMessage(), 'root commit initialization should fail with a clear error');
    }

    fwrite(STDOUT, "All commit-driven analyzer tests passed.\n");
} finally {
    removeDirectory($repo);
    removeDirectory($initRepo);
}
