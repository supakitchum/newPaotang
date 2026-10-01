<?php

namespace App\Shared\Http;

use Illuminate\Http\Request;

class RequestHeaderValidator
{
    /**
     * @return array<string, array<int, string>>
     */
    public function idempotencyKeyErrors(Request $request): array
    {
        $idempotencyKey = $request->header('Idempotency-Key');

        if ($idempotencyKey === null || strlen($idempotencyKey) < 8 || strlen($idempotencyKey) > 128) {
            return [
                'Idempotency-Key' => ['The Idempotency-Key header must be between 8 and 128 characters.'],
            ];
        }

        return [];
    }
}
