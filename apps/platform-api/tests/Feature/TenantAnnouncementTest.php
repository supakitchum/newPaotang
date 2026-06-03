<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class TenantAnnouncementTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_tenant_admin_manages_announcements_and_public_reads_active_scheduled_news(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_ann', 'ten_ann', 'ann.example.test');
        $this->insertActivePartnerTenantWithDomain('par_other_ann', 'ten_other_ann', 'other-ann.example.test');
        $admin = $this->createTenantSession('ten_ann', 'par_ann', ['announcement.view', 'announcement.manage'], 'adm_ann', 'tenant-ann@example.test');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => 'ten_ann',
        ];

        $future = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/announcements', [
                'title' => 'Future Promotion',
                'summary' => 'Future summary',
                'body' => 'Future body',
                'status' => 'active',
                'modal_enabled' => true,
                'display_start_at' => now()->addDay()->toISOString(),
                'sort_order' => 1,
            ], $headers + ['Idempotency-Key' => 'ann-create-future'])
            ->assertCreated()
            ->assertJsonPath('slug', 'future-promotion')
            ->json();

        $this->getJson('http://ann.example.test/api/v1/public/news')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('content_source_status', 'empty');

        $updated = $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/announcements/'.$future['id'], [
                'display_start_at' => now()->subMinute()->toISOString(),
                'display_end_at' => now()->addDay()->toISOString(),
                'important' => false,
            ], $headers + ['Idempotency-Key' => 'ann-update-future-active'])
            ->assertOk()
            ->assertJsonPath('title', 'Future Promotion')
            ->json();

        $this->getJson('http://ann.example.test/api/v1/public/news')
            ->assertOk()
            ->assertJsonPath('data.0.id', $updated['id'])
            ->assertJsonPath('data.0.cover', null)
            ->assertJsonPath('content_source_status', 'configured');

        $important = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/announcements', [
                'title' => 'Important QR News',
                'slug' => 'important-qr-news',
                'summary' => 'Important summary',
                'body' => "Line one\nLine two",
                'status' => 'active',
                'modal_enabled' => true,
                'important' => true,
                'display_start_at' => now()->subHour()->toISOString(),
                'sort_order' => 99,
            ], $headers + ['Idempotency-Key' => 'ann-create-important'])
            ->assertCreated()
            ->assertJsonPath('important', true)
            ->json();

        Storage::fake('lottery_images');

        $withImage = $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/announcements/'.$important['id'].'/image', [
                'file' => UploadedFile::fake()->create('qr-guide.png', 32, 'image/png'),
            ], $headers)
            ->assertOk()
            ->assertJsonPath('id', $important['id'])
            ->json();

        $this->assertNotEmpty($withImage['image_full_url']);
        $this->assertNotEmpty($withImage['image_thumb_url']);
        $this->assertDatabaseCount('platform_assets', 2);
        $this->assertDatabaseHas('platform_assets', [
            'tenant_id' => 'ten_ann',
            'purpose' => 'tenant_announcement_image',
            'status' => 'committed',
        ]);

        $this->getJson('http://ann.example.test/api/v1/public/news/modal')
            ->assertOk()
            ->assertJsonPath('data.id', $important['id'])
            ->assertJsonPath('data.slug', 'important-qr-news')
            ->assertJsonPath('data.body', null);

        $this->getJson('http://ann.example.test/api/v1/public/news/important-qr-news')
            ->assertOk()
            ->assertJsonPath('id', $important['id'])
            ->assertJsonPath('body', "Line one\nLine two");

        $this->getJson('http://other-ann.example.test/api/v1/public/news/important-qr-news')
            ->assertNotFound()
            ->assertJsonPath('error.code', 'news_not_found');

        $this->withToken($admin['access_token'])
            ->deleteJson('/api/v1/admin/tenant/announcements/'.$important['id'], [
                'reason' => 'Campaign ended',
            ], $headers + ['Idempotency-Key' => 'ann-delete-important'])
            ->assertNoContent();

        $this->assertDatabaseHas('tenant_announcements', [
            'id' => $important['id'],
            'status' => 'archived',
        ]);

        $this->assertDatabaseHas('audit_logs', ['action' => 'announcement.created', 'target_id' => $important['id']]);
        $this->assertSame(2, DB::table('platform_assets')->where('tenant_id', 'ten_ann')->where('purpose', 'tenant_announcement_image')->count());
    }
}
