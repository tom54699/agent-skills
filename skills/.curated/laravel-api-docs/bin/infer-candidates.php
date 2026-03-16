#!/usr/bin/env php
<?php

require dirname(__DIR__) . '/src/InferCandidates/bootstrap.php';

use LaravelApiDocs\InferCandidates\Analyzer;
use LaravelApiDocs\InferCandidates\AnalyzerOptions;
use LaravelApiDocs\InferCandidates\EventEmitter;
use LaravelApiDocs\InferCandidates\Shell;

try {
    $projectRoot = getcwd();
    if ($projectRoot === false || !is_file($projectRoot . '/artisan') || !is_dir($projectRoot . '/routes')) {
        throw new RuntimeException('錯誤：請在 Laravel 專案根目錄執行（需有 artisan 與 routes/）');
    }

    $options = AnalyzerOptions::fromArgv($argv, $projectRoot);
    $events = new EventEmitter($options->progressEnabled, $options->debug);
    $shell = new Shell($projectRoot);
    $analyzer = new Analyzer($options, $events, $shell);

    $result = $analyzer->run();
    $json = json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($json === false) {
        throw new RuntimeException('Failed to encode analyzer result');
    }

    if ($options->outputFile !== null) {
        file_put_contents($options->outputFile, $json . PHP_EOL);
    }

    echo $json . PHP_EOL;
} catch (Throwable $throwable) {
    fwrite(STDERR, $throwable->getMessage() . PHP_EOL);
    exit(1);
}
