<?php

namespace LaravelApiDocs\OpenApiGenerator;

final class GeneratorOptions
{
    public function __construct(
        public readonly bool $incremental,
        public readonly ?string $baseFile,
        public readonly bool $skipResource,
        public readonly ?string $candidateFile,
        public readonly ?string $reviewFile,
        public readonly string $outputDir,
        public readonly string $openApiFile,
        public readonly bool $progressEnabled,
        public readonly string $projectRoot,
    ) {
    }

    public static function fromArgv(array $argv, string $projectRoot): self
    {
        $incremental = false;
        $baseFile = null;
        $skipResource = false;
        $candidateFile = null;
        $reviewFile = null;
        $outputDir = 'docs/api-docs';
        $openApiFile = $outputDir . '/openapi.yaml';
        $progressEnabled = true;

        for ($i = 1, $count = count($argv); $i < $count; $i++) {
            $arg = $argv[$i];
            switch ($arg) {
                case '--incremental':
                    $incremental = true;
                    break;
                case '--candidate-file':
                    $candidateFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--base':
                    $baseFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--review-file':
                    $reviewFile = self::requireValue($argv, ++$i, $arg);
                    break;
                case '--skip-resource':
                    $skipResource = true;
                    break;
                case '--no-progress':
                    $progressEnabled = false;
                    break;
                case '-h':
                case '--help':
                    self::printUsage();
                    exit(0);
                default:
                    throw new \InvalidArgumentException("未知參數：{$arg}");
            }
        }

        return new self(
            incremental: $incremental,
            baseFile: $baseFile,
            skipResource: $skipResource,
            candidateFile: $candidateFile,
            reviewFile: $reviewFile,
            outputDir: $outputDir,
            openApiFile: $openApiFile,
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

    private static function printUsage(): void
    {
        fwrite(STDERR, <<<USAGE
Usage: gen-openapi.php [options]

Options:
  --incremental
  --candidate-file FILE
  --base FILE
  --review-file FILE
  --skip-resource
  --no-progress
  -h, --help
USAGE
        );
    }
}
