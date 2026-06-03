<?php

namespace LaravelApiDocs\InferCandidates;

final class RouteIndex
{
    /** @var array<string, bool> */
    private readonly array $routeKeys;

    /**
     * @param list<RouteEntry> $routes
     */
    public function __construct(public readonly array $routes)
    {
        $routeKeys = [];
        foreach ($routes as $route) {
            $routeKeys[$route->routeKey()] = true;
        }
        $this->routeKeys = $routeKeys;
    }

    public function count(): int
    {
        return count($this->routes);
    }

    /**
     * @return list<string>
     */
    public function uniqueActionKeys(): array
    {
        $keys = [];
        foreach ($this->routes as $route) {
            if ($route->controller === '') {
                continue;
            }
            $keys[$route->actionKey()] = true;
        }

        return array_keys($keys);
    }

    public function hasRouteKey(string $routeKey): bool
    {
        return isset($this->routeKeys[$routeKey]);
    }

    /**
     * @return list<string>
     */
    public function routeKeys(): array
    {
        return array_keys($this->routeKeys);
    }
}
