<?php

namespace LaravelApiDocs\InferCandidates;

final class FormRequestParser
{
    /**
     * @return list<array<string,mixed>>
     */
    public function parseRules(string $requestFile): array
    {
        if ($requestFile === '' || !is_file($requestFile)) {
            return [];
        }

        $content = file_get_contents($requestFile);
        if ($content === false) {
            return [];
        }

        $rulesBlock = $this->extractRulesBlock($content);
        if ($rulesBlock === null || $rulesBlock === '') {
            return [];
        }

        $fields = [];
        foreach ($this->extractRuleEntries($rulesBlock) as $field => $rules) {
            $fields[] = $this->parseRuleTokens($field, $rules);
        }

        return $fields;
    }

    public function countRules(string $requestFile): int
    {
        return count($this->parseRules($requestFile));
    }

    /**
     * @param list<string> $rules
     * @return array<string,mixed>
     */
    private function parseRuleTokens(string $field, array $rules): array
    {
        $required = in_array('required', $rules, true);
        $nullable = in_array('nullable', $rules, true);
        $type = 'string';
        $format = null;
        $unresolvedRules = [];
        $passwordRules = [];

        if (in_array('integer', $rules, true)) {
            $type = 'integer';
        } elseif (in_array('numeric', $rules, true)) {
            $type = 'number';
        } elseif (in_array('boolean', $rules, true)) {
            $type = 'boolean';
        } elseif (in_array('array', $rules, true)) {
            $type = 'array';
        }

        if (in_array('email', $rules, true)) {
            $format = 'email';
        } elseif (in_array('url', $rules, true)) {
            $format = 'uri';
        } elseif (in_array('uuid', $rules, true)) {
            $format = 'uuid';
        } elseif (in_array('date', $rules, true)) {
            $format = 'date';
        }

        $result = [
            'field' => $field,
            'segments' => $this->segmentsForField($field),
            'type' => $type,
            'required' => $required,
            'nullable' => $nullable,
            'unresolvedRules' => [],
        ];

        if ($format !== null) {
            $result['format'] = $format;
        }

        foreach ($rules as $rule) {
            if ($rule === '' || in_array($rule, ['required', 'nullable', 'string', 'integer', 'numeric', 'boolean', 'array', 'email', 'url', 'uuid', 'date', 'bail'], true)) {
                continue;
            }

            if (preg_match('/^date_format:(.+)$/', $rule, $matches) === 1) {
                $result['dateFormat'] = trim($matches[1]);
                continue;
            }

            if (preg_match('/^min:(\d+)$/', $rule, $matches) === 1) {
                $this->applyRangeConstraint($result, 'min', (int) $matches[1]);
                continue;
            }

            if (preg_match('/^max:(\d+)$/', $rule, $matches) === 1) {
                $this->applyRangeConstraint($result, 'max', (int) $matches[1]);
                continue;
            }

            if (preg_match('/^between:(\d+),(\d+)$/', $rule, $matches) === 1) {
                $this->applyRangeConstraint($result, 'min', (int) $matches[1]);
                $this->applyRangeConstraint($result, 'max', (int) $matches[2]);
                continue;
            }

            if (preg_match('/^size:(\d+)$/', $rule, $matches) === 1) {
                $this->applyRangeConstraint($result, 'min', (int) $matches[1]);
                $this->applyRangeConstraint($result, 'max', (int) $matches[1]);
                continue;
            }

            if (preg_match('/^digits:(\d+)$/', $rule, $matches) === 1) {
                $digits = (int) $matches[1];
                $result['type'] = 'string';
                $result['minLength'] = $digits;
                $result['maxLength'] = $digits;
                $result['pattern'] = '^\d{' . $digits . '}$';
                continue;
            }

            if (preg_match('/^in:(.+)$/', $rule, $matches) === 1) {
                $result['enum'] = array_values(array_filter(array_map('trim', explode(',', $matches[1])), static fn (string $value): bool => $value !== ''));
                continue;
            }

            if (preg_match('/^regex:(.+)$/', $rule, $matches) === 1) {
                $pattern = trim($matches[1]);
                if (strlen($pattern) >= 2 && $pattern[0] === '/' && str_ends_with($pattern, '/')) {
                    $pattern = substr($pattern, 1, -1);
                }
                $result['pattern'] = $pattern;
                continue;
            }

            if (preg_match('/^same:(.+)$/', $rule, $matches) === 1) {
                $target = trim($matches[1]);
                if ($target !== '') {
                    $result['sameAs'] = $target;
                }
                continue;
            }

            if ($rule === 'confirmed') {
                $target = $this->inferConfirmedTarget($field);
                if ($target !== null) {
                    $result['sameAs'] = $target;
                    $result['confirmed'] = true;
                } else {
                    $unresolvedRules[] = $rule;
                }
                continue;
            }

            if (preg_match('/^Password::min\((\d+)\)(.+)?$/', $rule, $matches) === 1) {
                $result['type'] = 'string';
                $result['minLength'] = max((int) ($result['minLength'] ?? 0), (int) $matches[1]);
                $methods = (string) ($matches[2] ?? '');
                $passwordRules = array_merge($passwordRules, $this->parsePasswordBuilderMethods($methods));
                continue;
            }

            if (
                str_starts_with($rule, 'exists:')
                || str_starts_with($rule, 'unique:')
                || str_starts_with($rule, 'required_if:')
                || str_starts_with($rule, 'required_unless:')
                || str_starts_with($rule, 'required_with:')
                || str_starts_with($rule, 'required_without:')
                || str_starts_with($rule, 'sometimes')
                || str_starts_with($rule, 'after:')
                || str_starts_with($rule, 'after_or_equal:')
                || str_starts_with($rule, 'before:')
                || str_starts_with($rule, 'before_or_equal:')
                || str_starts_with($rule, 'Rule::')
            ) {
                $unresolvedRules[] = $rule;
                continue;
            }

            if (str_contains($rule, 'new') || str_contains($rule, 'Closure') || str_contains($rule, 'function(')) {
                $unresolvedRules[] = $rule;
            }
        }

        if ($passwordRules !== []) {
            $result['passwordRules'] = $passwordRules;
            if (($passwordRules['letters'] ?? false) === true) {
                $result['containsLetters'] = true;
            }
            if (($passwordRules['numbers'] ?? false) === true) {
                $result['containsNumbers'] = true;
            }
            if (($passwordRules['symbols'] ?? false) === true) {
                $result['containsSymbols'] = true;
            }
            if (($passwordRules['mixedCase'] ?? false) === true) {
                $result['containsMixedCase'] = true;
            }
        }

        $result['unresolvedRules'] = array_values(array_unique($unresolvedRules));

        return $result;
    }

