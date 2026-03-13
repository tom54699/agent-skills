<?php

namespace LaravelApiDocs\InferCandidates;

final class AnalyzerOptions
{
    public function __construct(
        public readonly string $historyFile,
        public readonly string $openApiFile,
        public readonly ?string $fromCommit,
        public readonly string $analysisMode,
        public readonly int $lookbackCommits,
        /** @var list<string> */
        public readonly array $scanRoots,
        public readonly bool $debug,
        public readonly ?string $outputFile,
        public readonly bool $progressEnabled,
        public readonly string $projectRoot,
    ) {
    }

    public static function fromArgv(array $argv, string $projectRoot): self
    {
        $historyFile = 'docs/api-docs/history/apidog-sync-history.jsonl';
        $openApiFile = 'docs/api-docs/openapi.yaml';
        $fromCommit = null;
        $analysisMode = 'fast';
        $lookbackCommits = (int) (getenv('SYNC_LOOKBACK_COMMITS') ?: 50);
        $scanRootsRaw = getenv('SYNC_SCAN_ROOTS') ?: 'app';
        $debug = false;
        $outputFile = null;
        $progressEnabled = true;

        for ($i = 1, $count = count($argv); $i < $count; $i++) {
            $arg = $argv[$i];
            switch ($arg) {
                case '--history':
                    $historyFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--openapi':
                    $openApiFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--from-commit':
                    $fromCommit = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--analysis-mode':
                    $analysisMode = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--scan-roots':
                    $scanRootsRaw = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--debug':
                    $debug = true;
                    break;
                case '--output':
                    $outputFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--no-progress':
                    $progressEnabled = false;
                    break;
                case '-h':
                case '--help':
                    self::printUsage();
                    exit(0);
                case '--lookback-commits':
                    $lookbackCommits = (int) self::requireValue($argv, ++$i, $arg);
                    break;
                default:
                    throw new \InvalidArgumentException("Unknown argument: {$arg}");
            }
        }

        if (!in_array($analysisMode, ['fast', 'enhanced'], true)) {
            throw new \InvalidArgumentException('錯誤：--analysis-mode 只能是 fast 或 enhanced');
        }
        if ($lookbackCommits <= 0) {
            throw new \InvalidArgumentException('錯誤：--lookback-commits 必須為正整數');
        }

        return new self(
            historyFile: $historyFile,
            openApiFile: $openApiFile,
            fromCommit: $fromCommit,
            analysisMode: $analysisMode,
            lookbackCommits: $lookbackCommits,
            scanRoots: self::normalizeRoots($scanRootsRaw),
            debug: $debug,
            outputFile: $outputFile,
            progressEnabled: $progressEnabled,
            projectRoot: $projectRoot,
        );
    }

    private static function requireValue(array $argv, int $index, string $flag): string
    {
        if (!isset($argv[$index]) || str_starts_with($argv[$index], '-')) {
            throw new \InvalidArgumentException("Missing value for {$flag}");
        }

        return $argv[$index];
    }

    /**
     * @return list<string>
     */
    private static function normalizeRoots(string $raw): array
    {
        $parts = preg_split('/[:,]/', $raw) ?: [];
        $parts = array_map(static fn (string $part): string => trim($part), $parts);
        $parts = array_values(array_filter($parts, static fn (string $part): bool => $part !== ''));

        return array_values(array_unique($parts));
    }

    private static function printUsage(): void
    {
        fwrite(STDERR, <<<USAGE
Usage: infer-candidates.php [options]

Options:
  --history FILE
  --openapi FILE
  --from-commit COMMIT
  --analysis-mode MODE
  --scan-roots ROOTS
  --debug
  --output FILE
  --no-progress
  -h, --help
USAGE
        );
    }
}
