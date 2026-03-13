<?php

namespace LaravelApiDocs\InferCandidates;

final class RouteCandidateContext
{
    /**
     * @param array{exceptions:list<array<string,mixed>>,error_messages:list<mixed>,base_exception_getter_usage:bool,getter_methods:list<string>,catches_base_exception:bool,method_exceptions:array<string,list<string>>} $serviceMetadata
     */
    public function __construct(
        public readonly RouteEntry $route,
        public readonly ActionMetadata $actionMetadata,
        public readonly ?string $controllerFile,
        public readonly ?string $formRequestFile,
        public readonly ?string $resourceFile,
        public readonly ?string $serviceFile,
        public readonly array $serviceMetadata,
        public readonly int $requestRuleCount,
    ) {
    }
}
