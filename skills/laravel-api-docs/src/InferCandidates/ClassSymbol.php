<?php

namespace LaravelApiDocs\InferCandidates;

final class ClassSymbol
{
    public function __construct(
        public readonly string $fqcn,
        public readonly string $shortName,
        public readonly string $path,
        public readonly string $kind,
    ) {
    }
}
