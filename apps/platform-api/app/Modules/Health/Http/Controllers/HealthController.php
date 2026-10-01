<?php

namespace App\Modules\Health\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

class HealthController extends Controller
{
    public function summary(): JsonResponse
    {
        $checks = $this->checks();
        $status = in_array('unavailable', $checks, true) ? 'degraded' : 'ok';

        return response()->json([
            'status' => $status,
            'checks' => $checks,
        ]);
    }

    public function live(): JsonResponse
    {
        return response()->json([
            'status' => 'ok',
            'checks' => [
                'app' => 'ok',
            ],
        ]);
    }

    public function ready(): JsonResponse
    {
        $checks = $this->checks();
        $ready = ! in_array('unavailable', $checks, true);

        if ($ready) {
            return response()->json([
                'status' => 'ok',
                'checks' => $checks,
            ]);
        }

        return response()->json([
            'error' => [
                'code' => 'service_overloaded',
                'message' => 'Service dependencies are not ready.',
                'details' => [
                    'checks' => $checks,
                ],
                'request_id' => request()->headers->get('X-Request-Id', ''),
            ],
        ], 503);
    }

    /**
     * @return array<string, string>
     */
    private function checks(): array
    {
        return [
            'app' => 'ok',
            'database' => $this->databaseReady() ? 'ok' : 'unavailable',
            'cache' => $this->cacheReady() ? 'ok' : 'unavailable',
        ];
    }

    private function databaseReady(): bool
    {
        try {
            DB::select('select 1');

            return true;
        } catch (Throwable) {
            return false;
        }
    }

    private function cacheReady(): bool
    {
        try {
            $key = 'health:ready';
            Cache::put($key, 'ok', 10);

            return Cache::get($key) === 'ok';
        } catch (Throwable) {
            return false;
        }
    }
}
