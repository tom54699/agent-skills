<?php

namespace LaravelApiDocs\InferCandidates;

final class ControllerParser
{
    /**
     * @return array<string,mixed>
     */
    public function parse(string $controllerFile, string $methodName): array
    {
        if ($controllerFile === '' || $methodName === '' || !is_file($controllerFile)) {
            return [];
        }

        $content = file_get_contents($controllerFile);
        if ($content === false) {
            return [];
        }

        [$signature, $phpDoc, $methodSource] = $this->extractMethodData($content, $methodName);

        return [
            'description' => $this->extractDescription($phpDoc),
            'throws' => $this->extractThrows($phpDoc),
            'form_request' => $this->findFormRequest($signature),
            'resource' => $this->findResource($methodSource),
            'error_messages' => $this->extractErrorMessages($methodSource),
            'inline_validation_detected' => preg_match('/->validate\(|Validator::make\(/', $methodSource) === 1,
            'base_exception_getter_usage' => preg_match('/getErrorCode\(|getStatusCode\(|getData\(/', $methodSource) === 1,
            'throwable_fallback_detected' => (
                preg_match('/catch\s*\([^)]*Throwable[^)]*\)/', $methodSource) === 1
                && preg_match('/apiResponse\s*\(/', $methodSource) === 1
                && preg_match('/,\s*500\s*\)/', $methodSource) === 1
            ),
            'api_responses' => $this->extractApiResponses($methodSource),
            'return_responses' => $this->extractReturnResponses($methodSource),
            'service_calls' => $this->extractServiceCalls($methodSource),
            'exception_refs' => $this->extractExceptionRefs($methodSource),
        ];
    }

    /**
     * @return array{0:string,1:string,2:string}
     */
    private function extractMethodData(string $content, string $methodName): array
    {
        $pattern = '/function\s+' . preg_quote($methodName, '/') . '\s*\(/';
        if (!preg_match($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
            return ['', '', ''];
        }

        $functionOffset = $matches[0][1];
        $prefix = substr($content, 0, $functionOffset);
        $phpDoc = '';

        if (preg_match_all('/\/\*\*.*?\*\//s', $prefix, $docMatches, PREG_OFFSET_CAPTURE)) {
            $lastDoc = end($docMatches[0]);
            if ($lastDoc !== false) {
                $phpDoc = $lastDoc[0];
            }
        }

        $paramStart = strpos($content, '(', $functionOffset);
        if ($paramStart === false) {
            return ['', $phpDoc, ''];
        }

        $paramEnd = $this->scanBalanced($content, $paramStart, '(', ')');
        if ($paramEnd === null) {
            return ['', $phpDoc, ''];
        }

        $signature = substr($content, $functionOffset, $paramEnd - $functionOffset + 1);
        $braceStart = strpos($content, '{', $paramEnd);
        if ($braceStart === false) {
            return [$signature, $phpDoc, $signature];
        }

        $braceEnd = $this->scanBalanced($content, $braceStart, '{', '}');
        if ($braceEnd === null) {
            return [$signature, $phpDoc, substr($content, $functionOffset)];
        }

        $methodSource = substr($content, $functionOffset, $braceEnd - $functionOffset + 1);
        return [$signature, $phpDoc, $methodSource];
    }

    private function extractDescription(string $phpDoc): string
    {
        if ($phpDoc === '') {
            return '';
        }

        foreach (preg_split('/\R/', $phpDoc) ?: [] as $line) {
            $line = trim($line);
            $line = preg_replace('/^\/\*\*?/', '', $line) ?? $line;
            $line = preg_replace('/^\*/', '', $line) ?? $line;
            $line = preg_replace('/\*\/$/', '', $line) ?? $line;
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '@')) {
                continue;
            }

            return $line;
        }

