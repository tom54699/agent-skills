<?php

namespace LaravelApiDocs\InferCandidates;

final class ChangeIndex
{
    /**
     * @param list<string> $changedFiles
     * @param array<string,list<string>> $changedServiceMethods
     * @param list<string> $changedControllerFiles
     * @param list<string> $changedRequestClasses
     * @param list<string> $changedResourceClasses
     * @param list<string> $changedServiceClasses
     * @param list<string> $changedExceptionClasses
     * @param list<string> $changedControllerActions
     * @param list<string> $routeActionHints
     */
    public function __construct(
        public readonly array $changedFiles,
        public readonly array $changedServiceMethods,
        public readonly ?string $diffRange,
        public readonly array $changedControllerFiles,
        public readonly array $changedRequestClasses,
        public readonly array $changedResourceClasses,
        public readonly array $changedServiceClasses,
        public readonly array $changedExceptionClasses,
        public readonly array $changedControllerActions,
        public readonly array $routeActionHints,
    ) {
    }

    public function changedFileCount(): int
    {
        return count($this->changedFiles);
    }

    public function changedServiceMethodCount(): int
    {
        return array_sum(array_map(static fn (array $methods): int => count($methods), $this->changedServiceMethods));
    }

    public function hasChangedFile(string $file): bool
    {
        return in_array($file, $this->changedFiles, true);
    }

    public function routesChanged(): bool
    {
        foreach ($this->changedFiles as $file) {
            if (str_starts_with($file, 'routes/')) {
                return true;
            }
        }

        return false;
    }
}
