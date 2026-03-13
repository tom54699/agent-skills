<?php

namespace LaravelApiDocs\InferCandidates;

final class ClassIndex
{
    /** @var list<ClassSymbol> */
    public readonly array $symbols;
    /** @var array<string, ClassSymbol> */
    private readonly array $byFqcn;
    /** @var array<string, list<ClassSymbol>> */
    private readonly array $byShortName;
    /** @var array<string, list<ClassSymbol>> */
    private readonly array $byKindAndShortName;

    /**
     * @param list<ClassSymbol> $symbols
     */
    public function __construct(array $symbols)
    {
        $this->symbols = $symbols;
        $byFqcn = [];
        $byShortName = [];
        $byKindAndShortName = [];
        foreach ($symbols as $symbol) {
            $byFqcn[ltrim($symbol->fqcn, '\\')] = $symbol;
            $byShortName[$symbol->shortName][] = $symbol;
            $byKindAndShortName[$symbol->kind . '|' . $symbol->shortName][] = $symbol;
        }
        $this->byFqcn = $byFqcn;
        $this->byShortName = $byShortName;
        $this->byKindAndShortName = $byKindAndShortName;
    }

    public function count(): int
    {
        return count($this->symbols);
    }

    public function findByFqcn(string $fqcn): ?ClassSymbol
    {
        $normalized = ltrim($fqcn, '\\');
        return $this->byFqcn[$normalized] ?? null;
    }

    /**
     * @return list<ClassSymbol>
     */
    public function findByShortName(string $shortName, ?string $kind = null): array
    {
        if ($kind !== null) {
            return $this->byKindAndShortName[$kind . '|' . $shortName] ?? [];
        }

        return $this->byShortName[$shortName] ?? [];
    }
}
