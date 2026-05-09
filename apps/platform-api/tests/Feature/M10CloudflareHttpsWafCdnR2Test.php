<?php

namespace Tests\Feature;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class M10CloudflareHttpsWafCdnR2Test extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_Cloudflare_readiness_command_redacts_config_and_requires_ticket_image_evidence(): void
    {
        $this->seed(DatabaseSeeder::class);
        config($this->configuredCloudflareReadinessConfig());

        $exitCode = Artisan::call('platform:cloudflare:readiness', ['--format' => 'json']);
        $output = Artisan::output();
        $report = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertSame('blocked_external', $report['status']);
        $this->assertFalse($report['production_approved']);
        $this->assertFalse($report['boundary']['production_approved']);
        $this->assertFalse($report['boundary']['external_cloudflare_calls_attempted']);
        $this->assertFalse($report['boundary']['external_r2_calls_attempted']);
        $this->assertSame(3, $report['domains']['total']);
        $this->assertSame(0, $report['domains']['unsafe_active']);
        $this->assertSame('artifacts_ready_local', $report['cache']['status']);
        $this->assertGreaterThanOrEqual(7, $report['cache']['waf_rate_limit_rules']['rule_count']);
        $this->assertGreaterThanOrEqual(8, $report['cache']['cache_bypass_rules']['rule_count']);
        $this->assertSame('missing_ticket_image_evidence', $report['cdn_r2_ticket_images']['status']);
        $this->assertContains('ticket_image_cdn_image_path_missing', $report['cdn_r2_ticket_images']['blockers']);
        $this->assertContains('ticket_image_cdn_image_path_missing', $report['blockers']);
        $this->assertFalse($report['cdn_r2_ticket_images']['k6_prerequisites']['base_url_fallback_allowed']);
        $this->assertFalse($report['cdn_r2_ticket_images']['k6_prerequisites']['image_path_evidence_present']);
        $this->assertTrue($report['cloudflare']['configured']['account_id']);
        $this->assertTrue($report['cloudflare']['configured']['zone_id']);
        $this->assertTrue($report['cloudflare']['configured']['api_token']);
        $this->assertTrue($report['cloudflare']['configured']['api_base_url']);
        $this->assertSame('[CONFIGURED]', $report['cloudflare']['redacted_config']['account_id']);
        $this->assertSame('[CONFIGURED]', $report['cloudflare']['redacted_config']['zone_id']);
        $this->assertSame('[REDACTED]', $report['cloudflare']['redacted_config']['api_token']);
        $this->assertSame('[CONFIGURED]', $report['cloudflare']['redacted_config']['api_base_url']);
        $this->assertSame('[CONFIGURED]', $report['cdn_r2_ticket_images']['redacted_config']['cdn_base_url']);
        $this->assertSame('[CONFIGURED]', $report['cdn_r2_ticket_images']['redacted_config']['r2_endpoint']);
        $this->assertSame('[CONFIGURED]', $report['cdn_r2_ticket_images']['redacted_config']['r2_bucket']);
        $this->assertSame('[REDACTED]', $report['cdn_r2_ticket_images']['redacted_config']['r2_access_key_id']);
        $this->assertSame('[REDACTED]', $report['cdn_r2_ticket_images']['redacted_config']['r2_secret_access_key']);
        $this->assertNull($report['cdn_r2_ticket_images']['redacted_config']['ticket_image_object_path']);

        foreach ($this->rawFakeReadinessValues() as $rawValue) {
            $this->assertStringNotContainsString($rawValue, $output);
        }

        $this->assertStringContainsString('[CONFIGURED]', $output);
        $this->assertStringContainsString('[REDACTED]', $output);
    }

    public function test_Explicit_ticket_image_path_evidence_removes_image_path_blocker_without_production_approval(): void
    {
        $this->seed(DatabaseSeeder::class);
        config($this->configuredCloudflareReadinessConfig('/tickets/qa-redaction-safe.png'));

        $exitCode = Artisan::call('platform:cloudflare:readiness', ['--format' => 'json']);
        $output = Artisan::output();
        $report = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertSame('ready_local', $report['status']);
        $this->assertSame('configured_dry_run', $report['cdn_r2_ticket_images']['status']);
        $this->assertFalse($report['production_approved']);
        $this->assertFalse($report['boundary']['production_approved']);
        $this->assertFalse($report['boundary']['external_cloudflare_calls_attempted']);
        $this->assertFalse($report['boundary']['external_r2_calls_attempted']);
        $this->assertTrue($report['cdn_r2_ticket_images']['configured']['ticket_image_object_path']);
        $this->assertTrue($report['cdn_r2_ticket_images']['k6_prerequisites']['image_path_evidence_present']);
        $this->assertNotContains('ticket_image_cdn_image_path_missing', $report['cdn_r2_ticket_images']['blockers']);
        $this->assertNotContains('ticket_image_cdn_image_path_missing', $report['blockers']);
        $this->assertSame('[CONFIGURED]', $report['cdn_r2_ticket_images']['redacted_config']['ticket_image_object_path']);

        foreach (array_merge($this->rawFakeReadinessValues(), ['/tickets/qa-redaction-safe.png']) as $rawValue) {
            $this->assertStringNotContainsString($rawValue, $output);
        }
    }

    public function test_Base_url_does_not_satisfy_ticket_image_cdn_evidence(): void
    {
        $this->seed(DatabaseSeeder::class);
        putenv('BASE_URL=https://api.fake-redaction.test');
        $_ENV['BASE_URL'] = 'https://api.fake-redaction.test';
        $_SERVER['BASE_URL'] = 'https://api.fake-redaction.test';

        try {
            config($this->configuredCloudflareReadinessConfig());

            $exitCode = Artisan::call('platform:cloudflare:readiness', ['--format' => 'json']);
            $output = Artisan::output();
            $report = json_decode($output, true);

            $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
            $this->assertIsArray($report);
            $this->assertSame('blocked_external', $report['status']);
            $this->assertSame('missing_ticket_image_evidence', $report['cdn_r2_ticket_images']['status']);
            $this->assertContains('ticket_image_cdn_image_path_missing', $report['cdn_r2_ticket_images']['blockers']);
            $this->assertFalse($report['cdn_r2_ticket_images']['configured']['ticket_image_object_path']);
            $this->assertFalse($report['cdn_r2_ticket_images']['k6_prerequisites']['base_url_fallback_allowed']);
            $this->assertStringNotContainsString('https://api.fake-redaction.test', $output);
        } finally {
            putenv('BASE_URL');
            unset($_ENV['BASE_URL'], $_SERVER['BASE_URL']);
        }
    }

    public function test_Custom_domain_activation_guard_requires_dns_ssl_proxy_and_https_evidence(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession([
            'partner.create',
            'partner.provision',
        ], 'adm_cf_domain', 'cf-domain@example.test');

        $partner = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => 'cf_partner',
                'name' => 'Cloudflare Partner',
                'type' => 'white_label',
                'status' => 'draft',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cf-partner-create',
            ])
            ->assertCreated()
            ->json();

        $payload = [
            'tenant_code' => 'cf_tenant',
            'tenant_name' => 'Cloudflare Tenant',
            'domain_host' => 'tickets.example.test',
            'domain_type' => 'custom_domain',
            'owner_email' => 'owner@cf-domain.test',
            'owner_password' => 'secret-password',
            'site_name' => 'Cloudflare Tickets',
        ];

        $provisioned = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', $payload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cf-partner-provision',
            ])
            ->assertAccepted()
            ->assertJsonPath('domains.0.status', 'pending_verification')
            ->json();

        $tenantId = $provisioned['tenants'][0]['id'];

        $this->assertDatabaseHas('partner_tenant_domains', [
            'tenant_id' => $tenantId,
            'host' => 'tickets.example.test',
            'type' => 'custom_domain',
            'status' => 'pending_verification',
            'verified_at' => null,
            'ssl_ready_at' => null,
            'dns_verified_at' => null,
            'cloudflare_proxy_verified_at' => null,
            'https_enforced_at' => null,
        ]);

        $this->getJson('http://tickets.example.test/api/v1/public/site-config')
            ->assertConflict()
            ->assertJsonPath('error.code', 'domain_not_active');

        DB::table('partner_tenant_domains')->where('tenant_id', $tenantId)->update([
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'dns_verified_at' => now(),
            'cloudflare_proxy_verified_at' => now(),
            'https_enforced_at' => now(),
            'cloudflare_readiness_checked_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', $payload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cf-partner-provision-after-readiness',
            ])
            ->assertAccepted()
            ->assertJsonPath('domains.0.status', 'active');

        $this->assertDatabaseHas('partner_tenant_domains', [
            'tenant_id' => $tenantId,
            'host' => 'tickets.example.test',
            'status' => 'active',
        ]);
    }

    public function test_Env_ops_artifacts_ticket_image_guard_and_routes_keep_release_boundary(): void
    {
        $env = file_get_contents(base_path('.env.example'));
        $this->assertIsString($env);

        foreach ([
            'CLOUDFLARE_ACCOUNT_ID=',
            'CLOUDFLARE_ZONE_ID=',
            'CLOUDFLARE_API_TOKEN=',
            'CLOUDFLARE_DRY_RUN=',
            'CLOUDFLARE_PROXY_REQUIRED=',
            'CLOUDFLARE_HTTPS_REQUIRED=',
            'R2_ENDPOINT=',
            'R2_BUCKET=',
            'R2_ACCESS_KEY_ID=',
            'R2_SECRET_ACCESS_KEY=',
            'CDN_BASE_URL=',
            'TICKET_IMAGE_CDN_REQUIRED=',
            'TICKET_IMAGE_CDN_IMAGE_PATH=',
        ] as $key) {
            $this->assertStringContainsString($key, $env);
        }

        foreach (['TENANT_LOGO', 'TENANT_THEME', 'TENANT_PAYMENT', 'TENANT_DOMAIN', 'TENANT_FEATURE', 'LOGO_URL', 'THEME_PRIMARY_COLOR', 'PAYMENT_CHANNEL'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $env);
        }

        $waf = $this->jsonWorkspaceFile('ops/m10/cloudflare-waf-rate-limit-rules.json');
        $cache = $this->jsonWorkspaceFile('ops/m10/cloudflare-cache-bypass-rules.json');

        foreach ([
            'public_tenant_pages',
            'public_stock_search_results',
            'customer_auth_booking_checkout',
            'admin_back_office',
            'partner_sync',
            'payment_topup_webhooks',
            'support_impersonation_sensitive',
        ] as $category) {
            $this->assertContains($category, array_column($waf['rules'], 'category'));
        }

        foreach ([
            'api_dynamic',
            'webhook_payment_topup_callbacks',
            'admin_back_office',
            'auth_session_protected',
            'tenant_maintenance_dynamic_pages',
            'ticket_images_static',
        ] as $category) {
            $this->assertContains($category, array_column($cache['rules'], 'category'));
        }

        $ticketScript = $this->workspaceFile('load-tests/k6/ticket-image-cdn-spike.js');
        $runner = $this->workspaceFile('scripts/k6-run-baseline.sh');

        $this->assertStringContainsString("requireEnv(['CDN_BASE_URL']", $ticketScript);
        $this->assertStringContainsString('IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH is required', $ticketScript);
        $this->assertStringContainsString('__ENV.TICKET_IMAGE_CDN_IMAGE_PATH', $ticketScript);
        $this->assertStringContainsString('BASE_URL is intentionally ignored', $ticketScript);
        $this->assertStringNotContainsString('__ENV.CDN_BASE_URL || __ENV.BASE_URL', $ticketScript);
        $this->assertStringContainsString('IMAGE_PATH=${OVERRIDE_IMAGE_PATH:-${IMAGE_PATH:-${TICKET_IMAGE_CDN_IMAGE_PATH:-}}}', $runner);
        $this->assertStringContainsString('[ "${IMAGE_PATH:-}" != "" ] && [ "${CDN_BASE_URL:-}" != "" ]', $runner);
        $this->assertStringNotContainsString('|| [ "${BASE_URL:-}" != "" ]', $runner);

        $routes = collect(Route::getRoutes())->map(fn ($route): string => $route->uri())->all();

        $this->assertFalse(collect($routes)->contains(fn (string $uri): bool => str_contains($uri, 'cloudflare')));
    }

    /**
     * @return array<string, mixed>
     */
    private function jsonWorkspaceFile(string $path): array
    {
        $decoded = json_decode($this->workspaceFile($path), true);

        $this->assertIsArray($decoded);

        return $decoded;
    }

    private function workspaceFile(string $path): string
    {
        $workspaceRoots = array_filter([
            env('WORKSPACE_ROOT'),
            '/workspace',
            dirname(base_path(), 2),
        ]);

        foreach ($workspaceRoots as $root) {
            $file = rtrim((string) $root, '/').'/'.$path;

            if (is_file($file)) {
                $contents = file_get_contents($file);

                $this->assertIsString($contents);

                return $contents;
            }
        }

        $this->fail($path.' must exist in the mounted workspace.');
    }

    /**
     * @return array<string, mixed>
     */
    private function configuredCloudflareReadinessConfig(?string $imagePath = null): array
    {
        return [
            'platform.cloudflare.account_id' => 'acct-super-secret',
            'platform.cloudflare.zone_id' => 'zone_placeholder',
            'platform.cloudflare.api_token' => 'cf-super-secret-token',
            'platform.cloudflare.api_base_url' => 'https://api.cloudflare.fake-redaction.test/client/v4',
            'platform.cloudflare.dry_run' => true,
            'platform.ticket_images.cdn_base_url' => 'https://cdn.example.test',
            'platform.ticket_images.r2_endpoint' => 'https://r2.example.test',
            'platform.ticket_images.r2_bucket' => 'newpaotang-ticket-images',
            'platform.ticket_images.r2_access_key_id' => 'r2_key_id_placeholder',
            'platform.ticket_images.r2_secret_access_key' => 'r2-super-secret-key',
            'platform.ticket_images.image_path' => $imagePath,
        ];
    }

    /**
     * @return array<int, string>
     */
    private function rawFakeReadinessValues(): array
    {
        return [
            'acct-super-secret',
            'zone_placeholder',
            'cf-super-secret-token',
            'https://api.cloudflare.fake-redaction.test/client/v4',
            'https://cdn.example.test',
            'https://r2.example.test',
            'newpaotang-ticket-images',
            'r2_key_id_placeholder',
            'r2-super-secret-key',
        ];
    }
}
