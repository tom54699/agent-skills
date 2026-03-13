<?php

namespace LaravelApiDocs\InferCandidates;

final class ServiceParser
{
    /**
     * @return array{exceptions:list<array<string,mixed>>,error_messages:list<mixed>,base_exception_getter_usage:bool,getter_methods:list<string>,catches_base_exception:bool,method_exceptions:array<string,list<string>>}
     */
    public function parse(string $serviceFile): array
    {
        if ($serviceFile === '' || !is_file($serviceFile)) {
            return $this->emptyMetadata();
        }

        $content = file_get_contents($serviceFile);
        if ($content === false) {
            return $this->emptyMetadata();
        }

        $exceptions = $this->extractExceptions($content);
        $getterMethods = $this->detectGetterMethods($content);

        return [
            'exceptions' => $exceptions,
            'error_messages' => [],
            'base_exception_getter_usage' => $getterMethods !== [],
            'getter_methods' => $getterMethods,
            'catches_base_exception' => preg_match('/catch[[:space:]]*\([^)]*BaseException[^)]*\)/', $content) === 1,
            'method_exceptions' => $this->extractMethodExceptions($content),
        ];
    }

    /**
     * @return array{exceptions:list<array<string,mixed>>,error_messages:list<mixed>,base_exception_getter_usage:bool,getter_methods:list<string>,catches_base_exception:bool,method_exceptions:array<string,list<string>>}
     */
    public function emptyMetadata(): array
    {
        return [
            'exceptions' => [],
            'error_messages' => [],
            'base_exception_getter_usage' => false,
            'getter_methods' => [],
            'catches_base_exception' => false,
            'method_exceptions' => [],
        ];
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractExceptions(string $content): array
    {
        $rows = [];
        foreach (preg_split('/\R/', $content) ?: [] as $line) {
            if (!str_contains($line, 'throw new ')) {
                continue;
            }

            if (preg_match('/throw new\s+([A-Za-z0-9_\\\\]+)/', $line, $exceptionMatches) !== 1) {
                continue;
            }

            $row = ['exception' => $exceptionMatches[1]];
            if (preg_match('/"([^"]+)"/', $line, $messageMatches) === 1 || preg_match("/'([^']+)'/", $line, $messageMatches) === 1) {
                $row['message'] = $messageMatches[1];
            }
            if (preg_match('/,\s*([0-9]+)/', $line, $codeMatches) === 1) {
                $row['code'] = (int) $codeMatches[1];
            }
            $rows[] = $row;
        }

        foreach (preg_split('/\R/', $content) ?: [] as $line) {
            if (preg_match('/ValidationException|->fails\(\)|->errors\(\)/', $line) !== 1) {
                continue;
            }

            if (preg_match('/"([^"]+)"/', $line, $messageMatches) === 1 || preg_match("/'([^']+)'/", $line, $messageMatches) === 1) {
                $rows[] = [
                    'exception' => 'ValidationException',
                    'message' => $messageMatches[1],
                    'code' => 422,
                ];
            }
        }

        return $rows;
    }

    /**
     * @return list<string>
     */
    private function detectGetterMethods(string $content): array
    {
        $methods = [];
        foreach (['getErrorCode', 'getStatusCode', 'getData'] as $method) {
            if (preg_match('/' . preg_quote($method, '/') . '\(/', $content) === 1) {
                $methods[] = $method;
            }
        }

        return $methods;
    }

    /**
     * @return array<string,list<string>>
     */
    private function extractMethodExceptions(string $content): array
    {
        $methodExceptions = [];
        $currentMethod = null;

        foreach (preg_split('/\R/', $content) ?: [] as $line) {
            if (preg_match('/(?:public|protected|private)\s+function\s+([A-Za-z_]\w*)\s*\(/', $line, $methodMatches) === 1) {
                $currentMethod = $methodMatches[1];
            }

            if ($currentMethod === null) {
                continue;
            }

            if (preg_match_all('/throw\s+new\s+([A-Za-z_][A-Za-z0-9_\\\\]*)/', $line, $throwMatches)) {
                foreach ($throwMatches[1] as $exception) {
                    $methodExceptions[$currentMethod][] = $exception;
                }
            }

            if (preg_match_all('/catch\s*\(([^)]*)\)/', $line, $catchMatches)) {
                foreach ($catchMatches[1] as $inner) {
                    $inner = str_replace('|', ' ', $inner);
                    if (preg_match_all('/([A-Za-z_][A-Za-z0-9_\\\\]*)/', $inner, $tokenMatches)) {
                        foreach ($tokenMatches[1] as $exception) {
                            $methodExceptions[$currentMethod][] = $exception;
                        }
                    }
                }
            }
        }

        foreach ($methodExceptions as $method => $exceptions) {
            $methodExceptions[$method] = array_values(array_unique($exceptions));
            sort($methodExceptions[$method]);
        }

        return $methodExceptions;
    }
}
