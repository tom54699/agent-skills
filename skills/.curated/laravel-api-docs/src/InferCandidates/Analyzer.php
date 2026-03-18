<?php

namespace LaravelApiDocs\InferCandidates;

final class Analyzer
{
    private readonly ControllerParser $controllerParser;
    private readonly ServiceParser $serviceParser;
    private readonly FormRequestParser $formRequestParser;
    /** @var array<string,array{duration_ms:int,detail:string}> */
    private array $timings = [];
    /** @var array<string,string> */
    private array $timingDetails = [];

    public function __construct(
        private readonly AnalyzerOptions $options,
        private readonly EventEmitter $events,
        private readonly Shell $shell,
    ) {
        $this->controllerParser = new ControllerParser();
        $this->serviceParser = new ServiceParser();
        $this->formRequestParser = new FormRequestParser();
    }

    /**
     * @return array<string,mixed>
     */
    public function run(): array
    {
        $rangeSelection = $this->time('range_selection', fn (): RangeSelection => $this->resolveRangeSelection());
        $routeIndex = $this->time('route_index', fn (): RouteIndex => $this->buildRouteIndex());
        $classIndex = $this->time('class_index', fn (): ClassIndex => $this->buildClassIndex());
        $changeIndex = $this->time('change_index', fn (): ChangeIndex => $this->buildChangeIndex($rangeSelection, $classIndex));
        $actionIndex = $this->time('action_index', fn (): ActionIndex => $this->buildActionIndex($routeIndex, $classIndex));
        $documentRouteKeys = $this->time('baseline_keys', fn (): array => $this->buildDocumentRouteKeys($rangeSelection));
        $newRouteKeys = $this->setDifference($routeIndex->routeKeys(), $documentRouteKeys);
        $deletedRouteKeys = $this->setDifference($documentRouteKeys, $routeIndex->routeKeys());
        $this->events->debug('baseline comparison', [
            'has_openapi_baseline' => $rangeSelection->hasOpenApiBaseline,
            'doc_keys' => count($documentRouteKeys),
            'route_only_keys' => count($newRouteKeys),
            'openapi_only_keys' => count($deletedRouteKeys),
            'informational_only' => true,
            'used_for_deleted_only' => $rangeSelection->initMode === 'daily' && $rangeSelection->hasOpenApiBaseline,
        ]);
        $evaluationRoutes = $this->time(
            'candidate_subset',
            fn (): array => $this->buildEvaluationRoutes($routeIndex, $classIndex, $changeIndex, $actionIndex, $rangeSelection)
        );
        $candidates = $this->time(
            'candidate_resolver',
            fn (): array => $this->resolveCandidates($evaluationRoutes, $classIndex, $changeIndex, $actionIndex, $rangeSelection, $documentRouteKeys, $newRouteKeys, $deletedRouteKeys)
        );

        return [
            'meta' => [
                'engine' => 'php-analyzer',
                'project_root' => $this->options->projectRoot,
                'from_time' => $rangeSelection->fromTime,
                'to_time' => $rangeSelection->toTime,
                'from_commit' => $this->options->fromCommit,
                'init_mode' => $rangeSelection->initMode,
                'analysis_mode' => $this->options->analysisMode,
                'range_source' => $rangeSelection->rangeSource,
                'diff_range_source' => $rangeSelection->diffRangeSource,
                'diff_range' => $rangeSelection->diffRange,
                'history_base_commit' => $rangeSelection->historyBaseCommit,
                'range_fallback_reason' => $rangeSelection->rangeFallbackReason,
                'last_success_synced_at' => $rangeSelection->lastSuccessSyncedAt,
                'baseline_source' => $rangeSelection->baselineSource,
                'has_success_history' => $rangeSelection->hasSuccessHistory,
                'has_openapi_baseline' => $rangeSelection->hasOpenApiBaseline,
                'init_include_updated' => $rangeSelection->initIncludeUpdated,
                'init_exclude_deleted' => $rangeSelection->initExcludeDeleted,
                'lookback_commits' => $this->options->lookbackCommits,
                'scan_roots' => $this->options->scanRoots,
                'history_file' => $this->options->historyFile,
                'openapi_file' => $this->options->openApiFile,
                'output_file' => $this->options->outputFile,
            ],
            'changed_files' => $rangeSelection->changedFiles,
            'candidate_count' => count($candidates),
            'candidates' => $candidates,
            'indexes' => [
                'routes' => $routeIndex->count(),
                'evaluation_routes' => count($evaluationRoutes),
                'unique_actions' => count($routeIndex->uniqueActionKeys()),
                'class_symbols' => $classIndex->count(),
                'changed_files' => $changeIndex->changedFileCount(),
                'changed_service_methods' => $changeIndex->changedServiceMethodCount(),
                'action_metadata' => $actionIndex->count(),
                'document_route_keys' => count($documentRouteKeys),
                'baseline_gap_route_keys' => count($newRouteKeys),
                'baseline_deleted_route_keys' => count($deletedRouteKeys),
            ],
            'timings' => $this->timings,
        ];
    }

