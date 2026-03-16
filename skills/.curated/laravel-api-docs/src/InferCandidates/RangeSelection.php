<?php

namespace LaravelApiDocs\InferCandidates;

final class RangeSelection
{
    /**
     * @param list<string> $changedFiles
     */
    public function __construct(
        public readonly string $toTime,
        public readonly ?string $fromTime,
        public readonly string $initMode,
        public readonly string $rangeSource,
        public readonly ?string $diffRange,
        public readonly string $diffRangeSource,
        public readonly string $baselineSource,
        public readonly bool $hasSuccessHistory,
        public readonly bool $hasOpenApiBaseline,
        public readonly bool $initIncludeUpdated,
        public readonly bool $initExcludeDeleted,
        public readonly array $changedFiles,
    ) {
    }
}
