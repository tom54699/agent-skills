<?php

namespace LaravelApiDocs\InferCandidates;

final class Shell
{
    public function __construct(
        private readonly string $workingDirectory,
    ) {
    }

    public function mustRun(array $command): string
    {
        [$stdout, $stderr, $code] = $this->run($command);
        if ($code !== 0) {
            throw new \RuntimeException(sprintf(
                "Command failed (%s): %s",
                $code,
                trim($stderr) !== '' ? trim($stderr) : implode(' ', $command),
            ));
        }

        return $stdout;
    }

    /**
     * @return array{0:string,1:string,2:int}
     */
    public function run(array $command): array
    {
        $descriptorSpec = [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $process = proc_open($command, $descriptorSpec, $pipes, $this->workingDirectory);
        if (!is_resource($process)) {
            throw new \RuntimeException('Failed to start process');
        }

        $stdout = stream_get_contents($pipes[1]) ?: '';
        fclose($pipes[1]);
        $stderr = stream_get_contents($pipes[2]) ?: '';
        fclose($pipes[2]);
        $exitCode = proc_close($process);

        return [$stdout, $stderr, $exitCode];
    }
}
