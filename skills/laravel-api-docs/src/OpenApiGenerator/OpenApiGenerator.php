<?php

namespace LaravelApiDocs\OpenApiGenerator;

use LaravelApiDocs\InferCandidates\ControllerParser;
use LaravelApiDocs\InferCandidates\EventEmitter;
use LaravelApiDocs\InferCandidates\FormRequestParser;
use LaravelApiDocs\InferCandidates\ServiceParser;
use LaravelApiDocs\InferCandidates\Shell;

final class OpenApiGenerator
{
    private readonly ControllerParser $controllerParser;
    private readonly FormRequestParser $formRequestParser;
    private readonly ResponseAnalyzer $responseAnalyzer;
    private readonly ServiceParser $serviceParser;
    /** @var array<string,array{duration_ms:int,detail:string}> */
    private array $timings = [];
    /** @var array<string,string> */
    private array $timingDetails = [];
    /** @var array{
     *   unresolved_validation_rules:list<array<string,mixed>>,
     *   unresolved_response_shape:list<array<string,mixed>>,
     *   unresolved_security:list<array<string,mixed>>,
     *   low_confidence_examples:list<array<string,mixed>>
     * } */
    private array $reviewItems = [
        'unresolved_validation_rules' => [],
        'unresolved_response_shape' => [],
        'unresolved_security' => [],
        'low_confidence_examples' => [],
    ];

    public function __construct(
        private readonly GeneratorOptions $options,
        private readonly EventEmitter $events,
        private readonly Shell $shell,
    ) {
        $this->controllerParser = new ControllerParser();
        $this->formRequestParser = new FormRequestParser();
        $this->responseAnalyzer = new ResponseAnalyzer();
        $this->serviceParser = new ServiceParser();
    }

    /** @return array<string,mixed> */
    public function run(): array
    {
        if (!is_dir($this->options->outputDir) && !mkdir($concurrentDirectory = $this->options->outputDir, 0777, true) && !is_dir($concurrentDirectory)) {
            throw new \RuntimeException("Failed to create output directory: {$this->options->outputDir}");
        }

        $routeIndex = $this->time('route_snapshot', fn (): RouteIndex => $this->buildRouteIndex());
        $candidateState = $this->time('candidate_normalization', fn (): array => $this->normalizeCandidates($routeIndex));
        if ($candidateState['routes'] === [] && $candidateState['deleted_keys'] === []) {
            throw new \RuntimeException('錯誤：沒有找到任何可處理的 endpoint');
        }
        $document = $this->time('endpoint_generation', fn (): array => $this->buildGeneratedDocument($candidateState['routes']));
        $merged = $this->time('merge_openapi', fn (): array => $this->mergeDocument($document));
        $final = $this->time('apply_deletions', fn (): array => $this->applyDeletions($merged, $candidateState['deleted_keys']));
        $this->time('write_output', function () use ($final): null {
            $this->writeYamlDocument($final, $this->options->openApiFile);
            return null;
        });
        $reviewFile = $this->time('write_review', fn (): ?string => $this->writeReviewArtifact());

        return [
            'file' => $this->options->openApiFile,
            'mode' => $this->mode(),
            'candidate_file' => $this->options->candidateFile,
            'review_file' => $reviewFile,
            'review_item_count' => $this->reviewItemCount(),
            'total_endpoint_count' => $routeIndex->count(),
            'generated_endpoint_count' => count($candidateState['routes']),
            'confirmed_candidate_count' => $candidateState['confirmed_count'],
            'deleted_candidate_count' => count($candidateState['deleted_keys']),
            'missing_route_count' => $candidateState['missing_route_count'],
            'timings' => $this->timings,
        ];
    }

    private function mode(): string
    {
        if ($this->options->candidateFile !== null) {
            return 'confirmed_apply';
        }

        if ($this->options->incremental) {
            return 'incremental';
        }

        return 'full';
    }

    private function buildRouteIndex(): RouteIndex
    {
        $this->events->progress('route_snapshot', 0, 1, 'loading laravel routes');
        $raw = $this->shell->mustRun(['php', '-n', 'artisan', 'route:list', '--json']);
        $decoded = json_decode($this->stripNonJsonPrefix($raw), true, flags: JSON_THROW_ON_ERROR);
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
            $method = $methodParts[0] ?? 'GET';
            $uri = trim($rawUri, '/');
            $normalizedUri = preg_replace('#^api/?#', '', $uri) ?? $uri;
            $path = '/' . ltrim($normalizedUri, '/');
            $path = rtrim($path, '/');
            $path = $path === '' ? '/' : $path;
            $action = (string) ($route['action'] ?? '');
            $controller = '';
            $methodName = '';
            if (str_contains($action, '@')) {
                [$controller, $methodName] = explode('@', $action, 2);
            }

            $routes[] = new RouteDefinition(
                method: strtoupper($method),
                path: $path,
                name: (string) ($route['name'] ?? ''),
                controller: $controller,
                action: $methodName,
                middleware: array_values(array_map('strval', $route['middleware'] ?? [])),
            );
        }

