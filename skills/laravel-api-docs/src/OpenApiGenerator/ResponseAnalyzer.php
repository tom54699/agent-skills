<?php

namespace LaravelApiDocs\OpenApiGenerator;

final class ResponseAnalyzer
{
    /** @var list<ProjectResponseAdapter> */
    private array $adapters = [];

    public function __construct()
    {
        $this->adapters[] = new ApiResponseProjectAdapter($this);
    }

    /**
     * @param array<string,mixed> $controllerData
     * @return array{schema:array<string,mixed>,example:mixed}|null
     */
    public function resolveSuccess(RouteDefinition $route, array $controllerData): ?array
    {
        foreach ($this->adapters as $adapter) {
            $resolved = $adapter->resolveSuccess($controllerData);
            if ($resolved !== null) {
                return $resolved;
            }
        }

        foreach (array_reverse($controllerData['return_responses'] ?? []) as $response) {
            if (!is_array($response)) {
                continue;
            }

            $status = (int) ($response['status'] ?? 200);
            if ($status < 200 || $status >= 400) {
                continue;
            }

            $kind = (string) ($response['kind'] ?? 'unknown');
            if (in_array($kind, ['json_helper', 'json_response', 'array_literal'], true)) {
                $payload = $response['payload_literal'] ?? null;
                if ($payload === null && trim((string) ($response['payload_expr'] ?? '')) !== 'null') {
                    continue;
                }

                return [
                    'schema' => $this->schemaFromLiteral($payload),
                    'example' => $payload,
                ];
            }

            if ($kind === 'resource') {
                return [
                    'schema' => ['type' => 'object'],
                    'example' => new \stdClass(),
                ];
            }

            if ($kind === 'resource_collection') {
                return [
                    'schema' => ['type' => 'array', 'items' => ['type' => 'object']],
                    'example' => [new \stdClass()],
                ];
            }
        }

        return null;
    }

    /**
     * @param array<string,mixed> $apiResponse
     * @return array{description:string,example:array<string,mixed>}|null
     */
    public function resolveError(array $apiResponse): ?array
    {
        foreach ($this->adapters as $adapter) {
            $resolved = $adapter->resolveError($apiResponse);
            if ($resolved !== null) {
                return $resolved;
            }
        }

        return null;
    }

    /**
     * @return array<string,mixed>
     */
    public function schemaFromLiteral(mixed $payload): array
    {
        if ($payload === null) {
            return [
                'type' => 'object',
                'nullable' => true,
            ];
        }

        if (is_bool($payload)) {
            return ['type' => 'boolean'];
        }

        if (is_int($payload)) {
            return ['type' => 'integer'];
        }

        if (is_float($payload)) {
            return ['type' => 'number'];
        }

        if (is_string($payload)) {
            return ['type' => 'string'];
        }

        if (is_array($payload)) {
            if (array_is_list($payload)) {
                $first = $payload[0] ?? null;
                return [
                    'type' => 'array',
                    'items' => $this->schemaFromLiteral($first),
                ];
            }

            $properties = [];
            $required = [];
            foreach ($payload as $key => $value) {
                if (!is_string($key) && !is_int($key)) {
                    continue;
                }
                $properties[(string) $key] = $this->schemaFromLiteral($value);
                $required[] = (string) $key;
            }

            return [
                'type' => 'object',
                'properties' => $properties === [] ? (object) [] : $properties,
                'required' => $required,
            ];
        }

        return ['type' => 'object'];
    }
}