    /**
     * @return array<string,list<string>>
     */
    private function extractRuleEntries(string $rulesBlock): array
    {
        $entries = [];
        if ($rulesBlock === '') {
            return $entries;
        }

        $arrayStart = strpos($rulesBlock, '[');
        if ($arrayStart === false) {
            return $entries;
        }

        $arrayEnd = $this->scanBalanced($rulesBlock, $arrayStart, '[', ']');
        if ($arrayEnd === null) {
            return $entries;
        }

        $inner = substr($rulesBlock, $arrayStart + 1, $arrayEnd - $arrayStart - 1);
        foreach ($this->splitTopLevelEntries($inner) as $entry) {
            if (preg_match("/^[[:space:]]*'([^']+)'[[:space:]]*=>[[:space:]]*(.+)$/s", $entry, $matches) !== 1) {
                continue;
            }

            $field = $matches[1];
            $value = trim(rtrim($matches[2], ','));
            $entries[$field] = $this->parseRuleValue($value);
        }

        return $entries;
    }

    /**
     * @return list<string>
     */
    private function parseRuleValue(string $value): array
    {
        $value = trim($value);
        if ($value === '') {
            return [];
        }

        if ($value[0] === "'" && str_ends_with($value, "'")) {
            return array_values(array_filter(array_map('trim', explode('|', trim($value, "'"))), static fn (string $rule): bool => $rule !== ''));
        }

        if ($value[0] !== '[') {
            return [$this->normalizeRuleToken($value)];
        }

        $end = $this->scanBalanced($value, 0, '[', ']');
        if ($end === null) {
            return [];
        }

        $inner = substr($value, 1, $end - 1);
        $tokens = [];
        foreach ($this->splitTopLevelEntries($inner) as $token) {
            $normalized = $this->normalizeRuleToken($token);
            if ($normalized === '') {
                continue;
            }
            $tokens[] = $normalized;
        }

        return $tokens;
    }

