<?php

namespace LaravelApiDocs\InferCandidates;

final class ActionIndex
{
    /** @var array<string, ActionMetadata> */
    private readonly array $items;

    /**
     * @param array<string, ActionMetadata> $items
     */
    public function __construct(array $items)
    {
        $this->items = $items;
    }

    public function count(): int
    {
        return count($this->items);
    }

    public function get(string $actionKey): ?ActionMetadata
    {
        return $this->items[$actionKey] ?? null;
    }
}
