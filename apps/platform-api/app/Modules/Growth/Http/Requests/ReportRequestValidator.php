<?php

namespace App\Modules\Growth\Http\Requests;

use App\Shared\Validation\RequestPayloadValidator;
use Illuminate\Http\Request;

class ReportRequestValidator
{
    private const EXPORT_FORMATS = ['csv', 'xlsx', 'pdf'];

    public function __construct(private readonly RequestPayloadValidator $payloads)
    {
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function reportQueryErrors(Request $request, string $scope): array
    {
        $query = $request->query();
        $rules = [
            'date_from' => ['sometimes', 'nullable', 'string'],
            'date_to' => ['sometimes', 'nullable', 'string'],
            'cursor' => ['sometimes', 'nullable', 'string', 'max:128'],
            'limit' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ];

        if ($scope === 'central') {
            $rules['tenant_id'] = ['sometimes', 'nullable', 'string', 'max:30'];
        }

        return $this->payloads->merge(
            $this->payloads->validate($query, $rules),
            $this->payloads->dateRange($query),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function exportPayloadErrors(array $payload, string $scope): array
    {
        $errors = $this->payloads->validate($payload, [
            'format' => ['required', 'string', 'in:'.implode(',', self::EXPORT_FORMATS)],
            'tenant_id' => [$scope === 'central' ? 'sometimes' : 'prohibited', 'nullable', 'string', 'max:30'],
            'date_from' => ['sometimes', 'nullable', 'string'],
            'date_to' => ['sometimes', 'nullable', 'string'],
            'filters' => ['sometimes', 'array'],
        ], [
            'format.in' => 'The format field must be one of csv, xlsx, or pdf.',
            'format.required' => 'The format field must be one of csv, xlsx, or pdf.',
            'tenant_id.prohibited' => 'The tenant_id field is not allowed for tenant report exports.',
        ]);

        return $this->payloads->merge($errors, $this->payloads->dateRange($payload));
    }
}