    private function normalizeRuleToken(string $token): string
    {
        $token = trim(trim($token), ", \t\n\r\0\x0B");
        if ($token === '') {
            return '';
        }

        if (($token[0] === "'" && str_ends_with($token, "'")) || ($token[0] === '"' && str_ends_with($token, '"'))) {
            return trim($token, "'\"");
        }

        return preg_replace('/\s+/', '', $token) ?? $token;
    }

    /**
     * @return list<string>
     */
    private function splitTopLevelEntries(string $value): array
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

        if (trim($current) !== '') {
            $parts[] = trim($current);
        }

        return $parts;
    }

    /**
     * @param array<string,mixed> $field
     */
    private function applyRangeConstraint(array &$field, string $kind, int $value): void
    {
        $type = (string) ($field['type'] ?? 'string');
        if ($type === 'array') {
            $field[$kind === 'min' ? 'minItems' : 'maxItems'] = $value;
            $field['items'] = $field['items'] ?? ['type' => 'string'];
            return;
        }

        if ($type === 'integer' || $type === 'number') {
            $field[$kind === 'min' ? 'minimum' : 'maximum'] = $value;
            return;
        }

        $field[$kind === 'min' ? 'minLength' : 'maxLength'] = $value;
    }

    private function extractRulesBlock(string $content): ?string
    {
        if (preg_match('/public function rules\s*\([^)]*\)\s*:\s*array\s*\{/', $content, $matches, PREG_OFFSET_CAPTURE) !== 1
            && preg_match('/public function rules\s*\([^)]*\)\s*\{/', $content, $matches, PREG_OFFSET_CAPTURE) !== 1) {
            return null;
        }

        $methodStart = $matches[0][1];
        $returnOffset = strpos($content, 'return [', $methodStart);
        if ($returnOffset === false) {
            return null;
        }

        $arrayStart = strpos($content, '[', $returnOffset);
        if ($arrayStart === false) {
            return null;
        }

        $arrayEnd = $this->scanBalanced($content, $arrayStart, '[', ']');
        if ($arrayEnd === null) {
            return null;
        }

        return substr($content, $arrayStart, $arrayEnd - $arrayStart + 1);
    }

    private function scanBalanced(string $source, int $start, string $openChar, string $closeChar): ?int
    {
        $length = strlen($source);
        $depth = 0;
        $quote = null;
        $escape = false;

        for ($i = $start; $i < $length; $i++) {
            $char = $source[$i];
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

    /**
     * @return list<string>
     */
    private function segmentsForField(string $field): array
    {
        return array_values(array_filter(explode('.', $field), static fn (string $segment): bool => $segment !== ''));
    }

    private function inferConfirmedTarget(string $field): ?string
    {
        $segments = $this->segmentsForField($field);
        if ($segments === []) {
            return null;
        }

        $last = array_pop($segments);
        if ($last === null || !str_ends_with($last, '_confirmation')) {
            return null;
        }

        $base = substr($last, 0, -13);
        if ($base === '') {
            return null;
        }

        $segments[] = $base;
        return implode('.', $segments);
    }

    /**
     * @return array<string,bool|int>
     */
    private function parsePasswordBuilderMethods(string $methods): array
    {
        $rules = [];
        if ($methods === '') {
            return $rules;
        }

        if (preg_match('/mixedCase\(\)/', $methods) === 1) {
            $rules['mixedCase'] = true;
        }
        if (preg_match('/letters\(\)/', $methods) === 1) {
            $rules['letters'] = true;
        }
        if (preg_match('/numbers\(\)/', $methods) === 1) {
            $rules['numbers'] = true;
        }
        if (preg_match('/symbols\(\)/', $methods) === 1) {
            $rules['symbols'] = true;
        }

        return $rules;
    }
}