        $this->timingDetails['route_snapshot'] = sprintf('routes=%d', count($routes));
        $this->events->progress('route_snapshot', 1, 1, 'route snapshot ready');
        return new RouteIndex($routes);
    }

    /**
     * @return array{
     *   routes:list<RouteDefinition>,
     *   deleted_keys:list<string>,
     *   confirmed_count:int,
     *   missing_route_count:int
     * }
     */
    private function normalizeCandidates(RouteIndex $routeIndex): array
    {
        $this->events->progress('candidate_normalization', 0, 1, 'normalizing candidates');

        if ($this->options->candidateFile === null) {
            $this->events->progress('candidate_normalization', 1, 1, 'full generation without candidate file');
            return [
                'routes' => $routeIndex->routes,
                'deleted_keys' => [],
                'confirmed_count' => 0,
                'missing_route_count' => 0,
            ];
        }

        if (!is_file($this->options->candidateFile)) {
            throw new \RuntimeException("錯誤：找不到確認清單 {$this->options->candidateFile}");
        }

        $decoded = json_decode((string) file_get_contents($this->options->candidateFile), true, flags: JSON_THROW_ON_ERROR);
        $candidates = is_array($decoded) && array_is_list($decoded)
            ? $decoded
            : (is_array($decoded) ? ($decoded['candidates'] ?? []) : []);

        $normalized = [];
        foreach ($candidates as $candidate) {
            if (!is_array($candidate)) {
                continue;
            }

            $status = strtolower((string) ($candidate['status'] ?? ''));
            $method = strtoupper((string) ($candidate['method'] ?? ''));
            $path = (string) ($candidate['path'] ?? '');
            if (!in_array($status, ['new', 'updated', 'deleted'], true) || $method === '' || $path === '') {
                continue;
            }
            $normalized[$status . '|' . $method . '|' . $path] = [
                'status' => $status,
                'method' => $method,
                'path' => $path,
            ];
        }

        $confirmed = array_values($normalized);
        usort($confirmed, static fn (array $left, array $right): int => [$left['path'], $left['method'], $left['status']] <=> [$right['path'], $right['method'], $right['status']]);

        $activeKeys = [];
        $deletedKeys = [];
        foreach ($confirmed as $candidate) {
            $key = strtolower($candidate['method']) . ' ' . $candidate['path'];
            if ($candidate['status'] === 'deleted') {
                $deletedKeys[$key] = true;
                continue;
            }
            $activeKeys[$key] = true;
        }

        $routes = [];
        $missing = $activeKeys;
        foreach ($routeIndex->routes as $route) {
            $key = $route->routeKey();
            if (!isset($activeKeys[$key])) {
                continue;
            }
            $routes[] = $route;
            unset($missing[$key]);
        }

        $this->events->progress('candidate_normalization', 1, 1, 'candidate normalization ready');
        $this->timingDetails['candidate_normalization'] = sprintf(
            'confirmed=%d active=%d deleted=%d missing_routes=%d',
            count($confirmed),
            count($activeKeys),
            count($deletedKeys),
            count($missing)
        );

        return [
            'routes' => $routes,
            'deleted_keys' => array_keys($deletedKeys),
            'confirmed_count' => count($confirmed),
            'missing_route_count' => count($missing),
        ];
    }

    /** @param list<RouteDefinition> $routes */
    private function buildGeneratedDocument(array $routes): array
    {
        $this->events->progress('endpoint_generation', 0, max(1, count($routes)), 'building operations');
        $document = $this->baseDocument();
        $controllerParseCache = [];
        $requestParseCache = [];
        $serviceParseCache = [];
        $interval = max(1, (int) floor(max(1, count($routes)) / 20));

        foreach ($routes as $index => $route) {
            $current = $index + 1;
            $document['paths'][$route->path][strtolower($route->method)] = $this->buildOperation(
                $route,
                $controllerParseCache,
                $requestParseCache,
                $serviceParseCache,
            );

            if ($current === 1 || $current % $interval === 0 || $current === count($routes)) {
                $this->events->progress('endpoint_generation', $current, max(1, count($routes)), "generating {$route->method} {$route->path}");
            }
        }

        $this->timingDetails['endpoint_generation'] = sprintf('generated=%d', count($routes));
        return $document;
    }

    /**
     * @param array<string,array<string,mixed>> $controllerParseCache
     * @param array<string,list<array<string,mixed>>> $requestParseCache
     * @param array<string,array<string,mixed>> $serviceParseCache
     * @return array<string,mixed>
     */
    private function buildOperation(
        RouteDefinition $route,
        array &$controllerParseCache,
        array &$requestParseCache,
        array &$serviceParseCache,
    ): array {
        $action = $route->action !== '' ? $route->action : '__invoke';
        $controllerFile = $this->resolveControllerFile($route->controller);
        $controllerData = [];
        if ($controllerFile !== null) {
            $cacheKey = $controllerFile . '|' . $action;
            if (!isset($controllerParseCache[$cacheKey])) {
                $controllerParseCache[$cacheKey] = $this->controllerParser->parse($controllerFile, $action);
            }
            $controllerData = $controllerParseCache[$cacheKey];
        }

        $serviceFile = $this->resolveServiceFile($route->controller);
        $serviceData = $this->serviceParser->emptyMetadata();
        if ($serviceFile !== null && !isset($serviceParseCache[$serviceFile])) {
            $serviceParseCache[$serviceFile] = $this->serviceParser->parse($serviceFile);
        }
        if ($serviceFile !== null) {
            $serviceData = $serviceParseCache[$serviceFile] ?? $serviceData;
        }

        $description = trim((string) ($controllerData['description'] ?? ''));
        if ($description === '') {
            $description = sprintf('由 %s@%s 處理', $route->controller, $action);
        }

        $requestFields = [];
        $operation = [
            'summary' => $action,
            'description' => $description,
            'tags' => [$this->tagForController($route->controller)],
        ];
        if ($this->routeRequiresAuth($route)) {
            $operation['security'] = [['bearerAuth' => []]];
        }

        if ($this->isBodyMethod($route->method)) {
            $formRequest = (string) ($controllerData['form_request'] ?? '');
            if ($formRequest !== '') {
                $requestFile = $this->resolveRequestFile($formRequest);
                if ($requestFile !== null) {
                    if (!isset($requestParseCache[$requestFile])) {
                        $requestParseCache[$requestFile] = $this->formRequestParser->parseRules($requestFile);
                    }
                    $requestFields = $requestParseCache[$requestFile];
                }
            }

            if ($requestFields === []) {
                $inlineValidationRules = $controllerData['inline_validation_rules'] ?? [];
                if (is_array($inlineValidationRules)) {
                    $requestFields = array_values(array_filter($inlineValidationRules, static fn (mixed $field): bool => is_array($field)));
                }
            }

            $this->collectValidationReviewItems($route, $requestFields);
            $schema = $this->buildRequestSchema($requestFields);

            $operation['requestBody'] = [
                'required' => true,
                'content' => [
                    'application/json' => [
                        'schema' => $schema,
                        'example' => $this->requestExample($requestFields),
                    ],
                ],
            ];
        }

        $this->collectResponseReviewItems($route, $controllerData);
        $operation['responses'] = $this->buildResponses($route, $controllerData, $serviceData, $requestFields);

        return $operation;
    }

    /** @param array<string,mixed> $field */
    private function fieldSchema(array $field): array
    {
        $schema = [
            'type' => (string) ($field['type'] ?? 'string'),
        ];

        if (($schema['type'] ?? '') === 'array' && !array_key_exists('items', $field)) {
            $schema['items'] = ['type' => 'string'];
        }

        foreach (['format', 'minLength', 'maxLength', 'enum', 'nullable', 'minimum', 'maximum', 'minItems', 'maxItems', 'pattern', 'items'] as $key) {
            if (array_key_exists($key, $field)) {
                $schema[$key] = $field[$key];
            }
        }

        $notes = [];
        if (isset($field['sameAs']) && is_string($field['sameAs']) && $field['sameAs'] !== '') {
            $notes[] = 'Must match ' . $field['sameAs'];
        }
        if (($field['containsLetters'] ?? false) === true) {
            $notes[] = 'Must contain letters';
        }
        if (($field['containsNumbers'] ?? false) === true) {
            $notes[] = 'Must contain numbers';
        }
        if (($field['containsSymbols'] ?? false) === true) {
            $notes[] = 'Must contain symbols';
        }
        if (($field['containsMixedCase'] ?? false) === true) {
            $notes[] = 'Must contain both uppercase and lowercase letters';
        }
        if (isset($field['dateFormat']) && is_string($field['dateFormat']) && $field['dateFormat'] !== '') {
            $notes[] = 'Laravel date format: ' . $field['dateFormat'];
        }
        if ($notes !== []) {
            $schema['description'] = implode('; ', $notes);
        }
        if (isset($field['passwordRules']) && is_array($field['passwordRules']) && $field['passwordRules'] !== []) {
            $schema['x-laravel-password-rules'] = $field['passwordRules'];
        }
        if (isset($field['unresolvedRules']) && is_array($field['unresolvedRules']) && $field['unresolvedRules'] !== []) {
            $schema['x-laravel-unresolved-rules'] = array_values(array_map('strval', $field['unresolvedRules']));
        }

        return $schema;
    }

    /**
     * @param list<array<string,mixed>> $requestFields
     * @return array<string,mixed>
     */
    private function buildRequestSchema(array $requestFields): array
    {
        $schema = [
            'type' => 'object',
            'properties' => [],
        ];

        foreach ($requestFields as $field) {
            $segments = $field['segments'] ?? null;
            if (!is_array($segments) || $segments === []) {
                $segments = [(string) ($field['field'] ?? '')];
            }

            $this->applyFieldToSchema($schema, array_values(array_map('strval', $segments)), $field);
        }

        return $this->normalizeSchemaNode($schema);
    }

    /**
     * @param list<array<string,mixed>> $requestFields
     * @param array<string,mixed> $controllerData
     * @param array<string,mixed> $serviceData
     * @return array<string,mixed>
     */
    private function buildResponses(RouteDefinition $route, array $controllerData, array $serviceData, array $requestFields): array
    {
        $responses = $this->defaultResponses($route, $requestFields, $controllerData);
        $knownErrors = $this->collectKnownErrors($controllerData, $serviceData);

        foreach ($knownErrors as $error) {
            $status = (int) ($error['status'] ?? 500);
            $description = (string) ($error['description'] ?? '錯誤');
            $example = $error['example'] ?? null;
            $this->upsertErrorResponse($responses, $status, $description, $example);
        }

        return $responses;
    }

    /**
     * @param list<array<string,mixed>> $requestFields
     * @return array<string,mixed>
     */
    private function requestExample(array $requestFields): array|\stdClass
    {
        if ($requestFields === []) {
            return new \stdClass();
        }

        $resolvedExamples = [];
        foreach ($requestFields as $field) {
            $name = (string) ($field['field'] ?? '');
            if ($name === '') {
                continue;
            }
            $resolvedExamples[$name] = $this->exampleForField($field);
        }

        foreach ($requestFields as $field) {
            $name = (string) ($field['field'] ?? '');
            $sameAs = (string) ($field['sameAs'] ?? '');
            if ($name === '' || $sameAs === '' || !array_key_exists($sameAs, $resolvedExamples)) {
                continue;
            }
            $resolvedExamples[$name] = $resolvedExamples[$sameAs];
        }

        $example = [];
        foreach ($requestFields as $field) {
            $name = (string) ($field['field'] ?? '');
            if ($name === '' || !array_key_exists($name, $resolvedExamples)) {
                continue;
            }

            $segments = $field['segments'] ?? null;
            if (!is_array($segments) || $segments === []) {
                $segments = [$name];
            }
            $this->applyExampleValue($example, array_values(array_map('strval', $segments)), $resolvedExamples[$name]);
        }

        return $example === [] ? new \stdClass() : $example;
    }

    /**
     * @param array<string,mixed> $field
     */
    private function exampleForField(array $field): mixed
    {
        $name = strtolower((string) ($field['field'] ?? 'field'));
        $type = (string) ($field['type'] ?? 'string');
        $enum = $field['enum'] ?? null;
        if (is_array($enum) && $enum !== []) {
            return $enum[0];
        }

        return match ($type) {
            'boolean' => true,
            'integer' => (int) ($field['minimum'] ?? 1),
            'number' => (float) ($field['minimum'] ?? 1.5),
            'array' => [$this->exampleForArrayItem($field)],
            default => $this->stringExample($name, $field),
        };
    }

    /**
     * @param array<string,mixed> $field
     */
    private function exampleForArrayItem(array $field): mixed
    {
        $items = $field['items'] ?? ['type' => 'string'];
        if (!is_array($items)) {
            return 'item';
        }

        return match ((string) ($items['type'] ?? 'string')) {
            'boolean' => true,
            'integer' => 1,
            'number' => 1.5,
            'object' => new \stdClass(),
            default => 'item',
        };
    }

    /**
     * @param array<string,mixed> $field
     */
    private function stringExample(string $name, array $field): string
    {
        if (($field['format'] ?? null) === 'email') {
            return 'user@example.com';
        }

        if (($field['format'] ?? null) === 'date') {
            return '2026-01-01';
        }

        if (str_contains($name, 'phone')) {
            return '0912345678';
        }

        if ($name === 'country_code') {
            return '+95';
        }

        if ($name === 'country_iso_code') {
            return 'MM';
        }

        if (str_contains($name, 'password')) {
            return 'secret123';
        }

        if (str_contains($name, 'otp')) {
            $length = (int) ($field['minLength'] ?? $field['maxLength'] ?? 6);
            return str_repeat('1', max(1, $length));
        }

        if ($name === 'device_os') {
            return 'ios';
        }

        if ($name === 'device_model') {
            return 'iPhone 15';
        }

        if ($name === 'device_id_type') {
            return 'idfa';
        }

        if ($name === 'device_id') {
            return 'device-123';
        }

        if (isset($field['pattern']) && preg_match('/^\^\\\\d\{(\d+)\}\$$/', (string) $field['pattern'], $matches) === 1) {
            return str_repeat('0', (int) $matches[1]);
        }

        $example = 'string';
        $minLength = (int) ($field['minLength'] ?? 0);
        if ($minLength > strlen($example)) {
            $example = str_pad($example, $minLength, 'x');
        }

        return $example;
    }

    /**
     * @param array<string,mixed> $controllerData
     * @param array<string,mixed> $serviceData
     * @return list<array{status:int,description:string,example:array<string,mixed>}>
     */
    private function collectKnownErrors(array $controllerData, array $serviceData): array
    {
        $errors = [];

        foreach (($controllerData['api_responses'] ?? []) as $response) {
            if (!is_array($response)) {
                continue;
            }
            $status = (int) ($response['http_status'] ?? 0);
            if ($status < 400 || $status > 599) {
                continue;
            }

            $message = $this->messageFromExpression((string) ($response['message_expr'] ?? '')) ?: $this->defaultErrorDescription($status);
            $resolved = $this->responseAnalyzer->resolveError($response);
            $code = isset($response['error_code']) && is_int($response['error_code']) ? $response['error_code'] : $status;
            $errors[$status] = [
                'status' => $status,
                'description' => $resolved['description'] ?? $message,
                'example' => $resolved['example'] ?? $this->errorExample($status, $message, $code),
            ];
        }

        foreach (($serviceData['exceptions'] ?? []) as $exception) {
            if (!is_array($exception)) {
                continue;
            }
            $status = isset($exception['code']) && is_int($exception['code']) && $exception['code'] >= 400 && $exception['code'] <= 599
                ? $exception['code']
                : 500;
            $message = (string) ($exception['message'] ?? $exception['exception'] ?? $this->defaultErrorDescription($status));
            if (!isset($errors[$status])) {
                $errors[$status] = [
                    'status' => $status,
                    'description' => $message,
                    'example' => $this->errorExample($status, $message, isset($exception['code']) && is_int($exception['code']) ? $exception['code'] : $status),
                ];
            }
        }

        $controllerMessages = array_values(array_filter(array_map('strval', $controllerData['error_messages'] ?? [])));
        if ($controllerMessages !== [] && !isset($errors[500])) {
            $errors[500] = [
                'status' => 500,
                'description' => $controllerMessages[0],
                'example' => $this->errorExample(500, $controllerMessages[0], 500),
            ];
        }

        ksort($errors);
        return array_values($errors);
    }

    private function messageFromExpression(string $expression): ?string
    {
        $expression = trim($expression);
        if ($expression === '') {
            return null;
        }

        if (preg_match('/^[\'"](.+)[\'"]$/', $expression, $matches) === 1) {
            return $matches[1];
        }

        if (preg_match('/__(\s*)\(\s*[\'"]([^\'"]+)[\'"]/', $expression, $matches) === 1) {
            return $matches[2];
        }

        if (preg_match('/trans(\s*)\(\s*[\'"]([^\'"]+)[\'"]/', $expression, $matches) === 1) {
            return $matches[2];
        }

        return null;
    }

    private function defaultResponses(RouteDefinition $route, array $requestFields, array $controllerData): array
    {
        return [
            '200' => $this->successResponse($route, $controllerData),
            '401' => $this->errorResponse(401, '未授權', $this->errorExample(401, '未授權', 401)),
            '422' => $this->errorResponse(422, '驗證失敗', $this->validationErrorExample($requestFields)),
            '500' => $this->errorResponse(500, '伺服器錯誤', $this->errorExample(500, '伺服器錯誤', 500)),
        ];
    }

    private function successResponse(RouteDefinition $route, array $controllerData): array
    {
        $resolved = $this->responseAnalyzer->resolveSuccess($route, $controllerData);
        if ($resolved !== null) {
            return [
                'description' => '成功',
                'content' => [
                    'application/json' => [
                        'schema' => $resolved['schema'],
                        'example' => $resolved['example'],
                    ],
                ],
            ];
        }

        return [
            'description' => '成功',
            'content' => [
                'application/json' => [
                    'schema' => [
                        'type' => 'object',
                        'properties' => [
                            'data' => [
                                'type' => 'object',
                                'nullable' => true,
                            ],
                        ],
                    ],
                    'example' => [
                        'data' => $this->successExampleData($route, $controllerData),
                    ],
                ],
            ],
        ];
    }

    private function successExampleData(RouteDefinition $route, array $controllerData): mixed
    {
        $preferred = $this->preferredSuccessPayload($controllerData);
        if ($preferred['resolved']) {
            return $preferred['value'];
        }

        $path = strtolower($route->path);
        if (str_contains($path, 'login') || str_contains($path, 'register')) {
            return [
                'token' => 'sample-token',
                'user' => new \stdClass(),
            ];
        }

        if (str_contains($path, 'config')) {
            return [
                'config' => new \stdClass(),
            ];
        }

        return new \stdClass();
    }

    /**
     * @param array<string,mixed> $controllerData
     * @return array{resolved:bool,value:mixed}
     */
    private function preferredSuccessPayload(array $controllerData): array
    {
        $resolved = ['resolved' => false, 'value' => null];

        foreach (($controllerData['api_responses'] ?? []) as $response) {
            if (!is_array($response)) {
                continue;
            }

            $status = (int) ($response['http_status'] ?? 0);
            if ($status < 200 || $status >= 400) {
                continue;
            }

            if (!array_key_exists('data_literal', $response)) {
                continue;
            }

            $expr = trim((string) ($response['data_expr'] ?? ''));
            if ($expr === 'null') {
                $resolved = ['resolved' => true, 'value' => null];
                continue;
            }

            if ($expr !== '' && $response['data_literal'] !== null) {
                $resolved = ['resolved' => true, 'value' => $response['data_literal']];
            }
        }

        return $resolved;
    }

    private function errorResponse(int $status, string $description, array $example): array
    {
        return [
            'description' => $description,
            'content' => [
                'application/json' => [
                    'schema' => ['$ref' => '#/components/schemas/ErrorResponse'],
                    'example' => $example,
                ],
            ],
        ];
    }

    private function upsertErrorResponse(array &$responses, int $status, string $description, mixed $example): void
    {
        $key = (string) $status;
        if (!isset($responses[$key])) {
            $responses[$key] = $this->errorResponse($status, $description, is_array($example) ? $example : $this->errorExample($status, $description, $status));
            return;
        }

        $responses[$key]['description'] = $description;
        if (is_array($example)) {
            $responses[$key]['content']['application/json']['example'] = $example;
        }
    }

    /**
     * @param list<array<string,mixed>> $requestFields
     * @return array<string,mixed>
     */
    private function validationErrorExample(array $requestFields): array
    {
        $errors = [];
        foreach ($requestFields as $field) {
            if (($field['required'] ?? false) !== true) {
                continue;
            }
            $fieldName = (string) ($field['field'] ?? '');
            if ($fieldName === '') {
                continue;
            }
            $errors[$fieldName] = ['The ' . $fieldName . ' field is required.'];
        }

        if ($errors === []) {
            $errors['field'] = ['The field is invalid.'];
        }

        return [
            'message' => '驗證失敗',
            'code' => 422,
            'errors' => $errors,
        ];
    }

    /**
     * @param array<string,mixed> $schema
     * @param list<string> $segments
     * @param array<string,mixed> $field
     */
    private function applyFieldToSchema(array &$schema, array $segments, array $field): void
    {
        if ($segments === []) {
            return;
        }

        $segment = array_shift($segments);
        if ($segment === null) {
            return;
        }

        if ($segment === '*') {
            $schema['type'] = 'array';
            if ($segments === []) {
                $schema['items'] = $this->fieldSchema($field);
                return;
            }

            if (!isset($schema['items']) || !is_array($schema['items'])) {
                $schema['items'] = $this->defaultContainerSchema($segments[0] ?? null);
            }
            $this->applyFieldToSchema($schema['items'], $segments, $field);
            return;
        }

        $schema['type'] = 'object';
        if (!isset($schema['properties']) || !is_array($schema['properties'])) {
            $schema['properties'] = [];
        }

        if ($segments === []) {
            $schema['properties'][$segment] = $this->fieldSchema($field);
            if (($field['required'] ?? false) === true) {
                $this->markRequired($schema, $segment);
            }
            return;
        }

        if (!isset($schema['properties'][$segment]) || !is_array($schema['properties'][$segment])) {
            $schema['properties'][$segment] = $this->defaultContainerSchema($segments[0] ?? null);
        }

        if (($field['required'] ?? false) === true) {
            $this->markRequired($schema, $segment);
        }

        $this->applyFieldToSchema($schema['properties'][$segment], $segments, $field);
    }

    /**
     * @return array<string,mixed>
     */
    private function defaultContainerSchema(?string $nextSegment): array
    {
        if ($nextSegment === '*') {
            return [
                'type' => 'array',
                'items' => [
                    'type' => 'object',
                    'properties' => [],
                ],
            ];
        }

        return [
            'type' => 'object',
            'properties' => [],
        ];
    }

    /**
     * @param array<string,mixed> $schema
     */
    private function markRequired(array &$schema, string $property): void
    {
        $required = $schema['required'] ?? [];
        if (!is_array($required)) {
            $required = [];
        }
        if (!in_array($property, $required, true)) {
            $required[] = $property;
        }
        $schema['required'] = $required;
    }

    /**
     * @param array<string,mixed> $schema
     * @return array<string,mixed>
     */
    private function normalizeSchemaNode(array $schema): array
    {
        $type = (string) ($schema['type'] ?? 'object');

        if ($type === 'object') {
            $properties = $schema['properties'] ?? [];
            if (!is_array($properties)) {
                $properties = [];
            }
            foreach ($properties as $name => $property) {
                if (is_array($property)) {
                    $properties[$name] = $this->normalizeSchemaNode($property);
                }
            }
            $schema['properties'] = $properties === [] ? (object) [] : $properties;
            if (isset($schema['required']) && is_array($schema['required'])) {
                $schema['required'] = array_values(array_unique(array_map('strval', $schema['required'])));
            }
        }

        if ($type === 'array') {
            if (!isset($schema['items']) || !is_array($schema['items'])) {
                $schema['items'] = ['type' => 'string'];
            } else {
                $schema['items'] = $this->normalizeSchemaNode($schema['items']);
            }
        }

        return $schema;
    }

    /**
     * @param array<string,mixed> $example
     * @param list<string> $segments
     */
    private function applyExampleValue(array &$example, array $segments, mixed $value): void
    {
        if ($segments === []) {
            return;
        }

        $segment = array_shift($segments);
        if ($segment === null) {
            return;
        }

        if ($segment === '*') {
            if (!array_is_list($example)) {
                $example = [];
            }
            if ($segments === []) {
                $example[0] = $value;
                return;
            }
            if (!isset($example[0]) || !is_array($example[0])) {
                $example[0] = [];
            }
            $this->applyExampleValue($example[0], $segments, $value);
            return;
        }

        if ($segments === []) {
            $example[$segment] = $value;
            return;
        }

        if (!isset($example[$segment]) || !is_array($example[$segment])) {
            $example[$segment] = $segments[0] === '*' ? [] : [];
        }

        $this->applyExampleValue($example[$segment], $segments, $value);
    }

    private function errorExample(int $status, string $message, int $code): array
    {
        return [
            'message' => $message !== '' ? $message : $this->defaultErrorDescription($status),
            'code' => $code,
        ];
    }

    private function defaultErrorDescription(int $status): string
    {
        return match ($status) {
            400 => '請求錯誤',
            401 => '未授權',
            403 => '禁止存取',
            404 => '找不到資源',
            409 => '狀態衝突',
            422 => '驗證失敗',
            default => '伺服器錯誤',
        };
    }

    private function mergeDocument(array $generated): array
    {
        $this->events->progress('merge_openapi', 0, 1, 'merging openapi');
        $baseFile = $this->resolveMergeSource();
        $result = $generated;
        if ($baseFile !== null && ($this->options->incremental || $this->options->candidateFile !== null)) {
            $base = $this->loadYamlDocument($baseFile);
            $result = $this->recursiveMerge($base, $generated);
            $this->timingDetails['merge_openapi'] = "base={$baseFile}";
        } else {
            $this->timingDetails['merge_openapi'] = 'base=<none>';
        }

        $this->events->progress('merge_openapi', 1, 1, 'merge stage complete');
        return $result;
    }

    /** @param list<string> $deletedKeys */
    private function applyDeletions(array $document, array $deletedKeys): array
    {
        $this->events->progress('apply_deletions', 0, 1, 'applying deletions');
        foreach ($deletedKeys as $deleteKey) {
            [$method, $path] = explode(' ', $deleteKey, 2);
            $method = strtolower($method);
            if (!isset($document['paths'][$path][$method])) {
                continue;
            }
            unset($document['paths'][$path][$method]);
            if ($document['paths'][$path] === []) {
                unset($document['paths'][$path]);
            }
        }
        $this->timingDetails['apply_deletions'] = sprintf('deleted=%d', count($deletedKeys));
        $this->events->progress('apply_deletions', 1, 1, 'deletion stage complete');
        return $document;
    }

    private function writeYamlDocument(array $document, string $outputFile): void
    {
        $this->timingDetails['write_output'] = "output={$outputFile}";
        $jsonFile = tempnam(sys_get_temp_dir(), 'openapi-json-');
        if ($jsonFile === false) {
            throw new \RuntimeException('Failed to create temporary file');
        }

        try {
            $json = json_encode(
                $document,
                JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
            );
            if ($json === false) {
                throw new \RuntimeException('Failed to encode OpenAPI document');
            }
            file_put_contents($jsonFile, $json);
            $yaml = $this->shell->mustRun(['yq', '-P', '-p=json', '.', $jsonFile]);
            file_put_contents($outputFile, $yaml);
        } finally {
            @unlink($jsonFile);
        }
    }

    private function resolveMergeSource(): ?string
    {
        if ($this->options->baseFile !== null && is_file($this->options->baseFile)) {
            return $this->options->baseFile;
        }

        if (is_file($this->options->openApiFile)) {
            return $this->options->openApiFile;
        }

        if ($this->options->openApiFile === 'docs/api-docs/openapi.yaml' && is_file('docs/openapi.yaml')) {
            return 'docs/openapi.yaml';
        }

        return null;
    }

    private function resolveControllerFile(string $controller): ?string
    {
        if ($controller === '') {
            return null;
        }
        $className = str_contains($controller, '\\') ? substr($controller, strrpos($controller, '\\') + 1) : $controller;
        return $this->findPhpFile($this->options->projectRoot . '/app/Http/Controllers', $className);
    }

    private function resolveServiceFile(string $controller): ?string
    {
        $className = str_contains($controller, '\\') ? substr($controller, strrpos($controller, '\\') + 1) : $controller;
        if ($className === '' || !str_ends_with($className, 'Controller')) {
            return null;
        }

        $serviceName = substr($className, 0, -10) . 'Service.php';
        return $this->findPhpFile($this->options->projectRoot . '/app/Services', pathinfo($serviceName, PATHINFO_FILENAME));
    }

    private function resolveRequestFile(string $requestClass): ?string
    {
        $className = str_contains($requestClass, '\\') ? substr($requestClass, strrpos($requestClass, '\\') + 1) : $requestClass;
        return $this->findPhpFile($this->options->projectRoot . '/app', $className);
    }

    private function tagForController(string $controller): string
    {
        $className = str_contains($controller, '\\') ? substr($controller, strrpos($controller, '\\') + 1) : $controller;
        return preg_replace('/Controller$/', '', $className) ?: $className;
    }

    private function isBodyMethod(string $method): bool
    {
        return in_array(strtolower($method), ['post', 'put', 'patch'], true);
    }

    private function routeRequiresAuth(RouteDefinition $route): bool
    {
        foreach ($route->middleware as $middleware) {
            $normalized = strtolower($middleware);
            if (
                $normalized === 'auth'
                || str_starts_with($normalized, 'auth:')
                || str_contains($normalized, '\\authenticate')
                || str_contains($normalized, 'jwt')
            ) {
                return true;
            }
        }

        return false;
    }

    private function reviewItemCount(): int
    {
        return count($this->reviewItems['unresolved_validation_rules'])
            + count($this->reviewItems['unresolved_response_shape'])
            + count($this->reviewItems['unresolved_security'])
            + count($this->reviewItems['low_confidence_examples']);
    }

    private function writeReviewArtifact(): ?string
    {
        $count = $this->reviewItemCount();
        $detail = "items={$count}";
        if ($count === 0) {
            $this->timingDetails['write_review'] = $detail;
            return null;
        }

        $outputFile = $this->options->reviewFile;
        if ($outputFile === null) {
            $timestamp = gmdate('Ymd\\THis\\Z');
            $outputFile = $this->options->outputDir . '/reviews/openapi-review.' . $timestamp . '.json';
        }

        $payload = [
            'meta' => [
                'generated_at' => gmdate('Y-m-d\\TH:i:s\\Z'),
                'openapi_file' => $this->options->openApiFile,
                'candidate_file' => $this->options->candidateFile,
                'review_item_count' => $count,
            ],
            'unresolved_validation_rules' => $this->reviewItems['unresolved_validation_rules'],
            'unresolved_response_shape' => $this->reviewItems['unresolved_response_shape'],
            'unresolved_security' => $this->reviewItems['unresolved_security'],
            'low_confidence_examples' => $this->reviewItems['low_confidence_examples'],
        ];

        $directory = dirname($outputFile);
        if (!is_dir($directory) && !mkdir($concurrentDirectory = $directory, 0777, true) && !is_dir($concurrentDirectory)) {
            throw new \RuntimeException("Failed to create review directory: {$directory}");
        }

        $json = json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
        if ($json === false) {
            throw new \RuntimeException('Failed to encode review artifact');
        }

        file_put_contents($outputFile, $json . PHP_EOL);
        $this->timingDetails['write_review'] = $detail . " output={$outputFile}";
        return $outputFile;
    }

    /**
     * @param list<array<string,mixed>> $requestFields
     */
    private function collectValidationReviewItems(RouteDefinition $route, array $requestFields): void
    {
        foreach ($requestFields as $field) {
            $unresolved = $field['unresolvedRules'] ?? [];
            if (!is_array($unresolved) || $unresolved === []) {
                continue;
            }

            $fieldName = (string) ($field['field'] ?? '');
            $this->reviewItems['unresolved_validation_rules'][] = [
                'id' => sha1('validation|' . $route->routeKey() . '|' . $fieldName . '|' . implode('|', array_map('strval', $unresolved))),
                'method' => $route->method,
                'path' => $route->path,
                'field' => $fieldName,
                'unresolved_rules' => array_values(array_map('strval', $unresolved)),
            ];
        }
    }

    /**
     * @param array<string,mixed> $controllerData
     */
    private function collectResponseReviewItems(RouteDefinition $route, array $controllerData): void
    {
        $resolved = $this->responseAnalyzer->resolveSuccess($route, $controllerData);
        if ($resolved === null) {
            $this->reviewItems['unresolved_response_shape'][] = [
                'id' => sha1('response|' . $route->routeKey() . '|generic_success_fallback'),
                'method' => $route->method,
                'path' => $route->path,
                'reason' => 'generic_success_fallback',
            ];
            return;
        }

        foreach (($controllerData['return_responses'] ?? []) as $response) {
            if (!is_array($response)) {
                continue;
            }
            $kind = (string) ($response['kind'] ?? '');
            if (!in_array($kind, ['resource', 'resource_collection'], true)) {
                continue;
            }
            $this->reviewItems['low_confidence_examples'][] = [
                'id' => sha1('example|' . $route->routeKey() . '|' . $kind),
                'method' => $route->method,
                'path' => $route->path,
                'reason' => $kind . '_fallback_example',
            ];
        }
    }

    private function baseDocument(): array
    {
        return [
            'openapi' => '3.0.3',
            'info' => [
                'title' => 'Laravel API',
                'description' => '由 Laravel routes 自動產出的 API 文件',
                'version' => '1.0.0',
            ],
            'servers' => [
                ['url' => 'http://localhost:8000/api', 'description' => '本地開發環境'],
                ['url' => 'https://api.example.com', 'description' => '正式環境'],
            ],
            'components' => [
                'securitySchemes' => [
                    'bearerAuth' => [
                        'type' => 'http',
                        'scheme' => 'bearer',
                        'bearerFormat' => 'JWT',
                        'description' => 'Laravel Sanctum Token',
                    ],
                ],
                'schemas' => [
                    'ErrorResponse' => [
                        'type' => 'object',
                        'properties' => [
                            'message' => ['type' => 'string', 'description' => '錯誤訊息'],
                            'code' => ['type' => 'integer', 'description' => '錯誤碼或對應 HTTP 狀態'],
                            'errors' => [
                                'type' => 'object',
                                'description' => '欄位驗證錯誤',
                                'additionalProperties' => [
                                    'type' => 'array',
                                    'items' => ['type' => 'string'],
                                ],
                            ],
                            'data' => [
                                'type' => 'object',
                                'nullable' => true,
                                'description' => '額外錯誤資料',
                            ],
                        ],
                    ],
                    'PaginatedMeta' => [
                        'type' => 'object',
                        'properties' => [
                            'current_page' => ['type' => 'integer'],
                            'from' => ['type' => 'integer'],
                            'last_page' => ['type' => 'integer'],
                            'path' => ['type' => 'string'],
                            'per_page' => ['type' => 'integer'],
                            'to' => ['type' => 'integer'],
                            'total' => ['type' => 'integer'],
                        ],
                    ],
                    'PaginatedLinks' => [
                        'type' => 'object',
                        'properties' => [
                            'first' => ['type' => 'string'],
                            'last' => ['type' => 'string'],
                            'prev' => ['type' => 'string', 'nullable' => true],
                            'next' => ['type' => 'string', 'nullable' => true],
                        ],
                    ],
                ],
            ],
            'paths' => [],
        ];
    }

    private function stripNonJsonPrefix(string $value): string
    {
        $offsetBrace = strpos($value, '{');
        $offsetBracket = strpos($value, '[');
        $offsets = array_values(array_filter([$offsetBrace, $offsetBracket], static fn ($offset): bool => $offset !== false));
        if ($offsets === []) {
            return $value;
        }

        return substr($value, min($offsets));
    }

    private function findPhpFile(string $root, string $className): ?string
    {
        if (!is_dir($root) || $className === '') {
            return null;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($root, \FilesystemIterator::SKIP_DOTS)
        );

        /** @var \SplFileInfo $file */
        foreach ($iterator as $file) {
            if ($file->getExtension() !== 'php') {
                continue;
            }
            if ($file->getBasename('.php') !== $className) {
                continue;
            }
            return $file->getPathname();
        }

        return null;
    }

    private function loadYamlDocument(string $file): array
    {
        [$stdout, , $exitCode] = $this->shell->run(['yq', '-o=json', '.', $file]);
        if ($exitCode !== 0 || trim($stdout) === '') {
            return [];
        }

        $decoded = json_decode($stdout, true);
        return is_array($decoded) ? $decoded : [];
    }

    private function recursiveMerge(mixed $base, mixed $overlay): mixed
    {
        if (!is_array($base) || !is_array($overlay)) {
            return $overlay;
        }

        if (array_is_list($base) || array_is_list($overlay)) {
            return $overlay;
        }

        $merged = $base;
        foreach ($overlay as $key => $value) {
            if (array_key_exists($key, $merged)) {
                $merged[$key] = $this->recursiveMerge($merged[$key], $value);
                continue;
            }
            $merged[$key] = $value;
        }

        return $merged;
    }

    private function time(string $stage, callable $callback): mixed
    {
        $start = microtime(true);
        $result = $callback();
        $durationMs = (int) round((microtime(true) - $start) * 1000);
        $detail = $this->timingDetails[$stage] ?? '';
        $this->timings[$stage] = [
            'duration_ms' => $durationMs,
            'detail' => $detail,
        ];
        $payload = $detail !== '' ? ['detail' => $detail] : [];
        $this->events->timing($stage, $durationMs, $payload);
        return $result;
    }
}