    private function resolveRangeSelection(): RangeSelection
    {
        $this->events->progress('range_selection', 0, 5, 'resolving range selection');

        $toTime = gmdate('Y-m-d\TH:i:s\Z');
        $fromTime = null;
        $initMode = 'daily';
        $rangeSource = 'history_git_head_commit';
        $diffRange = null;
        $diffRangeSource = 'none';
        $historyBaseCommit = null;
        $rangeFallbackReason = null;
        $baselineSource = $this->absolutePath($this->options->openApiFile) !== null ? 'local_openapi' : 'none';
        $hasOpenApiBaseline = $baselineSource === 'local_openapi';
        $hasSuccessHistory = false;
        $initIncludeUpdated = true;
        $initExcludeDeleted = true;
        $lastSuccessRecord = $this->readLastSuccessRecord();
        $lastSuccessSyncedAt = $lastSuccessRecord['synced_at'];
        $lastSuccessCommit = $lastSuccessRecord['git_head_commit'];

        if ($lastSuccessSyncedAt !== null) {
            if (!$this->isUtcIso8601($lastSuccessSyncedAt)) {
                throw new \RuntimeException("錯誤：history 最後 success 的 synced_at 不是合法 UTC ISO 8601：{$lastSuccessSyncedAt}");
            }
            $fromTime = $lastSuccessSyncedAt;
            $hasSuccessHistory = true;
        }

        if ($hasSuccessHistory && $this->options->fromCommit === null) {
            if (!$hasOpenApiBaseline) {
                throw new \RuntimeException("錯誤：找到成功同步歷史，但缺少 {$this->options->openApiFile}，無法做日常推測。");
            }
            if ($lastSuccessCommit !== null && $this->gitCommitExists($lastSuccessCommit) && $this->gitIsAncestor($lastSuccessCommit, 'HEAD')) {
                $historyBaseCommit = $lastSuccessCommit;
                $diffRange = $lastSuccessCommit . '..HEAD';
                $diffRangeSource = 'last_success_commit';
                $changedFiles = $this->changedFilesFromDiff($diffRange);
            } else {
                $rangeSource = 'history_time_window_fallback';
                $rangeFallbackReason = $lastSuccessCommit === null || $lastSuccessCommit === ''
                    ? 'missing_git_head_commit'
                    : 'invalid_git_head_commit';
                if ($fromTime === null) {
                    throw new \RuntimeException('錯誤：最後一筆 success history 缺少可用的 synced_at，無法回退時間窗推測。');
                }
                $changedFiles = $this->changedFilesFromTimeWindow($fromTime, $toTime);
                [$diffRange, $diffRangeSource] = $this->determineTimeWindowDiffRange($fromTime, $toTime);
            }
        } else {
            $initMode = 'initialization';
            $rangeSource = 'from_commit_range';
            $fromCommit = $this->options->fromCommit;
            if ($fromCommit === null || $fromCommit === '') {
                throw new \RuntimeException('錯誤：無 success history，初始化必須提供 --from-commit。');
            }
            if (!$this->gitCommitExists($fromCommit)) {
                throw new \RuntimeException("錯誤：--from-commit 不存在：{$fromCommit}");
            }
            if (!$this->gitIsAncestor($fromCommit, 'HEAD')) {
                throw new \RuntimeException("錯誤：--from-commit 不是目前 HEAD 的祖先，無法建立範圍：{$fromCommit}..HEAD");
            }
            $fromTime = $this->epochToUtc(trim($this->shell->mustRun(['git', 'show', '-s', '--format=%ct', $fromCommit])));
            $diffRange = "{$fromCommit}..HEAD";
            $diffRangeSource = 'from_commit';
            $changedFiles = $this->changedFilesFromDiff($diffRange);
            if (!$hasOpenApiBaseline) {
                $baselineSource = 'none';
            }
        }

        $this->events->debug('range selection', [
            'init_mode' => $initMode,
            'range_source' => $rangeSource,
            'from_commit' => $this->options->fromCommit,
            'history_base_commit' => $historyBaseCommit,
            'range_fallback_reason' => $rangeFallbackReason,
            'last_success_synced_at' => $lastSuccessSyncedAt,
            'from_time' => $fromTime,
            'to_time' => $toTime,
        ]);
        $this->events->debug('diff range', [
            'source' => $diffRangeSource,
            'spec' => $diffRange,
        ]);
        $this->timingDetails['range_selection'] = sprintf(
            'init_mode=%s changed_files=%d',
            $initMode,
            count($changedFiles)
        );
        $this->events->progress('range_selection', 5, 5, 'range selection ready');

        return new RangeSelection(
            toTime: $toTime,
            fromTime: $fromTime,
            initMode: $initMode,
            rangeSource: $rangeSource,
            diffRange: $diffRange,
            diffRangeSource: $diffRangeSource,
            historyBaseCommit: $historyBaseCommit,
            rangeFallbackReason: $rangeFallbackReason,
            lastSuccessSyncedAt: $lastSuccessSyncedAt,
            baselineSource: $baselineSource,
            hasSuccessHistory: $hasSuccessHistory,
            hasOpenApiBaseline: $hasOpenApiBaseline,
            initIncludeUpdated: $initIncludeUpdated,
            initExcludeDeleted: $initExcludeDeleted,
            changedFiles: $changedFiles,
        );
    }

    private function buildRouteIndex(): RouteIndex
    {
        $this->events->progress('route_index', 1, 4, 'building route index');
        $raw = $this->shell->mustRun(['php', '-n', 'artisan', 'route:list', '--json']);
        $raw = $this->stripNonJsonPrefix($raw);
        $decoded = json_decode($raw, true, flags: JSON_THROW_ON_ERROR);
        $routes = [];

        foreach ($decoded as $route) {
            if (!is_array($route)) {
                continue;
            }

            $rawUri = (string) ($route['uri'] ?? '');
            if (!str_starts_with($rawUri, 'api/') && !str_starts_with($rawUri, '/api/')) {
                continue;
            }

            $methodParts = explode('|', (string) ($route['method'] ?? 'GET'));
            $methodParts = array_values(array_filter(array_map('strtoupper', $methodParts), static fn (string $method): bool => !in_array($method, ['HEAD', 'OPTIONS'], true)));
            $method = strtolower($methodParts[0] ?? 'GET');
            $uri = trim($rawUri, '/');
            $normalizedUri = preg_replace('#^api/?#', '', $uri);
            if ($normalizedUri === null) {
                $normalizedUri = $uri;
            }
            $path = '/' . ltrim($normalizedUri, '/');
            $trimmedPath = rtrim($path, '/');
            $path = $trimmedPath === '' ? '/' : $trimmedPath;
            $action = (string) ($route['action'] ?? '');
            $controller = '';
            $methodName = '';
            if (str_contains($action, '@')) {
                [$controller, $methodName] = explode('@', $action, 2);
            }

            $routes[] = new RouteEntry(
                method: $method,
                path: $path,
                controller: $controller,
                action: $methodName,
            );
        }

        return new RouteIndex($routes);
    }

    private function buildClassIndex(): ClassIndex
    {
        $this->events->progress('class_index', 2, 4, 'building class index');
        $symbols = [];

        foreach ($this->options->scanRoots as $root) {
            $absoluteRoot = $this->options->projectRoot . '/' . $root;
            if (!is_dir($absoluteRoot)) {
                continue;
            }

            $iterator = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator($absoluteRoot, \FilesystemIterator::SKIP_DOTS)
            );

            /** @var \SplFileInfo $file */
            foreach ($iterator as $file) {
                if ($file->getExtension() !== 'php') {
                    continue;
                }

                $symbol = $this->extractClassSymbol($file->getPathname());
                if ($symbol === null) {
                    continue;
                }
                $symbols[] = $symbol;
            }
        }

