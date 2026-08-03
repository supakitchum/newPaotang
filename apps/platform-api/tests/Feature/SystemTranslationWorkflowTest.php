<?php

namespace Tests\Feature;

use App\Models\SystemTranslationKey;
use App\Models\SystemLanguage;
use App\Models\SystemTranslationValue;
use App\Modules\Translations\Services\SystemTranslationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SystemTranslationWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
    }

    public function test_translator_request_can_be_previewed_and_approved_to_runtime_bundle(): void
    {
        DB::table('admin_users')->insert([
            'id' => 'adm_translation_test',
            'email' => 'translator@example.test',
            'password_hash' => 'not-used',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $key = SystemTranslationKey::query()
            ->where('surface', 'customer')
            ->where('category', 'profile')
            ->where('translation_key', 'profile.memberCode')
            ->firstOrFail();

        $draft = $service->saveDraft($key->id, [
            'locale' => 'en-US',
            'value' => 'Member code: {code}',
        ], 'adm_translation_test');
        $this->assertArrayNotHasKey('error', $draft);

        $created = $service->createDeployRequest([
            'locale' => 'en-US',
            'surface' => 'customer',
            'category' => 'profile',
        ], 'adm_translation_test');
        $request = $created['resource']['request'];
        $this->assertSame('draft', $request['status']);
        $this->assertCount(1, $request['items']);

        $submitted = $service->submitDeployRequest($request['id'], 'adm_translation_test');
        $this->assertSame('submitted', $submitted['resource']['request']['status']);

        $preview = $service->previewSession($request['id'], 'adm_translation_test');
        $token = $preview['resource']['preview']['token'];
        $previewBundle = $service->runtimeBundle('en-US', 'customer', $token);
        $this->assertSame('Member code: {code}', $previewBundle['messages']['profile.memberCode']);

        $approved = $service->approveDeployRequest($request['id'], 'adm_translation_test');
        $this->assertSame('deployed', $approved['resource']['request']['status']);

        $runtimeBundle = $service->runtimeBundle('en-US', 'customer');
        $this->assertSame('Member code: {code}', $runtimeBundle['messages']['profile.memberCode']);
    }

    public function test_runtime_bundle_only_advertises_languages_published_for_the_requested_surface(): void
    {
        $service = app(SystemTranslationService::class);
        $service->syncCatalog();
        $service->upsertLanguage([
            'locale' => 'ja-JP',
            'name' => 'Japanese',
            'native_name' => 'Japanese',
            'status' => 'active',
            'sort_order' => 30,
        ]);

        $customerLocales = array_column(
            $service->runtimeBundle('th-TH', 'customer')['available_locales'],
            'locale',
        );
        $this->assertNotContains('ja-JP', $customerLocales);

        $language = SystemLanguage::query()->where('locale', 'ja-JP')->firstOrFail();
        $key = SystemTranslationKey::query()
            ->where('surface', 'customer')
            ->where('status', 'active')
            ->firstOrFail();
        SystemTranslationValue::query()->create([
            'id' => 'tvl_customer_ja_test',
            'language_id' => $language->id,
            'translation_key_id' => $key->id,
            'value' => 'Customer translation',
            'published_at' => now(),
        ]);

        $customerLocales = array_column(
            $service->runtimeBundle('th-TH', 'customer')['available_locales'],
            'locale',
        );
        $this->assertContains('ja-JP', $customerLocales);
    }

    public function test_placeholder_validation_blocks_submit(): void
    {
        DB::table('admin_users')->insert([
            'id' => 'adm_translation_test',
            'email' => 'translator@example.test',
            'password_hash' => 'not-used',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $key = SystemTranslationKey::query()
            ->where('translation_key', 'profile.memberCode')
            ->firstOrFail();

        $service->saveDraft($key->id, [
            'locale' => 'en-US',
            'value' => 'Member code',
        ], 'adm_translation_test');

        $created = $service->createDeployRequest([
            'locale' => 'en-US',
            'surface' => 'customer',
            'category' => 'profile',
        ], 'adm_translation_test');

        $submitted = $service->submitDeployRequest($created['resource']['request']['id'], 'adm_translation_test');
        $this->assertSame('validation_failed', $submitted['error']);
        $this->assertSame('Member ID: {code}', $service->runtimeBundle('en-US', 'customer')['messages']['profile.memberCode']);
    }

    public function test_back_office_phrase_translations_are_published_in_runtime_phrase_map(): void
    {
        DB::table('admin_users')->insert([
            'id' => 'adm_translation_test',
            'email' => 'translator@example.test',
            'password_hash' => 'not-used',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $key = SystemTranslationKey::query()
            ->where('surface', 'back-office')
            ->where('category', 'phrases')
            ->where('default_text', 'Back to games')
            ->firstOrFail();

        $service->saveDraft($key->id, [
            'locale' => 'th-TH',
            'value' => 'กลับไปหน้าเกม',
        ], 'adm_translation_test');

        $created = $service->createDeployRequest([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'phrases',
        ], 'adm_translation_test');

        $requestId = $created['resource']['request']['id'];
        $this->assertSame('submitted', $service->submitDeployRequest($requestId, 'adm_translation_test')['resource']['request']['status']);
        $this->assertSame('deployed', $service->approveDeployRequest($requestId, 'adm_translation_test')['resource']['request']['status']);

        $bundle = $service->runtimeBundle('th-TH', 'back-office');
        $this->assertSame('กลับไปหน้าเกม', $bundle['messages'][$key->translation_key]);
        $this->assertSame('กลับไปหน้าเกม', $bundle['phrases']['Back to games']);
    }

    public function test_translation_keys_are_paginated(): void
    {
        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $firstPage = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'phrases',
            'page' => 1,
            'per_page' => 10,
        ]);

        $secondPage = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'phrases',
            'page' => 2,
            'per_page' => 10,
        ]);

        $this->assertSame(10, $firstPage['pagination']['per_page']);
        $this->assertSame(1, $firstPage['pagination']['page']);
        $this->assertSame(2, $secondPage['pagination']['page']);
        $this->assertCount(10, $firstPage['data']);
        $this->assertCount(10, $secondPage['data']);
        $this->assertGreaterThan(10, $firstPage['pagination']['total']);
        $this->assertNotSame($firstPage['data'][0]['id'], $secondPage['data'][0]['id']);
    }

    public function test_static_locale_values_are_visible_in_translation_center_without_overwriting_approved_values(): void
    {
        DB::table('admin_users')->insert([
            'id' => 'adm_translation_test',
            'email' => 'translator@example.test',
            'password_hash' => 'not-used',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $menus = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'menus',
            'q' => 'menus.items.central.dashboard',
        ]);

        $dashboard = collect($menus['data'])->firstWhere('key', 'menus.items.central.dashboard');
        $this->assertSame('แดชบอร์ด', $dashboard['published_value'] ?? null);

        $localeOnlyMenus = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'menus',
            'q' => 'menus.sidebar.restoring',
        ]);

        $restoring = collect($localeOnlyMenus['data'])->firstWhere('key', 'menus.sidebar.restoring');
        $this->assertSame('กำลังกู้คืนเมนู...', $restoring['published_value'] ?? null);

        $key = SystemTranslationKey::query()
            ->where('surface', 'back-office')
            ->where('translation_key', 'menus.items.central.dashboard')
            ->firstOrFail();

        DB::table('system_translation_values')
            ->where('translation_key_id', $key->id)
            ->update([
                'value' => 'แดชบอร์ดที่อนุมัติแล้ว',
                'published_by_admin_id' => 'adm_translation_test',
                'updated_at' => now(),
            ]);

        $service->syncCatalog();
        $menusAfterSync = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'menus',
            'q' => 'menus.items.central.dashboard',
        ]);

        $dashboardAfterSync = collect($menusAfterSync['data'])->firstWhere('key', 'menus.items.central.dashboard');
        $this->assertSame('แดชบอร์ดที่อนุมัติแล้ว', $dashboardAfterSync['published_value'] ?? null);
    }

    public function test_translation_center_reseeds_missing_published_values(): void
    {
        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        DB::table('system_translation_values')->delete();
        Cache::forget('system_translation_catalog_seeded');

        $menus = $service->keys([
            'locale' => 'th-TH',
            'surface' => 'back-office',
            'category' => 'menus',
            'q' => 'menus.items.central.translations',
        ]);

        $translations = collect($menus['data'])->firstWhere('key', 'menus.items.central.translations');
        $this->assertSame('ศูนย์แปลภาษา', $translations['published_value'] ?? null);
    }

    public function test_back_office_phrase_defaults_are_seeded_for_modals_and_forms(): void
    {
        $service = app(SystemTranslationService::class);
        $service->syncCatalog();

        $bundle = $service->runtimeBundle('th-TH', 'back-office');

        $this->assertSame('สร้างผู้ดูแลระบบ', $bundle['phrases']['Create admin user'] ?? null);
        $this->assertSame('เลือกเกม', $bundle['phrases']['Select game'] ?? null);
        $this->assertSame('กำลังโหลดตัวเลือก...', $bundle['phrases']['Loading options...'] ?? null);

        $this->assertDatabaseMissing('system_translation_keys', [
            'surface' => 'back-office',
            'category' => 'phrases',
            'default_text' => 'Welcome to Nuxt!',
            'status' => 'active',
        ]);
    }
}
