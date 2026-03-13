#!/usr/bin/env php
<?php

require dirname(__DIR__) . '/src/OpenApiGenerator/bootstrap.php';

use LaravelApiDocs\InferCandidates\EventEmitter;
use LaravelApiDocs\InferCandidates\Shell;
use LaravelApiDocs\OpenApiGenerator\GeneratorOptions;
use LaravelApiDocs\OpenApiGenerator\OpenApiGenerator;

try {
    $projectRoot = getcwd();
    if ($projectRoot === false || !is_file($projectRoot . '/artisan') || !is_dir($projectRoot . '/routes')) {
        throw new RuntimeException('錯誤：請在 Laravel 專案根目錄執行（需有 artisan 與 routes/）');
    }

    $options = GeneratorOptions::fromArgv($argv, $projectRoot);
    $events = new EventEmitter($options->progressEnabled, false);
    $shell = new Shell($projectRoot);
    $generator = new OpenApiGenerator($options, $events, $shell);

    $result = $generator->run();
    $json = json_encode(
        $result,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );
    if ($json === false) {
        throw new RuntimeException('Failed to encode generator result');
    }

    echo $json . PHP_EOL;
} catch (Throwable $throwable) {
    fwrite(STDERR, $throwable->getMessage() . PHP_EOL);
    exit(1);
}
