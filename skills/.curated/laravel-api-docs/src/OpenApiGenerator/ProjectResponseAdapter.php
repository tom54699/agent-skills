<?php

namespace LaravelApiDocs\OpenApiGenerator;

interface ProjectResponseAdapter
{
    /**
     * @param array<string,mixed> $controllerData
     * @return array{schema:array<string,mixed>,example:mixed}|null
     */
    public function resolveSuccess(array $controllerData): ?array;

    /**
     * @param array<string,mixed> $apiResponse
     * @return array{description:string,example:array<string,mixed>}|null
     */
    public function resolveError(array $apiResponse): ?array;
}
