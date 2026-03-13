<?php

namespace LaravelApiDocs\OpenApiGenerator;

final class ApiResponseProjectAdapter implements ProjectResponseAdapter
{
    public function __construct(
        private readonly ResponseAnalyzer $analyzer,
    ) {
    }

    public function resolveSuccess(array $controllerData): ?array
    {
        $resolved = null;

        foreach (($controllerData['api_responses'] ?? []) as $response) {
            if (!is_array($response)) {
                continue;
            }

            $status = (int) ($response['http_status'] ?? 0);
            if ($status < 200 || $status >= 400) {
                continue;
            }

            $message = $this->messageFromExpression((string) ($response['message_expr'] ?? '')) ?: '成功';
            $code = is_int($response['error_code'] ?? null) ? $response['error_code'] : 0;
            $dataExpr = trim((string) ($response['data_expr'] ?? ''));
            $dataLiteral = $response['data_literal'] ?? null;

            $dataSchema = ['type' => 'object', 'nullable' => true];
            $dataExample = new \stdClass();

            if ($dataExpr === 'null') {
                $dataExample = null;
            } elseif ($dataExpr !== '' && $dataLiteral !== null) {
                $dataSchema = $this->analyzer->schemaFromLiteral($dataLiteral);
                $dataExample = $dataLiteral;
            }

            $resolved = [
                'schema' => [
                    'type' => 'object',
                    'properties' => [
                        'code' => ['type' => 'integer'],
                        'message' => ['type' => 'string'],
                        'data' => $dataSchema,
                    ],
                    'required' => ['code', 'message', 'data'],
                ],
                'example' => [
                    'code' => $code,
                    'message' => $message,
                    'data' => $dataExample,
                ],
            ];
        }

        return $resolved;
    }

    public function resolveError(array $apiResponse): ?array
    {
        $status = (int) ($apiResponse['http_status'] ?? 0);
        if ($status < 400 || $status > 599) {
            return null;
        }

        $message = $this->messageFromExpression((string) ($apiResponse['message_expr'] ?? '')) ?: '錯誤';
        $code = is_int($apiResponse['error_code'] ?? null) ? $apiResponse['error_code'] : $status;
        $dataExpr = trim((string) ($apiResponse['data_expr'] ?? ''));
        $dataExample = null;
        if ($dataExpr !== '' && $dataExpr !== 'null') {
            $dataExample = $apiResponse['data_literal'] ?? null;
        }

        return [
            'description' => $message,
            'example' => [
                'code' => $code,
                'message' => $message,
                'data' => $dataExample,
            ],
        ];
    }

    private function messageFromExpression(string $expression): ?string
    {
        $expression = trim($expression);
        if ($expression === '') {
            return null;
        }

        if (preg_match('/^[\'"](.+)[\'"]$/', $expression, $matches) === 1) {
            return $matches[1];
        }

        if (preg_match('/__(\s*)\(\s*[\'"]([^\'"]+)[\'"]/', $expression, $matches) === 1) {
            return $matches[2];
        }

        if (preg_match('/trans(\s*)\(\s*[\'"]([^\'"]+)[\'"]/', $expression, $matches) === 1) {
            return $matches[2];
        }

        return null;
    }
}