        return new ClassIndex($symbols);
    }

    private function buildChangeIndex(RangeSelection $rangeSelection, ClassIndex $classIndex): ChangeIndex
    {
        $this->events->progress('change_index', 3, 4, 'building change index');
        $diffRange = $rangeSelection->diffRange;
        $changedFiles = $rangeSelection->changedFiles;

        $changedServiceMethods = [];
        foreach ($changedFiles as $file) {
            if (!str_ends_with($file, '.php') || !str_contains($file, '/Service')) {
                continue;
            }
            $methods = $this->extractChangedMethods($file, $diffRange);
            if ($methods !== []) {
                $changedServiceMethods[$file] = $methods;
            }
        }

        $changedControllerFiles = [];
        $changedRequestClasses = [];
        $changedResourceClasses = [];
        $changedServiceClasses = [];
        $changedExceptionClasses = [];

        foreach ($classIndex->symbols as $symbol) {
            if (!in_array($symbol->path, $changedFiles, true)) {
                continue;
            }

            switch ($symbol->kind) {
                case 'controller':
                    $changedControllerFiles[] = $symbol->path;
                    break;
                case 'request':
                    $changedRequestClasses[] = $symbol->shortName;
                    break;
                case 'resource':
                    $changedResourceClasses[] = $symbol->shortName;
                    break;
                case 'service':
                    $changedServiceClasses[] = $symbol->shortName;
                    break;
                case 'exception':
                    $changedExceptionClasses[] = $symbol->shortName;
                    break;
            }
        }

        $changedControllerActions = [];
        foreach ($changedControllerFiles as $controllerFile) {
            foreach ($this->extractChangedMethods($controllerFile, $diffRange) as $method) {
                $changedControllerActions[] = $controllerFile . '|' . $method;
            }
        }

        return new ChangeIndex(
            changedFiles: $changedFiles,
            changedServiceMethods: $changedServiceMethods,
            diffRange: $diffRange,
            changedControllerFiles: $this->sortUnique($changedControllerFiles),
            changedRequestClasses: $this->sortUnique($changedRequestClasses),
            changedResourceClasses: $this->sortUnique($changedResourceClasses),
            changedServiceClasses: $this->sortUnique($changedServiceClasses),
            changedExceptionClasses: $this->sortUnique($changedExceptionClasses),
            changedControllerActions: $this->sortUnique($changedControllerActions),
            routeActionHints: $this->extractRouteActionHints($changedFiles, $diffRange),
        );
    }

    private function buildActionIndex(RouteIndex $routeIndex, ClassIndex $classIndex): ActionIndex
    {
        $this->events->progress('action_index', 4, 4, 'building action index');
        $items = [];

        foreach ($routeIndex->routes as $route) {
            if ($route->controller === '') {
                continue;
            }

            $actionKey = $route->actionKey();
            if (isset($items[$actionKey])) {
                continue;
            }

            $symbol = $classIndex->findByFqcn($route->controller);
            $controllerFile = $symbol?->path;
            if ($controllerFile === null) {
            $items[$actionKey] = new ActionMetadata(
                controller: $route->controller,
                action: $route->action !== '' ? $route->action : '__invoke',
                controllerFile: null,
                description: '',
                throws: [],
                formRequest: '',
                resource: '',
                inlineValidationDetected: false,
                baseExceptionGetterUsage: false,
                throwableFallbackDetected: false,
                apiResponseCount: 0,
                serviceCalls: [],
                exceptionRefs: [],
                );
                continue;
            }

            $decoded = $this->controllerParser->parse(
                $this->options->projectRoot . '/' . ltrim($controllerFile, '/'),
                $route->action !== '' ? $route->action : '__invoke'
            );

            $serviceCalls = [];
            foreach (($decoded['service_calls'] ?? []) as $item) {
                if (!is_array($item)) {
                    continue;
                }
                $receiver = (string) ($item['receiver'] ?? '');
                $method = (string) ($item['method'] ?? '');
                if ($receiver === '' || $method === '') {
                    continue;
                }
                $serviceCalls[] = ['receiver' => $receiver, 'method' => $method];
            }

            $items[$actionKey] = new ActionMetadata(
                controller: $route->controller,
                action: $route->action !== '' ? $route->action : '__invoke',
                controllerFile: $controllerFile,
                description: (string) ($decoded['description'] ?? ''),
                throws: array_values(array_filter(array_map('strval', $decoded['throws'] ?? []))),
                formRequest: (string) ($decoded['form_request'] ?? ''),
                resource: (string) ($decoded['resource'] ?? ''),
                inlineValidationDetected: (bool) ($decoded['inline_validation_detected'] ?? false),
                baseExceptionGetterUsage: (bool) ($decoded['base_exception_getter_usage'] ?? false),
                throwableFallbackDetected: (bool) ($decoded['throwable_fallback_detected'] ?? false),
                apiResponseCount: count($decoded['api_responses'] ?? []),
                serviceCalls: $serviceCalls,
                exceptionRefs: array_values(array_filter(array_map('strval', $decoded['exception_refs'] ?? []))),
            );
        }

        return new ActionIndex($items);
    }

    private function extractClassSymbol(string $absoluteFile): ?ClassSymbol
    {
        $code = file_get_contents($absoluteFile);
        if ($code === false) {
            return null;
        }

        $tokens = token_get_all($code);
        $namespace = '';
        $className = null;
        $captureNamespace = false;
        $tokenCount = count($tokens);

        for ($index = 0; $index < $tokenCount; $index++) {
            $token = $tokens[$index];
            if (!is_array($token)) {
                if ($captureNamespace && ($token === ';' || $token === '{')) {
                    $captureNamespace = false;
                }
                continue;
            }

            [$id, $text] = $token;

            if ($id === T_NAMESPACE) {
                $namespace = '';
                $captureNamespace = true;
                continue;
            }

            if ($captureNamespace && in_array($id, [T_STRING, T_NAME_QUALIFIED, T_NS_SEPARATOR], true)) {
                $namespace .= $text;
                continue;
            }

            if (in_array($id, [T_CLASS, T_INTERFACE, T_TRAIT, T_ENUM], true)) {
                if ($this->isAnonymousClass($tokens, $index)) {
                    continue;
                }
                $className = $this->nextStringToken($tokens, $index + 1);
                break;
            }
        }

        if ($className === null) {
            return null;
        }

        $fqcn = ltrim($namespace . '\\' . $className, '\\');
        $relativePath = ltrim(str_replace($this->options->projectRoot, '', $absoluteFile), '/');

        return new ClassSymbol(
            fqcn: $fqcn,
            shortName: $className,
            path: $relativePath,
            kind: $this->classKind($fqcn, $className, $relativePath),
        );
    }

    private function nextStringToken(array $tokens, int $startIndex): ?string
    {
        $tokenCount = count($tokens);
        for ($index = $startIndex; $index < $tokenCount; $index++) {
            $token = $tokens[$index];
            if (is_array($token) && $token[0] === T_STRING) {
                return $token[1];
            }
        }

        return null;
    }

    private function isAnonymousClass(array $tokens, int $classTokenIndex): bool
    {
        for ($index = $classTokenIndex - 1; $index >= 0; $index--) {
            $token = $tokens[$index];
            if (is_string($token)) {
                if (trim($token) === '') {
                    continue;
                }

                return false;
            }

            if (in_array($token[0], [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT], true)) {
                continue;
            }

            return $token[0] === T_NEW;
        }

        return false;
    }

    private function classKind(string $fqcn, string $shortName, string $path): string
    {
        return match (true) {
            str_contains($fqcn, '\\Http\\Controllers\\') || str_ends_with($shortName, 'Controller') => 'controller',
            str_contains($fqcn, '\\Http\\Requests\\') || str_ends_with($shortName, 'Request') => 'request',
            str_contains($fqcn, '\\Http\\Resources\\') || str_ends_with($shortName, 'Resource') => 'resource',
            str_contains($fqcn, '\\Exceptions\\') || str_ends_with($shortName, 'Exception') => 'exception',
            str_contains($fqcn, '\\Services\\') || str_ends_with($shortName, 'Service') || str_contains($path, '/Services/') => 'service',
            default => 'other',
        };
    }

    /**
     * @return list<string>
     */
    private function extractChangedMethods(string $relativeFile, ?string $diffRange): array
    {
        if ($diffRange === null) {
            return [];
        }

        $absolute = $this->options->projectRoot . '/' . $relativeFile;
        if (!is_file($absolute)) {
            return [];
        }

        $diff = $this->shell->mustRun(['git', 'diff', '--unified=0', $diffRange, '--', $relativeFile]);
        preg_match_all('/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/m', $diff, $matches, PREG_SET_ORDER);
        $changedLines = [];
        foreach ($matches as $match) {
            $start = (int) $match[1];
            $count = isset($match[2]) && $match[2] !== '' ? (int) $match[2] : 1;
            if ($count === 0) {
                continue;
            }
            for ($line = $start; $line < $start + $count; $line++) {
                $changedLines[$line] = true;
            }
        }

        $methods = [];
        $currentMethod = null;
        foreach (file($absolute) ?: [] as $lineNumber => $line) {
            if (preg_match('/(?:public|protected|private)\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/', $line, $matches)) {
                $currentMethod = $matches[1];
            }
            if ($currentMethod !== null && isset($changedLines[$lineNumber + 1])) {
                $methods[$currentMethod] = true;
            }
        }

        return array_keys($methods);
    }

    private function stripNonJsonPrefix(string $value): string
    {
        $offsetBrace = strpos($value, '{');
        $offsetBracket = strpos($value, '[');
        $offsets = array_values(array_filter([$offsetBrace, $offsetBracket], static fn ($offset): bool => $offset !== false));
        if ($offsets === []) {
            return $value;
        }

        $offset = min($offsets);
        return substr($value, $offset);
    }

    /**
     * @return list<string>
     */
    private function buildDocumentRouteKeys(RangeSelection $rangeSelection): array
    {
        if (!$rangeSelection->hasOpenApiBaseline) {
            return [];
        }

        $openApiPath = $this->options->projectRoot . '/' . ltrim($this->options->openApiFile, '/');
        [$stdout, , $exitCode] = $this->shell->run(['yq', '-o=json', '.paths // {}', $openApiPath]);
        if ($exitCode !== 0 || trim($stdout) === '') {
            return [];
        }

        $decoded = json_decode($stdout, true);
        if (!is_array($decoded)) {
            return [];
        }

        $keys = [];
        foreach ($decoded as $path => $methods) {
            if (!is_array($methods) || !is_string($path)) {
                continue;
            }
            foreach (array_keys($methods) as $method) {
                $keys[] = strtolower((string) $method) . ' ' . $path;
            }
        }

        return $this->sortUnique($keys);
    }

    /**
     * @param list<string> $left
     * @param list<string> $right
     * @return list<string>
     */
    private function setDifference(array $left, array $right): array
    {
        $rightMap = array_fill_keys($right, true);
        $result = [];
        foreach ($left as $value) {
            if (!isset($rightMap[$value])) {
                $result[] = $value;
            }
        }

        return $this->sortUnique($result);
    }

    /**
     * @return list<RouteCandidateContext>
     */
    private function buildEvaluationRoutes(
        RouteIndex $routeIndex,
        ClassIndex $classIndex,
        ChangeIndex $changeIndex,
        ActionIndex $actionIndex,
        RangeSelection $rangeSelection,
    ): array {
        $serviceMetadataIndex = [];
        $formRequestRuleIndex = [];
        $contexts = [];
        $passed = 0;
        $skipped = 0;
        $totalRoutes = count($routeIndex->routes);
        $progressInterval = max(1, (int) floor(max(1, $totalRoutes) / 20));

        $this->events->progress('candidate_subset', 0, max(1, $totalRoutes), 'building evaluation subset');

        foreach ($routeIndex->routes as $index => $route) {
            $current = $index + 1;
            $actionName = $route->action !== '' ? $route->action : '__invoke';
            $actionMetadata = $actionIndex->get($route->actionKey()) ?? new ActionMetadata(
                controller: $route->controller,
                action: $actionName,
                controllerFile: null,
                description: '',
                throws: [],
                formRequest: '',
                resource: '',
                inlineValidationDetected: false,
                baseExceptionGetterUsage: false,
                throwableFallbackDetected: false,
                apiResponseCount: 0,
                serviceCalls: [],
                exceptionRefs: [],
            );
            $controllerFile = $actionMetadata->controllerFile;
            $formRequestFile = $this->resolveSymbolFile($classIndex, $actionMetadata->formRequest, 'request', $controllerFile);
            $resourceFile = $this->resolveSymbolFile($classIndex, $actionMetadata->resource, 'resource', $controllerFile);
            $serviceFile = $this->resolveServiceFile($classIndex, $controllerFile);
            $serviceMetadata = $this->serviceMetadataFor($serviceFile, $serviceMetadataIndex);
            $requestRuleCount = $this->formRequestRuleCountFor($formRequestFile, $formRequestRuleIndex);
            $subsetHit = false;

            if ($changeIndex->routesChanged() && $changeIndex->diffRange !== null && $this->hasRouteActionHint($changeIndex, $route->controller, $actionName)) {
                $subsetHit = true;
            }

            if ($controllerFile !== null && $changeIndex->diffRange !== null && $this->isChangedControllerAction($changeIndex, $controllerFile, $actionName)) {
                $subsetHit = true;
            } elseif ($controllerFile !== null && $changeIndex->diffRange === null && $changeIndex->hasChangedFile($controllerFile)) {
                $subsetHit = true;
            }

            if (
                !$subsetHit
                && $controllerFile !== null
                && $this->controllerMentionsChangedDependency($changeIndex, $controllerFile)
                && $this->actionLinksChangedDependency(
                    $classIndex,
                    $changeIndex,
                    $actionMetadata,
                    $controllerFile,
                    $serviceFile,
                    $formRequestFile,
                    $resourceFile,
                    $serviceMetadata
                )
            ) {
                $subsetHit = true;
            }

            if (!$subsetHit) {
                $skipped++;
                continue;
            }

            $contexts[] = new RouteCandidateContext(
                route: $route,
                actionMetadata: $actionMetadata,
                controllerFile: $controllerFile,
                formRequestFile: $formRequestFile,
                resourceFile: $resourceFile,
                serviceFile: $serviceFile,
                serviceMetadata: $serviceMetadata,
                requestRuleCount: $requestRuleCount,
            );
            $passed++;

            if ($current === 1 || $current % $progressInterval === 0 || $current === $totalRoutes) {
                $this->events->progress('candidate_subset', $current, max(1, $totalRoutes), "subset {$route->method} {$route->path}");
            }
        }

        $this->events->debug('prefilter summary', [
            'passed' => $passed,
            'skipped' => $skipped,
            'total_routes' => $totalRoutes,
        ]);
        $this->timingDetails['candidate_subset'] = sprintf(
            'subset=%d skipped=%d total_routes=%d',
            $passed,
            $skipped,
            $totalRoutes
        );

        return $contexts;
    }

    /**
     * @param list<string> $documentRouteKeys
     * @param list<string> $newRouteKeys
     * @param list<string> $deletedRouteKeys
     * @return list<array<string,mixed>>
     */
    private function resolveCandidates(
        array $evaluationRoutes,
        ClassIndex $classIndex,
        ChangeIndex $changeIndex,
        ActionIndex $actionIndex,
        RangeSelection $rangeSelection,
        array $documentRouteKeys,
        array $newRouteKeys,
        array $deletedRouteKeys,
    ): array {
        $docKeyMap = array_fill_keys($documentRouteKeys, true);
        $newKeyMap = array_fill_keys($newRouteKeys, true);
        $candidates = [];
        $totalRoutes = count($evaluationRoutes);
        $progressInterval = max(1, (int) floor(max(1, $totalRoutes) / 20));
        $parsedFormRequests = [];
        $parsedServices = [];
        $resolvedSymbols = 0;

        $this->events->progress('candidate_resolver', 0, max(1, $totalRoutes), 'resolving candidates');

        foreach ($evaluationRoutes as $index => $context) {
            $route = $context->route;
            $current = $index + 1;
            $routeKey = $route->routeKey();
            $actionName = $route->action !== '' ? $route->action : '__invoke';
            $actionMetadata = $context->actionMetadata;
            $controllerFile = $context->controllerFile;
            $formRequestFile = $context->formRequestFile;
            $resourceFile = $context->resourceFile;
            $serviceFile = $context->serviceFile;
            $serviceMetadata = $context->serviceMetadata;
            $requestRuleCount = $context->requestRuleCount;
            $serviceExceptionCount = count($serviceMetadata['exceptions']);
            $resolvedSymbols += 4;
            if ($serviceFile !== null) {
                $parsedServices[$serviceFile] = true;
            }
            if ($formRequestFile !== null) {
                $parsedFormRequests[$formRequestFile] = true;
            }

            $status = null;
            $confidenceRank = 0;
            $reasons = [];
            $missingFields = [];
            $updatedSignal = false;

            $formRequestChanged = $formRequestFile !== null && $changeIndex->hasChangedFile($formRequestFile);
            $resourceChanged = $resourceFile !== null && $changeIndex->hasChangedFile($resourceFile);
            $serviceChanged = false;
            $exceptionsChanged = false;
            $requestBoundHit = false;
            $resourceBoundHit = false;
            $serviceMethodHit = false;
            $exceptionFlowHit = false;
            $dependencyActionHit = false;
            $routeActionHit = false;
            $controllerActionHit = false;
            $matchedServiceMethods = [];
            $inDoc = isset($docKeyMap[$routeKey]);
            $missingFromBaseline = isset($newKeyMap[$routeKey]);

            if ($changeIndex->routesChanged() && $this->hasRouteActionHint($changeIndex, $route->controller, $actionName)) {
                $routeActionHit = true;
                $reasons[] = "route action changed: {$route->controller}@{$actionName}";
                $confidenceRank = max($confidenceRank, 3);
                if (!$rangeSelection->hasOpenApiBaseline || !$inDoc) {
                    $status = 'new';
                } else {
                    $updatedSignal = true;
                    $status ??= 'updated';
                }
            }

            if ($controllerFile !== null && $changeIndex->diffRange !== null && $this->isChangedControllerAction($changeIndex, $controllerFile, $actionName)) {
                $controllerActionHit = true;
                $updatedSignal = true;
                $reasons[] = "controller action changed: {$controllerFile}@{$actionName}";
                $confidenceRank = max($confidenceRank, 3);
            } elseif ($controllerFile !== null && $changeIndex->diffRange === null && $changeIndex->hasChangedFile($controllerFile)) {
                $controllerActionHit = true;
                $updatedSignal = true;
                $reasons[] = "controller changed: {$controllerFile}";
                $confidenceRank = max($confidenceRank, 2);
            }

            if ($formRequestChanged) {
                $requestBoundHit = true;
                $dependencyActionHit = true;
                $updatedSignal = true;
                $reasons[] = "request action-bound change: {$controllerFile}@{$actionName} uses {$formRequestFile}";
                $confidenceRank = max($confidenceRank, 2);
            }

            if ($resourceChanged) {
                $resourceBoundHit = true;
                $dependencyActionHit = true;
                $updatedSignal = true;
                $reasons[] = "resource action-bound change: {$controllerFile}@{$actionName} uses {$resourceFile}";
                $confidenceRank = max($confidenceRank, 2);
            }

            if ($serviceFile !== null && $changeIndex->hasChangedFile($serviceFile)) {
                $relevantActionMethods = $this->relevantActionMethodsForService($actionMetadata->serviceCalls, $serviceFile);
                $changedServiceMethods = $changeIndex->changedServiceMethods[$serviceFile] ?? [];
                $matchedServiceMethods = array_values(array_intersect($relevantActionMethods, $changedServiceMethods));

                if ($matchedServiceMethods !== []) {
                    $serviceMethodHit = true;
                    $dependencyActionHit = true;
                    $serviceChanged = true;
                    $updatedSignal = true;
                    $reasons[] = 'service method change: ' . $serviceFile . ' -> ' . implode(', ', $matchedServiceMethods) . " used by {$controllerFile}@{$actionName}";
                    $confidenceRank = max($confidenceRank, 3);
                } elseif ($changedServiceMethods === [] && $this->options->analysisMode === 'enhanced') {
                    $serviceChanged = true;
                    $updatedSignal = true;
                    $reasons[] = "service changed (method unresolved fallback): {$serviceFile}";
                    $confidenceRank = max($confidenceRank, 1);
                }
            }

            foreach ($actionMetadata->exceptionRefs as $exceptionRef) {
                $exceptionFile = $this->resolveSymbolFile($classIndex, $exceptionRef, 'exception', $controllerFile);
                if ($exceptionFile !== null && $changeIndex->hasChangedFile($exceptionFile)) {
                    $exceptionsChanged = true;
                    $exceptionFlowHit = true;
                    $dependencyActionHit = true;
                    $updatedSignal = true;
                    $reasons[] = "exception action-bound change: {$controllerFile}@{$actionName} references {$exceptionFile}";
                    $confidenceRank = max($confidenceRank, 2);
                }
            }

            if ($serviceMethodHit && $serviceFile !== null) {
                foreach ($matchedServiceMethods as $methodName) {
                    foreach (($serviceMetadata['method_exceptions'][$methodName] ?? []) as $exceptionRef) {
                        $exceptionFile = $this->resolveSymbolFile($classIndex, (string) $exceptionRef, 'exception', $serviceFile);
                        if ($exceptionFile !== null && $changeIndex->hasChangedFile($exceptionFile)) {
                            $exceptionsChanged = true;
                            $exceptionFlowHit = true;
                            $dependencyActionHit = true;
                            $updatedSignal = true;
                            $reasons[] = "exception flow via service method: {$serviceFile}::{$methodName} -> {$exceptionFile}";
                            $confidenceRank = max($confidenceRank, 2);
                        }
                    }
                }
            }

            if ($status === null && $updatedSignal) {
                $status = 'updated';
            }

            if ($status === null) {
                continue;
            }

            if ($this->isBodyMethod($route->method)) {
                if ($formRequestFile !== null) {
                    if ($requestRuleCount === 0 && !$actionMetadata->inlineValidationDetected) {
                        $missingFields[] = 'request_schema_missing';
                    }
                } elseif (!$actionMetadata->inlineValidationDetected) {
                    $missingFields[] = 'request_schema_missing';
                }
            }

            if (
                $actionMetadata->apiResponseCount === 0
                && !$actionMetadata->baseExceptionGetterUsage
                && !$actionMetadata->throwableFallbackDetected
                && $serviceExceptionCount === 0
            ) {
                $missingFields[] = 'response_schema_missing';
            }

            $confidence = match (true) {
                $confidenceRank >= 3 => 'high',
                $confidenceRank >= 2 => 'medium',
                default => 'low',
            };

            if ($reasons === []) {
                $reasons[] = 'inferred from route/action dependency';
            }

            $candidates[] = [
                'status' => $status,
                'method' => strtoupper($route->method),
                'path' => $route->path,
                'change_reason' => implode('; ', $reasons),
                'reason' => implode('; ', $reasons),
                'confidence' => $confidence,
                'missing_fields' => array_values(array_unique($missingFields)),
                'signals' => [
                    'controller_file' => $controllerFile ?? '',
                    'service_file' => $serviceFile ?? '',
                    'form_request_file' => $formRequestFile ?? '',
                    'resource_file' => $resourceFile ?? '',
                    'form_request_changed' => $formRequestChanged,
                    'resource_changed' => $resourceChanged,
                    'service_changed' => $serviceChanged,
                    'exceptions_changed' => $exceptionsChanged,
                    'route_action_hit' => $routeActionHit,
                    'controller_action_hit' => $controllerActionHit,
                    'request_bound_hit' => $requestBoundHit,
                    'resource_bound_hit' => $resourceBoundHit,
                    'service_method_hit' => $serviceMethodHit,
                    'exception_flow_hit' => $exceptionFlowHit,
                    'dependency_action_hit' => $dependencyActionHit,
                    'request_rule_count' => $requestRuleCount,
                    'api_response_count' => $actionMetadata->apiResponseCount,
                    'service_exception_count' => $serviceExceptionCount,
                    'matched_service_methods' => array_values($matchedServiceMethods),
                    'in_openapi_baseline' => $inDoc,
                    'missing_from_openapi_baseline' => $missingFromBaseline,
                ],
            ];

            if ($current === 1 || $current % $progressInterval === 0 || $current === $totalRoutes) {
                $this->events->progress('candidate_resolver', $current, max(1, $totalRoutes), "evaluating {$route->method} {$route->path}");
            }
        }

        if ($rangeSelection->initMode === 'daily' && $rangeSelection->hasOpenApiBaseline) {
            foreach ($deletedRouteKeys as $routeKey) {
                [$method, $path] = explode(' ', $routeKey, 2);
                $candidates[] = [
                    'status' => 'deleted',
                    'method' => strtoupper($method),
                    'path' => $path,
                    'change_reason' => 'route diff: endpoint exists in OpenAPI but missing in current Laravel routes',
                    'reason' => 'route diff: endpoint exists in OpenAPI but missing in current Laravel routes',
                    'confidence' => 'high',
                    'missing_fields' => [],
                    'signals' => new \stdClass(),
                ];
            }
        }

        usort($candidates, static function (array $left, array $right): int {
            return [$left['path'], $left['method'], $left['status']] <=> [$right['path'], $right['method'], $right['status']];
        });

        $unique = [];
        foreach ($candidates as $candidate) {
            $key = $candidate['status'] . '|' . $candidate['method'] . '|' . $candidate['path'];
            $unique[$key] = $candidate;
        }

        $statusCounts = ['new' => 0, 'updated' => 0, 'deleted' => 0];
        foreach ($unique as $candidate) {
            $status = (string) ($candidate['status'] ?? '');
            if (isset($statusCounts[$status])) {
                $statusCounts[$status]++;
            }
        }

        $this->events->debug('candidate resolver', [
            'routes' => $totalRoutes,
            'candidate_count' => count($unique),
            'new_candidates' => $statusCounts['new'],
            'updated_candidates' => $statusCounts['updated'],
            'deleted_candidates' => $statusCounts['deleted'],
            'baseline_gap_route_keys' => count($newRouteKeys),
            'parsed_form_requests' => count($parsedFormRequests),
            'parsed_services' => count($parsedServices),
            'resolved_symbols' => $resolvedSymbols,
        ]);
        $this->timingDetails['candidate_resolver'] = sprintf(
            'subset_routes=%d candidates=%d',
            $totalRoutes,
            count($unique)
        );

        return array_values($unique);
    }

    /**
     * @param list<string> $changedFiles
     * @return list<string>
     */
    private function extractRouteActionHints(array $changedFiles, ?string $diffRange): array
    {
        if ($diffRange === null) {
            return [];
        }

        $hints = [];
        foreach ($changedFiles as $file) {
            if (!str_starts_with($file, 'routes/')) {
                continue;
            }

            [$stdout] = $this->shell->run(['git', 'diff', '--unified=0', $diffRange, '--', $file]);
            foreach (preg_split('/\R/', $stdout) ?: [] as $line) {
                if ($line === '' || !str_starts_with($line, '+') || str_starts_with($line, '+++')) {
                    continue;
                }

                if (preg_match('/([A-Za-z_][A-Za-z0-9_\\\\]*Controller)::class/', $line, $controllerMatches) !== 1) {
                    continue;
                }
                if (preg_match('/,\s*[\'"]([A-Za-z_][A-Za-z0-9_]*)[\'"]/', $line, $actionMatches) !== 1) {
                    continue;
                }

                $controller = ltrim($controllerMatches[1], '\\');
                $action = $actionMatches[1];
                $hints[$controller . '|' . $action] = true;
                $baseName = str_contains($controller, '\\') ? substr($controller, strrpos($controller, '\\') + 1) : $controller;
                $hints[$baseName . '|' . $action] = true;
            }
        }

        return array_keys($hints);
    }

    /**
     * @return array{synced_at:?string,git_head_commit:?string}
     */
    private function readLastSuccessRecord(): array
    {
        $historyFile = $this->absolutePath($this->options->historyFile);
        if ($historyFile === null) {
            return ['synced_at' => null, 'git_head_commit' => null];
        }

        $lastSyncedAt = null;
        $lastHeadCommit = null;
        foreach ($this->decodeHistoryRecords($historyFile) as $decoded) {
            if (!is_array($decoded) || ($decoded['status'] ?? null) !== 'success') {
                continue;
            }
            $syncedAt = $decoded['synced_at'] ?? null;
            if (is_string($syncedAt) && $syncedAt !== '') {
                $lastSyncedAt = $syncedAt;
            }
            $headCommit = $decoded['git_head_commit'] ?? null;
            if (is_string($headCommit) && $headCommit !== '') {
                $lastHeadCommit = $headCommit;
            }
        }

        return ['synced_at' => $lastSyncedAt, 'git_head_commit' => $lastHeadCommit];
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function decodeHistoryRecords(string $historyFile): array
    {
        $content = file_get_contents($historyFile);
        if ($content === false || trim($content) === '') {
            return [];
        }

        $records = [];
        $buffer = '';
        $depth = 0;
        $inString = false;
        $escape = false;

        foreach (str_split($content) as $char) {
            if ($depth === 0 && trim($char) === '') {
                continue;
            }

            $buffer .= $char;

            if ($inString) {
                if ($escape) {
                    $escape = false;
                    continue;
                }

                if ($char === '\\') {
                    $escape = true;
                    continue;
                }

                if ($char === '"') {
                    $inString = false;
                }
                continue;
            }

            if ($char === '"') {
                $inString = true;
                continue;
            }

            if ($char === '{') {
                $depth++;
                continue;
            }

            if ($char !== '}') {
                continue;
            }

            $depth--;
            if ($depth !== 0) {
                continue;
            }

            $decoded = json_decode($buffer, true);
            if (is_array($decoded)) {
                $records[] = $decoded;
            }
            $buffer = '';
        }

        return $records;
    }

    /**
     * @return list<string>
     */
    private function changedFilesFromTimeWindow(string $fromTime, string $toTime): array
    {
        $stdout = $this->shell->mustRun(['git', 'log', '--since=' . $fromTime, '--until=' . $toTime, '--name-only', '--pretty=format:']);
        return $this->normalizeFileList(explode("\n", $stdout));
    }

    /**
     * @return list<string>
     */
    private function changedFilesFromDiff(string $diffRange): array
    {
        $stdout = $this->shell->mustRun(['git', 'diff', '--name-only', $diffRange]);
        return $this->normalizeFileList(explode("\n", $stdout));
    }

    /**
     * @return array{0:?string,1:string}
     */
    private function determineTimeWindowDiffRange(string $fromTime, string $toTime): array
    {
        $stdout = $this->shell->mustRun(['git', 'rev-list', '--reverse', '--since=' . $fromTime, '--until=' . $toTime, 'HEAD']);
        $commits = $this->normalizeFileList(explode("\n", $stdout));
        $firstCommit = $commits[0] ?? null;
        if ($firstCommit === null) {
            return [null, 'none'];
        }

        [$parentStdout, , $parentCode] = $this->shell->run(['git', 'rev-parse', $firstCommit . '^']);
        $diffBaseCommit = $parentCode === 0 ? trim($parentStdout) : $firstCommit;
        return [$diffBaseCommit . '..HEAD', 'time_window_fallback'];
    }

    /**
     * @param list<string> $values
     * @return list<string>
     */
    private function normalizeFileList(array $values): array
    {
        $normalized = [];
        foreach ($values as $value) {
            $value = trim($value);
            if ($value === '') {
                continue;
            }
            $normalized[$value] = true;
        }

        $result = array_keys($normalized);
        sort($result);
        return $result;
    }

    /**
     * @param list<string> $values
     * @return list<string>
     */
    private function sortUnique(array $values): array
    {
        $values = array_values(array_unique($values));
        sort($values);
        return $values;
    }

    private function hasRouteActionHint(ChangeIndex $changeIndex, string $controller, string $action): bool
    {
        $controller = ltrim($controller, '\\');
        $baseName = str_contains($controller, '\\') ? substr($controller, strrpos($controller, '\\') + 1) : $controller;
        $needle = $controller . '|' . $action;
        $baseNeedle = $baseName . '|' . $action;

        return in_array($needle, $changeIndex->routeActionHints, true)
            || in_array($baseNeedle, $changeIndex->routeActionHints, true);
    }

    private function isChangedControllerAction(ChangeIndex $changeIndex, string $controllerFile, string $action): bool
    {
        return in_array($controllerFile . '|' . $action, $changeIndex->changedControllerActions, true);
    }

    private function controllerMentionsChangedDependency(ChangeIndex $changeIndex, string $controllerFile): bool
    {
        $absolute = $this->options->projectRoot . '/' . ltrim($controllerFile, '/');
        if (!is_file($absolute)) {
            return false;
        }

        $content = file_get_contents($absolute);
        if ($content === false) {
            return false;
        }

        foreach ([
            $changeIndex->changedRequestClasses,
            $changeIndex->changedResourceClasses,
            $changeIndex->changedServiceClasses,
            $changeIndex->changedExceptionClasses,
        ] as $classNames) {
            foreach ($classNames as $className) {
                if ($className !== '' && str_contains($content, $className)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     */
    private function actionLinksChangedDependency(
        ClassIndex $classIndex,
        ChangeIndex $changeIndex,
        ActionMetadata $actionMetadata,
        string $controllerFile,
        ?string $serviceFile,
        ?string $formRequestFile,
        ?string $resourceFile,
        array $serviceMetadata,
    ): bool {
        if ($formRequestFile !== null && $changeIndex->hasChangedFile($formRequestFile)) {
            return true;
        }

        if ($resourceFile !== null && $changeIndex->hasChangedFile($resourceFile)) {
            return true;
        }

        foreach ($actionMetadata->exceptionRefs as $exceptionRef) {
            $exceptionFile = $this->resolveSymbolFile($classIndex, $exceptionRef, 'exception', $controllerFile);
            if ($exceptionFile !== null && $changeIndex->hasChangedFile($exceptionFile)) {
                return true;
            }
        }

        if ($serviceFile === null || !$changeIndex->hasChangedFile($serviceFile)) {
            return false;
        }

        $relevantActionMethods = $this->relevantActionMethodsForService($actionMetadata->serviceCalls, $serviceFile);
        $changedServiceMethods = $changeIndex->changedServiceMethods[$serviceFile] ?? [];
        $matchedServiceMethods = array_values(array_intersect($relevantActionMethods, $changedServiceMethods));

        if ($matchedServiceMethods !== []) {
            return true;
        }

        if ($changedServiceMethods === [] && $this->options->analysisMode === 'enhanced') {
            return true;
        }

        if ($changeIndex->changedExceptionClasses === []) {
            return false;
        }

        foreach ($matchedServiceMethods as $methodName) {
            foreach (($serviceMetadata['method_exceptions'][$methodName] ?? []) as $exceptionRef) {
                $exceptionFile = $this->resolveSymbolFile($classIndex, (string) $exceptionRef, 'exception', $serviceFile);
                if ($exceptionFile !== null && $changeIndex->hasChangedFile($exceptionFile)) {
                    return true;
                }
            }
        }

        return false;
    }

    private function resolveSymbolFile(ClassIndex $classIndex, string $rawSymbol, ?string $kind = null, ?string $contextFile = null): ?string
    {
        $normalized = ltrim(trim($rawSymbol), '\\');
        if ($normalized === '') {
            return null;
        }

        $symbol = $classIndex->findByFqcn($normalized);
        if ($symbol !== null) {
            return $symbol->path;
        }

        $shortName = str_contains($normalized, '\\') ? substr($normalized, strrpos($normalized, '\\') + 1) : $normalized;
        if ($contextFile !== null) {
            $imported = $this->resolveImportedFqcn($contextFile, $shortName);
            if ($imported !== null) {
                $symbol = $classIndex->findByFqcn($imported);
                if ($symbol !== null) {
                    return $symbol->path;
                }
            }
        }

        $matches = $classIndex->findByShortName($shortName, $kind);
        if ($matches !== []) {
            return $matches[0]->path;
        }

        $matches = $classIndex->findByShortName($shortName);
        return $matches[0]->path ?? null;
    }

    private function resolveImportedFqcn(string $contextFile, string $shortName): ?string
    {
        $absolute = $this->options->projectRoot . '/' . ltrim($contextFile, '/');
        if (!is_file($absolute)) {
            return null;
        }

        foreach (file($absolute, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            if (preg_match('/^\s*use\s+([^;]+);/', $line, $matches) !== 1) {
                continue;
            }

            $useClause = trim($matches[1]);
            $parts = preg_split('/\s+as\s+/i', $useClause) ?: [];
            $full = trim($parts[0] ?? '');
            if ($full === '') {
                continue;
            }

            $baseName = str_contains($full, '\\') ? substr($full, strrpos($full, '\\') + 1) : $full;
            $alias = trim($parts[1] ?? $baseName);
            if ($alias === $shortName) {
                return ltrim($full, '\\');
            }
        }

        return null;
    }

    private function resolveServiceFile(ClassIndex $classIndex, ?string $controllerFile): ?string
    {
        if ($controllerFile === null) {
            return null;
        }

        $controllerBase = basename($controllerFile, '.php');
        if (str_ends_with($controllerBase, 'Controller')) {
            $serviceShortName = substr($controllerBase, 0, -10) . 'Service';
            $matches = $classIndex->findByShortName($serviceShortName, 'service');
            if ($matches !== []) {
                return $matches[0]->path;
            }
        }

        $imported = $this->firstImportedService($controllerFile);
        if ($imported !== null) {
            $symbol = $classIndex->findByFqcn($imported);
            if ($symbol !== null) {
                return $symbol->path;
            }
        }

        return null;
    }

    private function firstImportedService(string $contextFile): ?string
    {
        $absolute = $this->options->projectRoot . '/' . ltrim($contextFile, '/');
        if (!is_file($absolute)) {
            return null;
        }

        foreach (file($absolute, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            if (preg_match('/^\s*use\s+([^;]+);/', $line, $matches) !== 1) {
                continue;
            }
            $full = trim(preg_split('/\s+as\s+/i', trim($matches[1]))[0] ?? '');
            $baseName = str_contains($full, '\\') ? substr($full, strrpos($full, '\\') + 1) : $full;
            if ($baseName !== '' && str_ends_with($baseName, 'Service')) {
                return ltrim($full, '\\');
            }
        }

        return null;
    }

    /**
     * @param array<string,array{exceptions:list<array<string,mixed>>,error_messages:list<mixed>,base_exception_getter_usage:bool,getter_methods:list<string>,catches_base_exception:bool,method_exceptions:array<string,list<string>>}> $serviceMetadataIndex
     * @return array{exceptions:list<array<string,mixed>>,error_messages:list<mixed>,base_exception_getter_usage:bool,getter_methods:list<string>,catches_base_exception:bool,method_exceptions:array<string,list<string>>}
     */
    private function serviceMetadataFor(?string $serviceFile, array &$serviceMetadataIndex): array
    {
        if ($serviceFile === null) {
            return $this->serviceParser->emptyMetadata();
        }

        if (!isset($serviceMetadataIndex[$serviceFile])) {
            $serviceMetadataIndex[$serviceFile] = $this->serviceParser->parse($this->options->projectRoot . '/' . ltrim($serviceFile, '/'));
        }

        return $serviceMetadataIndex[$serviceFile];
    }

    /**
     * @param array<string,int> $formRequestRuleIndex
     */
    private function formRequestRuleCountFor(?string $requestFile, array &$formRequestRuleIndex): int
    {
        if ($requestFile === null) {
            return 0;
        }

        if (!isset($formRequestRuleIndex[$requestFile])) {
            $formRequestRuleIndex[$requestFile] = $this->formRequestParser->countRules(
                $this->options->projectRoot . '/' . ltrim($requestFile, '/')
            );
        }

        return $formRequestRuleIndex[$requestFile];
    }

    /**
     * @param list<array{receiver:string,method:string}> $serviceCalls
     * @return list<string>
     */
    private function relevantActionMethodsForService(array $serviceCalls, string $serviceFile): array
    {
        $serviceClass = basename($serviceFile, '.php');
        $serviceVar = lcfirst($serviceClass);
        $methods = [];

        foreach ($serviceCalls as $call) {
            $receiver = strtolower($call['receiver'] ?? '');
            $method = (string) ($call['method'] ?? '');
            if ($method === '') {
                continue;
            }

            if (str_contains($receiver, strtolower($serviceClass)) || str_contains($receiver, strtolower($serviceVar))) {
                $methods[] = $method;
            }
        }

        if ($methods === []) {
            foreach ($serviceCalls as $call) {
                $method = (string) ($call['method'] ?? '');
                if ($method !== '') {
                    $methods[] = $method;
                }
            }
        }

        return $this->sortUnique($methods);
    }

    private function isBodyMethod(string $method): bool
    {
        return in_array(strtolower($method), ['post', 'put', 'patch'], true);
    }

    private function absolutePath(string $relativePath): ?string
    {
        if ($relativePath !== '' && str_starts_with($relativePath, '/')) {
            return is_file($relativePath) ? $relativePath : null;
        }

        $path = $this->options->projectRoot . '/' . ltrim($relativePath, '/');
        return is_file($path) ? $path : null;
    }

    private function isUtcIso8601(string $value): bool
    {
        return (bool) preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $value);
    }

    private function epochToUtc(string $epoch): string
    {
        return gmdate('Y-m-d\TH:i:s\Z', (int) $epoch);
    }

    private function gitCommitExists(string $commit): bool
    {
        [, , $code] = $this->shell->run(['git', 'cat-file', '-e', $commit . '^{commit}']);
        return $code === 0;
    }

    private function gitIsAncestor(string $ancestor, string $descendant): bool
    {
        [, , $code] = $this->shell->run(['git', 'merge-base', '--is-ancestor', $ancestor, $descendant]);
        return $code === 0;
    }

    private function time(string $stage, callable $callback): mixed
    {
        $start = microtime(true);
        $result = $callback();
        $durationMs = (int) round((microtime(true) - $start) * 1000);
        $detail = $this->timingDetails[$stage] ?? '';
        $stableStage = $this->stableTimingStage($stage);
        $this->timings[$stableStage] = [
            'duration_ms' => $durationMs,
            'detail' => $detail,
        ];
        $this->events->timing($stage, $durationMs, $detail !== '' ? ['detail' => $detail] : []);
        return $result;
    }

    private function stableTimingStage(string $stage): string
    {
        return match ($stage) {
            'route_index' => 'route_snapshot',
            'change_index' => 'git_inventory',
            'action_index' => 'action_hints',
            'candidate_resolver' => 'candidate_evaluation',
            default => $stage,
        };
    }
}
