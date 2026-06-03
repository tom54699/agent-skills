<?php

namespace LaravelApiDocs\InferCandidates;

final class RouteEntry
{
    public function __construct(
        public readonly string $method,
        public readonly string $path,
        public readonly string $controller,
        public readonly string $action,
    ) {
    }

    public function actionKey(): string
    {
        return $this->controller . '@' . ($this->action !== '' ? $this->action : '__invoke');
    }

    public function routeKey(): string
    {
        return $this->method . ' ' . $this->path;
    }
}
