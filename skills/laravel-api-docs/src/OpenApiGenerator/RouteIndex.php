<?php

namespace LaravelApiDocs\OpenApiGenerator;

final class RouteIndex
{
    /** @param list<RouteDefinition> $routes */
    public function __construct(
        public readonly array $routes,
    ) {
    }

    public function count(): int
    {
        return count($this->routes);
    }
}
