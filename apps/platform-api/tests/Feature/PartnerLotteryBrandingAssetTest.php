<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class PartnerLotteryBrandingAssetTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_CentralPartnerLotteryBrandingAssets_are_central_only_and_lock_after_generation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_branding', 'ten_branding');
        $central = $this->createCentralSession(['asset.manage'], 'adm_branding_central', 'branding-central@example.test');
        $tenant = $this->createTenantSession('ten_branding', 'par_branding', ['asset.manage'], 'adm_branding_tenant', 'branding-tenant@example.test');

        $assetIds = [
            'logo_qr' => $this->insertCentralImageAsset('ast_logo_qr', 'logo_qr'),
            'right_sidebar' => $this->insertCentralImageAsset('ast_right_sidebar', 'right_sidebar'),
            'logo_bottom' => $this->insertCentralImageAsset('ast_logo_bottom', 'logo_bottom'),
        ];

        $this->withToken($tenant['access_token'])
            ->putJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', [
                'version' => 'v1',
                'assets' => [
                    'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
                    'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
                    'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
                ],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_branding',
                'Idempotency-Key' => 'tenant-branding-update',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('partner_id', 'par_branding')
            ->assertJsonPath('status', 'missing')
            ->assertJsonPath('locked', false)
            ->assertJsonPath('generated_image_count', 0);

        $saved = $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', [
                'version' => 'v1',
                'assets' => [
                    'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
                    'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
                    'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-branding-update',
            ])
            ->assertOk()
            ->assertJsonPath('partner_id', 'par_branding')
            ->assertJsonPath('status', 'ready')
            ->assertJsonPath('locked', false)
            ->assertJsonPath('assets.logo_qr.asset_id', $assetIds['logo_qr'])
            ->assertJsonPath('assets.logo_qr.content_type', 'image/webp')
            ->assertJsonPath('assets.logo_qr.file_name', 'logo_qr.webp')
            ->assertJsonPath('assets.right_sidebar.file_name', 'rightsidebar.webp')
            ->assertJsonPath('assets.logo_bottom.file_name', 'logo_bottom.webp')
            ->json();

        $this->assertSame($saved, $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', [
                'version' => 'v1',
                'assets' => [
                    'logo_qr' => ['asset_id' => $assetIds['logo_qr']],
                    'right_sidebar' => ['asset_id' => $assetIds['right_sidebar']],
                    'logo_bottom' => ['asset_id' => $assetIds['logo_bottom']],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-branding-update',
            ])
            ->assertOk()
            ->json());

        $this->insertGame('gam_branding', 'open');
        $this->insertStockItems('gam_branding', 1, 420001);
        $stockItemId = (string) DB::table('stock_items')->where('game_id', 'gam_branding')->value('id');

        DB::table('local_stock_items')->insert([
            'id' => 'lsi_branding_generated',
            'tenant_id' => 'ten_branding',
            'partner_id' => 'par_branding',
            'store_id' => 'ten_branding',
            'game_id' => 'gam_branding',
            'stock_item_id' => $stockItemId,
            'allocation_id' => null,
            'full_number' => '420001',
            'front3' => '420',
            'back3' => '001',
            'back2' => '01',
            'image_url' => 'https://cdn.example.test/lotteries/gam_branding/partners/par_branding/lsi_branding_generated.webp',
            'image_thumb_url' => 'https://cdn.example.test/lotteries/gam_branding/partners/par_branding/thumbs/lsi_branding_generated.webp',
            'image_storage_path' => 'lotteries/gam_branding/partners/par_branding/lsi_branding_generated.webp',
            'image_thumb_storage_path' => 'lotteries/gam_branding/partners/par_branding/thumbs/lsi_branding_generated.webp',
            'image_generation_status' => 'generated',
            'image_generation_error' => null,
            'image_generated_at' => now(),
            'status' => 'available',
            'synced_at' => now(),
            'reserved_at' => null,
            'sold_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('locked', true)
            ->assertJsonPath('status', 'locked')
            ->assertJsonPath('generated_image_count', 1);

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/partners/par_branding/lottery-branding-assets', [
                'version' => 'v1',
                'logo_qr_asset_id' => $assetIds['logo_qr'],
                'right_sidebar_asset_id' => $assetIds['right_sidebar'],
                'logo_bottom_asset_id' => $assetIds['logo_bottom'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-branding-update-after-lock',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');
    }

    private function insertCentralImageAsset(string $assetId, string $slot): string
    {
        $fileName = match ($slot) {
            'right_sidebar' => 'rightsidebar.webp',
            'logo_bottom' => 'logo_bottom.webp',
            default => 'logo_qr.webp',
        };
        $storageKey = 'partners/par_branding/lottery-branding/v1/'.$fileName;

        DB::table('platform_assets')->insert([
            'id' => $assetId,
            'scope_type' => 'central',
            'tenant_id' => null,
            'created_by_admin_id' => null,
            'purpose' => 'partner_lottery_branding',
            'file_name' => $fileName,
            'content_type' => 'image/webp',
            'size_bytes' => 1024,
            'checksum_sha256' => hash('sha256', $assetId),
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => 'https://local-assets.newpaotang.test/'.$storageKey,
            'metadata_json' => json_encode(['fixture' => true, 'partner_id' => 'par_branding', 'branding_slot' => $slot, 'version' => 'v1'], JSON_THROW_ON_ERROR),
            'expires_at' => null,
            'committed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $assetId;
    }
}