        return '';
    }

    /**
     * @return list<string>
     */
    private function extractThrows(string $phpDoc): array
    {
        if ($phpDoc === '') {
            return [];
        }

        $throws = [];
        foreach (preg_split('/\R/', $phpDoc) ?: [] as $line) {
            if (preg_match('/@throws\s+(.+)/', $line, $matches) === 1) {
                $throws[] = trim($matches[1]);
            }
        }

        return array_values(array_filter($throws, static fn (string $value): bool => $value !== ''));
    }

    private function findFormRequest(string $signature): string
    {
        if (preg_match('/\b([A-Za-z_][A-Za-z0-9_]*Request)\b/', $signature, $matches) === 1) {
            return $matches[1];
        }

        return '';
    }

    private function findResource(string $methodSource): string
    {
        if (preg_match('/return\s+new\s+([A-Za-z_][A-Za-z0-9_]*Resource)\b/s', $methodSource, $matches) === 1) {
            return $matches[1];
        }

        return '';
    }

    /**
     * @return list<string>
     */
    private function extractErrorMessages(string $methodSource): array
    {
        $messages = [];
        foreach (preg_split('/\R/', $methodSource) ?: [] as $line) {
            if (!str_contains($line, 'throw new')) {
                continue;
            }
            if (preg_match('/"([^"]+)"/', $line, $matches) === 1) {
                $messages[] = $matches[1];
                continue;
            }
            if (preg_match("/'([^']+)'/", $line, $matches) === 1) {
                $messages[] = $matches[1];
            }
        }

        return array_values(array_filter($messages, static fn (string $value): bool => $value !== ''));
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractApiResponses(string $methodSource): array
    {
        $responses = [];
        $offset = 0;

        while (preg_match('/apiResponse\s*\(/', $methodSource, $matches, PREG_OFFSET_CAPTURE, $offset) === 1) {
            $start = $matches[0][1];
            $parenStart = strpos($methodSource, '(', $start);
            if ($parenStart === false) {
                break;
            }

            $parenEnd = $this->scanBalanced($methodSource, $parenStart, '(', ')');
            if ($parenEnd === null) {
                break;
            }

            $call = substr($methodSource, $start, $parenEnd - $start + 1);
            $inner = substr($methodSource, $parenStart + 1, $parenEnd - $parenStart - 1);
            $args = $this->splitTopLevelArguments($inner);
            $errorCode = null;
            $messageExpr = null;
            $dataExpr = null;
            $httpStatus = null;

            if (isset($args[0]) && preg_match('/^\d+$/', $args[0]) === 1) {
                $errorCode = (int) $args[0];
            }
            if (isset($args[1]) && $args[1] !== '') {
                $messageExpr = $args[1];
            }
            if (isset($args[2]) && $args[2] !== '') {
                $dataExpr = $args[2];
            }
            if (count($args) >= 4) {
                $lastArg = trim((string) end($args));
                if (preg_match('/^\d{3}$/', $lastArg) === 1) {
                    $httpStatus = (int) $lastArg;
                }
            }

            $responses[] = [
                'raw' => $this->normalizeWhitespace($call),
                'error_code' => $errorCode,
                'message_expr' => $messageExpr,
                'data_expr' => $dataExpr,
                'data_literal' => $this->parseLiteralExpression($dataExpr),
                'http_status' => $httpStatus,
            ];

            $offset = $parenEnd + 1;
        }

        return $responses;
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractReturnResponses(string $methodSource): array
    {
        $responses = [];

        foreach ($this->extractCallReturns($methodSource, 'response()->json', 'json_helper') as $response) {
            $responses[] = $response;
        }
        foreach ($this->extractCallReturns($methodSource, 'new JsonResponse', 'json_response') as $response) {
            $responses[] = $response;
        }
        foreach ($this->extractCallReturns($methodSource, 'response()->apiResponse', 'api_response') as $response) {
            $responses[] = $response;
        }
        foreach ($this->extractArrayLiteralReturns($methodSource) as $response) {
            $responses[] = $response;
        }
        foreach ($this->extractResourceReturns($methodSource) as $response) {
            $responses[] = $response;
        }

        return $responses;
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractCallReturns(string $methodSource, string $needle, string $kind): array
    {
        $responses = [];
        $offset = 0;

        while (($start = strpos($methodSource, 'return ' . $needle, $offset)) !== false) {
            $parenStart = strpos($methodSource, '(', $start + strlen('return ' . $needle) - 1);
            if ($parenStart === false) {
                break;
            }

            $parenEnd = $this->scanBalanced($methodSource, $parenStart, '(', ')');
            if ($parenEnd === null) {
                break;
            }

            $inner = substr($methodSource, $parenStart + 1, $parenEnd - $parenStart - 1);
            $args = $this->splitTopLevelArguments($inner);
            $payloadExpr = $args[0] ?? null;
            $status = null;
            if (isset($args[1]) && preg_match('/^\d{3}$/', trim($args[1])) === 1) {
                $status = (int) trim($args[1]);
            }

            $responses[] = [
                'kind' => $kind,
                'raw' => $this->normalizeWhitespace(substr($methodSource, $start, $parenEnd - $start + 1)),
                'payload_expr' => $payloadExpr,
                'payload_literal' => $this->parseLiteralExpression($payloadExpr),
                'status' => $status,
            ];

            $offset = $parenEnd + 1;
        }

        return $responses;
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractArrayLiteralReturns(string $methodSource): array
    {
        $responses = [];
        $offset = 0;

        while (($start = strpos($methodSource, 'return [', $offset)) !== false) {
            $arrayStart = strpos($methodSource, '[', $start);
            if ($arrayStart === false) {
                break;
            }

            $arrayEnd = $this->scanBalanced($methodSource, $arrayStart, '[', ']');
            if ($arrayEnd === null) {
                break;
            }

            $literal = substr($methodSource, $arrayStart, $arrayEnd - $arrayStart + 1);
            $responses[] = [
                'kind' => 'array_literal',
                'raw' => $this->normalizeWhitespace(substr($methodSource, $start, $arrayEnd - $start + 1)),
                'payload_expr' => $literal,
                'payload_literal' => $this->parseLiteralExpression($literal),
                'status' => 200,
            ];

            $offset = $arrayEnd + 1;
        }

        return $responses;
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function extractResourceReturns(string $methodSource): array
    {
        $responses = [];

        if (preg_match_all('/return\s+([A-Za-z_][A-Za-z0-9_\\\\]*Resource)::(make|collection)\s*\(/', $methodSource, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[0] as $index => $match) {
                $responses[] = [
                    'kind' => $matches[2][$index][0] === 'collection' ? 'resource_collection' : 'resource',
                    'resource_class' => $matches[1][$index][0],
                    'raw' => $this->normalizeWhitespace($match[0]),
                    'status' => 200,
                ];
            }
        }

        return $responses;
    }

    /**
     * @return list<array{receiver:string,method:string}>
     */
    private function extractServiceCalls(string $methodSource): array
    {
        $seen = [];
        $calls = [];

        if (preg_match_all('/(\$[A-Za-z_]\w*(?:\s*->\s*[A-Za-z_]\w*)?)\s*->\s*([A-Za-z_]\w*)\s*\(/', $methodSource, $matches, PREG_SET_ORDER)) {
            foreach ($matches as $match) {
                $receiver = preg_replace('/\s+/', '', $match[1]);
                $method = $match[2];
                if ($receiver === null || stripos($receiver, 'service') === false) {
                    continue;
                }
                $key = $receiver . '|' . $method;
                if (isset($seen[$key])) {
                    continue;
                }
                $seen[$key] = true;
                $calls[] = ['receiver' => $receiver, 'method' => $method];
            }
        }

        if (preg_match_all('/([A-Za-z_][A-Za-z0-9_\\\\]*Service)\s*::\s*([A-Za-z_]\w*)\s*\(/', $methodSource, $matches, PREG_SET_ORDER)) {
            foreach ($matches as $match) {
                $receiver = $match[1];
                $method = $match[2];
                $key = $receiver . '|' . $method;
                if (isset($seen[$key])) {
                    continue;
                }
                $seen[$key] = true;
                $calls[] = ['receiver' => $receiver, 'method' => $method];
            }
        }

        return $calls;
    }

    /**
     * @return list<string>
     */
    private function extractExceptionRefs(string $methodSource): array
    {
        $refs = [];

        if (preg_match_all('/throw\s+new\s+([A-Za-z_][A-Za-z0-9_\\\\]*)/', $methodSource, $matches)) {
            foreach ($matches[1] as $exceptionClass) {
                $refs[$exceptionClass] = true;
            }
        }

        if (preg_match_all('/catch\s*\(([^)]*)\)/', $methodSource, $matches)) {
            foreach ($matches[1] as $inner) {
                $inner = str_replace('|', ' ', $inner);
                if (preg_match_all('/([A-Za-z_][A-Za-z0-9_\\\\]*)/', $inner, $tokens)) {
                    foreach ($tokens[1] as $token) {
                        if (
                            in_array($token, ['Throwable', 'Exception', 'BaseException'], true)
                            || str_ends_with($token, 'Exception')
                            || str_contains($token, '\\')
                        ) {
                            $refs[$token] = true;
                        }
                    }
                }
            }
        }

        return array_keys($refs);
    }

    /**
     * @return list<string>
     */
    private function splitTopLevelArguments(string $value): array
    {
        $parts = [];
        $current = '';
        $length = strlen($value);
        $round = 0;
        $square = 0;
        $curly = 0;
        $quote = null;
        $escape = false;

        for ($i = 0; $i < $length; $i++) {
            $char = $value[$i];

            if ($quote !== null) {
                $current .= $char;
                if ($escape) {
                    $escape = false;
                    continue;
                }
                if ($char === '\\') {
                    $escape = true;
                    continue;
                }
                if ($char === $quote) {
                    $quote = null;
                }
                continue;
            }

            if ($char === '"' || $char === "'") {
                $quote = $char;
                $current .= $char;
                continue;
            }

            if ($char === '(') {
                $round++;
                $current .= $char;
                continue;
            }

            if ($char === ')') {
                $round--;
                $current .= $char;
                continue;
            }

            if ($char === '[') {
                $square++;
                $current .= $char;
                continue;
            }

            if ($char === ']') {
                $square--;
                $current .= $char;
                continue;
            }

            if ($char === '{') {
                $curly++;
                $current .= $char;
                continue;
            }

            if ($char === '}') {
                $curly--;
                $current .= $char;
                continue;
            }

            if ($char === ',' && $round === 0 && $square === 0 && $curly === 0) {
                $parts[] = trim($current);
                $current = '';
                continue;
            }

            $current .= $char;
        }

        $parts[] = trim($current);
        return $parts;
    }

    private function parseLiteralExpression(?string $expression): mixed
    {
        if ($expression === null) {
            return null;
        }

        $expression = trim($expression);
        if ($expression === '' || str_starts_with($expression, '$')) {
            return null;
        }

        if ($expression === 'null') {
            return null;
        }

        if ($expression === 'true') {
            return true;
        }

        if ($expression === 'false') {
            return false;
        }

        if (preg_match('/^-?\d+$/', $expression) === 1) {
            return (int) $expression;
        }

        if (preg_match('/^-?\d+\.\d+$/', $expression) === 1) {
            return (float) $expression;
        }

        if (($expression[0] === "'" && str_ends_with($expression, "'")) || ($expression[0] === '"' && str_ends_with($expression, '"'))) {
            return stripcslashes(substr($expression, 1, -1));
        }

        if ($expression[0] === '[') {
            return $this->parseArrayLiteral($expression);
        }

        return null;
    }

    private function parseArrayLiteral(string $expression): ?array
    {
        $end = $this->scanBalanced($expression, 0, '[', ']');
        if ($end === null) {
            return null;
        }

        $inner = trim(substr($expression, 1, $end - 1));
        if ($inner === '') {
            return [];
        }

        $parts = $this->splitTopLevelArguments($inner);
        $result = [];
        $index = 0;

        foreach ($parts as $part) {
            if (str_contains($part, '=>')) {
                [$keyExpr, $valueExpr] = explode('=>', $part, 2);
                $key = $this->parseLiteralExpression(trim($keyExpr));
                if (!is_string($key) && !is_int($key)) {
                    return null;
                }

                $value = $this->parseLiteralExpression(trim($valueExpr));
                if (trim($valueExpr) !== 'null' && $value === null && !str_starts_with(trim($valueExpr), '[')) {
                    return null;
                }
                $result[$key] = $value;
                continue;
            }

            $value = $this->parseLiteralExpression(trim($part));
            if (trim($part) !== 'null' && $value === null && !str_starts_with(trim($part), '[')) {
                return null;
            }
            $result[$index] = $value;
            $index++;
        }

        return $result;
    }

    private function scanBalanced(string $source, int $start, string $openChar, string $closeChar): ?int
    {
        $length = strlen($source);
        $depth = 0;
        $quote = null;
        $escape = false;
        $lineComment = false;
        $blockComment = false;

        for ($i = $start; $i < $length; $i++) {
            $char = $source[$i];
            $next = $i + 1 < $length ? $source[$i + 1] : '';

            if ($lineComment) {
                if ($char === "\n") {
                    $lineComment = false;
                }
                continue;
            }

            if ($blockComment) {
                if ($char === '*' && $next === '/') {
                    $blockComment = false;
                    $i++;
                }
                continue;
            }

            if ($quote !== null) {
                if ($escape) {
                    $escape = false;
                    continue;
                }
                if ($char === '\\') {
                    $escape = true;
                    continue;
                }
                if ($char === $quote) {
                    $quote = null;
                }
                continue;
            }

            if ($char === '/' && $next === '/') {
                $lineComment = true;
                $i++;
                continue;
            }

            if ($char === '/' && $next === '*') {
                $blockComment = true;
                $i++;
                continue;
            }

            if ($char === '"' || $char === "'") {
                $quote = $char;
                continue;
            }

            if ($char === $openChar) {
                $depth++;
                continue;
            }

            if ($char === $closeChar) {
                $depth--;
                if ($depth === 0) {
                    return $i;
                }
            }
        }

        return null;
    }

    private function normalizeWhitespace(string $value): string
    {
        return trim((string) preg_replace('/\s+/', ' ', $value));
    }
}
