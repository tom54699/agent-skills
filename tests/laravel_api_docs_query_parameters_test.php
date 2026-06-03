<?php

declare(strict_types=1);

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
function runCommand(array $command, string $cwd): array
{
    $descriptorSpec = [
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open($command, $descriptorSpec, $pipes, $cwd, $_ENV);
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

function mustRun(array $command, string $cwd): string
{
    [$stdout, $stderr, $code] = runCommand($command, $cwd);
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

function createFixtureRepository(): string
{
    $repo = sys_get_temp_dir() . '/laravel-api-docs-generator-test-' . bin2hex(random_bytes(4));
    if (!mkdir($repo, 0777, true) && !is_dir($repo)) {
        throw new RuntimeException('Failed to create temp repo');
    }

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

    writeFile($repo . '/routes/api.php', <<<'PHP'
<?php

use App\Http\Controllers\ReportController;
use Illuminate\Support\Facades\Route;

Route::get('reports', [ReportController::class, 'index']);
Route::get('search', [ReportController::class, 'search']);
Route::post('reports', [ReportController::class, 'store']);
PHP
        . "\n");

    writeFile($repo . '/route-list.json', json_encode([
        [
            'method' => 'GET|HEAD',
            'uri' => 'api/reports',
            'action' => 'App\\Http\\Controllers\\ReportController@index',
            'middleware' => ['api'],
        ],
        [
            'method' => 'GET|HEAD',
            'uri' => 'api/search',
            'action' => 'App\\Http\\Controllers\\ReportController@search',
            'middleware' => ['api'],
        ],
        [
            'method' => 'POST',
            'uri' => 'api/reports',
            'action' => 'App\\Http\\Controllers\\ReportController@store',
            'middleware' => ['api'],
        ],
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");

    writeFile($repo . '/app/Http/Controllers/ReportController.php', <<<'PHP'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\ReportIndexRequest;
use App\Http\Requests\ReportStoreRequest;
use Illuminate\Http\Request;

class ReportController
{
    /**
     * 報表查詢
     */
    public function index(ReportIndexRequest $request)
    {
        return [];
    }

    public function search(Request $request)
    {
        $request->validate([
            'keyword' => 'required|string',
            'page' => 'nullable|integer',
        ]);

        return [];
    }

    public function store(ReportStoreRequest $request)
    {
        return [];
    }
}
PHP
        . "\n");

    writeFile($repo . '/app/Http/Requests/ReportIndexRequest.php', <<<'PHP'
<?php

namespace App\Http\Requests;

class ReportIndexRequest
{
    public function rules(): array
    {
        return [
            'status' => ['required', 'string', 'in:open,closed'],
            'page' => ['nullable', 'integer', 'min:1'],
        ];
    }
}
PHP
        . "\n");

    writeFile($repo . '/app/Http/Requests/ReportStoreRequest.php', <<<'PHP'
<?php

namespace App\Http\Requests;

class ReportStoreRequest
{
    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:120'],
            'amount' => ['required', 'numeric', 'min:1'],
        ];
    }
}
PHP
        . "\n");

    return $repo;
}

/**
 * @return array<string,mixed>
 */
function decodeYamlFile(string $repo, string $file): array
{
    $json = mustRun(['yq', '-o=json', '.', $file], $repo);
    $decoded = json_decode($json, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($decoded)) {
        throw new RuntimeException('Expected decoded YAML document to be an array');
    }

    return $decoded;
}

function runGenerator(string $repo, string $pathStrategy): array
{
    $script = '/Users/athena/Documents/workSpace/私人/Agent-Skills/skills/laravel-api-docs/bin/gen-openapi.php';
    $stdout = mustRun(['php', '-n', $script, '--path-strategy', $pathStrategy, '--no-progress'], $repo);

    return json_decode($stdout, true, flags: JSON_THROW_ON_ERROR);
}

$repo = createFixtureRepository();

try {
    $keepFull = runGenerator($repo, 'keep-full-path');
    $keepFullDoc = decodeYamlFile($repo, $repo . '/docs/api-docs/openapi.yaml');

    assertSameValue('keep-full-path', $keepFull['path_strategy'], 'generator should expose keep-full-path strategy');
    assertTrueValue(isset($keepFullDoc['paths']['/api/reports']['get']['parameters']), 'GET FormRequest endpoint should emit query parameters with full path');
    assertTrueValue(!isset($keepFullDoc['paths']['/api/reports']['get']['requestBody']), 'GET endpoint must not emit requestBody');
    assertSameValue('http://localhost:8000', $keepFullDoc['servers'][0]['url'] ?? null, 'keep-full-path should keep server without /api base path');

    $reportParameters = $keepFullDoc['paths']['/api/reports']['get']['parameters'];
    assertSameValue('page', $reportParameters[0]['name'] ?? null, 'first GET parameter should be sorted by name');
    assertSameValue('query', $reportParameters[0]['in'] ?? null, 'GET parameter should be emitted as query');
    assertSameValue(true, $reportParameters[1]['required'] ?? null, 'required FormRequest field should mark required=true');

    $searchParameters = $keepFullDoc['paths']['/api/search']['get']['parameters'] ?? [];
    assertSameValue(2, count($searchParameters), 'GET inline validation should emit query parameters');
    assertTrueValue(isset($keepFullDoc['paths']['/api/reports']['post']['requestBody']), 'POST endpoint should still emit requestBody');

    $strip = runGenerator($repo, 'strip-api-prefix-to-server');
    $stripDoc = decodeYamlFile($repo, $repo . '/docs/api-docs/openapi.yaml');

    assertSameValue('strip-api-prefix-to-server', $strip['path_strategy'], 'generator should expose strip strategy');
    assertTrueValue(isset($stripDoc['paths']['/reports']['get']['parameters']), 'strip strategy should emit normalized route path');
    assertSameValue('http://localhost:8000/api', $stripDoc['servers'][0]['url'] ?? null, 'strip strategy should move /api into server base path');
    assertTrueValue(!isset($stripDoc['paths']['/reports']['get']['requestBody']), 'GET endpoint should still avoid requestBody under strip strategy');

    fwrite(STDOUT, "All query parameter generator tests passed.\n");
} finally {
    removeDirectory($repo);
}
