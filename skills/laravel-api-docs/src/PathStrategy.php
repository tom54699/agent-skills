<?php

namespace LaravelApiDocs;

final class PathStrategy
{
    public const KEEP_FULL_PATH = 'keep-full-path';
    public const STRIP_API_PREFIX_TO_SERVER = 'strip-api-prefix-to-server';

    /**
     * @return list<string>
     */
    public static function all(): array
    {
        return [
            self::KEEP_FULL_PATH,
            self::STRIP_API_PREFIX_TO_SERVER,
        ];
    }

    public static function normalize(string $strategy): string
    {
        $normalized = strtolower(trim($strategy));
        if (!in_array($normalized, self::all(), true)) {
            throw new \InvalidArgumentException('錯誤：--path-strategy 只能是 keep-full-path 或 strip-api-prefix-to-server');
        }

        return $normalized;
    }

    public static function isValid(?string $strategy): bool
    {
        return is_string($strategy) && in_array(strtolower(trim($strategy)), self::all(), true);
    }

    public static function normalizeRoutePath(string $rawUri, string $strategy): ?string
    {
        $strategy = self::normalize($strategy);
        $uri = trim($rawUri, '/');
        if ($uri === '') {
            return null;
        }

        if ($uri !== 'api' && !str_starts_with($uri, 'api/')) {
            return null;
        }

        if ($strategy === self::KEEP_FULL_PATH) {
            return self::normalizePath('/' . $uri);
        }

        $normalizedUri = preg_replace('#^api/?#', '', $uri);
        if ($normalizedUri === null) {
            $normalizedUri = $uri;
        }

        return self::normalizePath('/' . ltrim($normalizedUri, '/'));
    }

    /**
     * @param array<string,mixed> $document
     */
    public static function detectFromOpenApiDocument(array $document): ?string
    {
        $paths = $document['paths'] ?? null;
        if (is_array($paths) && $paths !== []) {
            foreach (array_keys($paths) as $path) {
                if (!is_string($path)) {
                    continue;
                }
                if ($path === '/api' || str_starts_with($path, '/api/')) {
                    return self::KEEP_FULL_PATH;
                }
            }

            return self::STRIP_API_PREFIX_TO_SERVER;
        }

        $servers = $document['servers'] ?? null;
        if (is_array($servers)) {
            foreach ($servers as $server) {
                if (!is_array($server)) {
                    continue;
                }
                $url = (string) ($server['url'] ?? '');
                if ($url === '') {
                    continue;
                }
                $path = (string) (parse_url($url, PHP_URL_PATH) ?? '');
                if ($path === '/api' || str_starts_with($path, '/api/')) {
                    return self::STRIP_API_PREFIX_TO_SERVER;
                }
            }
        }

        return null;
    }

    /**
     * @return list<array{url:string,description:string}>
     */
    public static function defaultServers(string $strategy): array
    {
        $strategy = self::normalize($strategy);

        if ($strategy === self::KEEP_FULL_PATH) {
            return [
                ['url' => 'http://localhost:8000', 'description' => '本地開發環境'],
                ['url' => 'https://api.example.com', 'description' => '正式環境'],
            ];
        }

        return [
            ['url' => 'http://localhost:8000/api', 'description' => '本地開發環境'],
            ['url' => 'https://api.example.com/api', 'description' => '正式環境'],
        ];
    }

    private static function normalizePath(string $path): string
    {
        $normalized = '/' . ltrim($path, '/');
        $trimmed = rtrim($normalized, '/');

        return $trimmed === '' ? '/' : $trimmed;
    }
}
