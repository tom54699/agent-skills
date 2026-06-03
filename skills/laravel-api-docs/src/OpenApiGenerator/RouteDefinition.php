<?php

namespace LaravelApiDocs\OpenApiGenerator;

final class RouteDefinition
{
    public function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly string $name,
        public readonly string $controller,
        public readonly string $action,
        /** @var list<string> */
        public readonly array $middleware = [],
    ) {
    }

    public function routeKey(): string
    {
        return strtolower($this->method) . ' ' . $this->path;
    }
}
