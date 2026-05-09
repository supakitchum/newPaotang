<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class M10K6LoadTestExecutionTest extends TestCase
{
    use RefreshDatabase;

    public function test_K6_fixture_command_writes_env_artifacts_and_prepares_runnable_api_paths(): void
    {
        $dir = storage_path('framework/testing/k6-'.Str::lower(Str::random(8)));
        $jsonPath = $dir.'/k6-baseline-env.json';
        $envPath = $dir.'/k6-baseline.env';

        $this->artisan('load-tests:k6:prepare', [
            '--output-json' => $jsonPath,
            '--output-env' => $envPath,
            '--base-url' => 'http://host.docker.internal:8000',
            '--tenant-host' => 'k6-alpha.newpaotang.test',
            '--stock-count' => 8,
        ])->assertExitCode(0);

        $this->assertFileExists($jsonPath);
        $this->assertFileExists($envPath);

        $artifact = json_decode((string) file_get_contents($jsonPath), true);
        $this->assertIsArray($artifact);
        $env = $artifact['env'];

        foreach ([
            'BASE_URL',
            'TENANT_HOST',
            'GAME_ID',
            'SEARCH_NUMBER',
            'LOCAL_STOCK_ITEM_ID',
            'RESERVATION_ID',
            'CUSTOMER_TOKEN',
            'ADMIN_TOKEN',
            'PARTNER_TOKEN',
            'PARTNER_ID',
            'TENANT_ID',
            'PARTNER_SYNC_PATH',
            'REWARD_RESULT_ID',
            'CDN_BASE_URL',
            'IMAGE_PATH',
        ] as $key) {
            $this->assertArrayHasKey($key, $env);
        }

        $envFile = (string) file_get_contents($envPath);
        $this->assertStringContainsString('CUSTOMER_TOKEN=', $envFile);
        $this->assertStringNotContainsString('secret_hash', $envFile);
        $this->assertStringNotContainsString('refresh_token', $envFile);

        $this->assertSame(0, DB::table('partner_api_clients')
            ->where('secret_hash', $env['PARTNER_TOKEN'])
            ->count());

        $this->getJson('http://'.$env['TENANT_HOST'].'/api/v1/public/stock/search?game_id='.$env['GAME_ID'].'&number='.$env['SEARCH_NUMBER'])
            ->assertOk()
            ->assertJsonStructure(['data', 'meta']);

        $this->withToken($env['CUSTOMER_TOKEN'])
            ->postJson('http://'.$env['TENANT_HOST'].'/api/v1/customer/checkout', [
                'reservation_id' => $env['RESERVATION_ID'],
                'payment_method' => 'wallet',
            ], [
                'Idempotency-Key' => 'k6-test-checkout',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'paid');

        $this->withToken($env['ADMIN_TOKEN'])
            ->getJson('/api/v1/admin/central/rewards/'.$env['REWARD_RESULT_ID'].'/check-batches', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.status', 'completed');

        $event = [
            'event_id' => 'evt_k6_test_'.Str::lower(Str::random(8)),
            'event_type' => 'stock.sync_completed.v1',
            'event_version' => 1,
            'occurred_at' => now()->toISOString(),
            'producer' => 'partner_store',
            'tenant_id' => $env['TENANT_ID'],
            'partner_id' => $env['PARTNER_ID'],
            'game_id' => $env['GAME_ID'],
            'idempotency_key' => 'idem-k6-test',
            'correlation_id' => 'corr-k6-test',
            'payload' => ['cursor' => 'test-cursor', 'item_count' => 1],
        ];

        $headers = [
            'X-Partner-Id' => $env['PARTNER_ID'],
            'X-Tenant-Id' => $env['TENANT_ID'],
            'Idempotency-Key' => 'k6-partner-test',
        ];

        $this->withToken($env['PARTNER_TOKEN'])
            ->postJson('/api/v1/partner-sync/events', ['events' => [$event]], $headers)
            ->assertAccepted()
            ->assertJsonPath('accepted_count', 1)
            ->assertJsonPath('duplicate_count', 0);

        $this->withToken($env['PARTNER_TOKEN'])
            ->postJson('/api/v1/partner-sync/events', ['events' => [$event]], $headers)
            ->assertAccepted()
            ->assertJsonPath('accepted_count', 0)
            ->assertJsonPath('duplicate_count', 1);

        $badEvent = $event;
        $badEvent['event_id'] = 'evt_k6_bad_'.Str::lower(Str::random(8));
        $badEvent['tenant_id'] = 'ten_wrong';

        $this->withToken($env['PARTNER_TOKEN'])
            ->postJson('/api/v1/partner-sync/events', ['events' => [$badEvent]], $headers)
            ->assertUnprocessable();
    }
}
