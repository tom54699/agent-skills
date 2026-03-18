<?php

namespace LaravelApiDocs\InferCandidates;

final class ActionMetadata
{
    /**
     * @param list<string> $throws
     * @param list<array{receiver:string,method:string}> $serviceCalls
     * @param list<string> $exceptionRefs
     */
    public function __construct(
        public readonly string $controller,
        public readonly string $action,
        public readonly ?string $controllerFile,
        public readonly string $description,
        public readonly array $throws,
        public readonly string $formRequest,
        public readonly string $resource,
        public readonly bool $inlineValidationDetected,
        public readonly bool $baseExceptionGetterUsage,
        public readonly bool $throwableFallbackDetected,
        public readonly int $apiResponseCount,
        public readonly int $documentationParameterCount,
        public readonly int $documentationResponseCount,
        public readonly array $serviceCalls,
        public readonly array $exceptionRefs,
    ) {
    }

    public function actionKey(): string
    {
        return $this->controller . '@' . $this->action;
    }
}
