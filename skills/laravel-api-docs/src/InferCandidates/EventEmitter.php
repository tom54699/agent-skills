<?php

namespace LaravelApiDocs\InferCandidates;

final class EventEmitter
{
    public function __construct(
        private readonly bool $enabled,
        private readonly bool $debug,
    ) {
    }

    public function progress(string $stage, int $current, int $total, string $message): void
    {
        if (!$this->enabled) {
            return;
        }

        $this->emit([
            'type' => 'progress',
            'stage' => $stage,
            'current' => $current,
            'total' => $total,
            'message' => $message,
        ]);
    }

    public function timing(string $stage, int $durationMs, array $detail = []): void
    {
        if (!$this->enabled) {
            return;
        }

        $this->emit([
            'type' => 'timing',
            'stage' => $stage,
            'duration_ms' => $durationMs,
            'detail' => $detail,
        ]);
    }

    public function debug(string $message, array $context = []): void
    {
        if (!$this->debug) {
            return;
        }

        $this->emit([
            'type' => 'debug',
            'message' => $message,
            'context' => $context,
        ]);
    }

    /**
     * Always emitted regardless of $enabled/$debug — used for conditions the
     * caller must not silently lose in progress/timing noise.
     */
    public function warning(string $message, array $context = []): void
    {
        $this->emit([
            'type' => 'warning',
            'message' => $message,
            'context' => $context,
        ]);
    }

    private function emit(array $payload): void
    {
        fwrite(STDERR, json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    }
}
