<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthEndpointsTest extends TestCase
{
    public function test_health_summary_matches_openapi_shape(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertOk()
            ->assertJsonStructure([
                'status',
                'checks',
            ])
            ->assertJsonPath('checks.app', 'ok');

        $this->assertContains($response->json('status'), ['ok', 'degraded', 'unavailable']);
    }

    public function test_liveness_endpoint_reports_process_is_live(): void
    {
        $this->getJson('/api/v1/health/live')
            ->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('checks.app', 'ok');
    }

    public function test_readiness_endpoint_reports_dependency_state(): void
    {
        $response = $this->getJson('/api/v1/health/ready');

        $this->assertContains($response->status(), [200, 503]);

        if ($response->status() === 200) {
            $response->assertJsonStructure(['status', 'checks']);
            return;
        }

        $response->assertJsonStructure([
            'error' => [
                'code',
                'message',
                'details',
                'request_id',
            ],
        ]);
    }
}
