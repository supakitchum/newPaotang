<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerSocialQaDiagnosticsTest extends TestCase
{
    use RefreshDatabase;

    private const ROUTES = [
        'google' => 'social/google/link-phone',
        'apple' => 'social/apple/link-phone',
        'facebook' => 'social/facebook/link-phone',
        'line' => 'social/line/link-phone',
        'line_legacy' => 'line/link-phone',
    ];

    public function test_qa_invalid_otp_hides_inactive_suspended_and_identity_conflict(): void
    {
        $this->fixtures();
        $ownerIndex = 0;
        foreach (self::ROUTES as $key => $route) {
            $ownerId = 'qa-owner-'.$key;
            DB::table('customers')->insert($this->customer($ownerId, '08999999'.sprintf('%02d', ++$ownerIndex), 'active'));
            $provider = str_starts_with($key, 'line') ? 'line' : $key;
            $this->link($key, $provider);
            $identity = ['id' => 'qa-identity-'.$key, 'tenant_id' => 'qa-tenant', 'customer_id' => $ownerId, 'created_at' => now(), 'updated_at' => now()];
            if ($provider === 'line') {
                DB::table('customer_line_identities')->insert($identity + ['line_user_id' => 'qa-user-'.$key, 'friend_flag' => false]);
            } else {
                DB::table('customer_social_identities')->insert($identity + ['provider' => $provider, 'provider_user_id' => 'qa-user-'.$key]);
            }
            foreach (['inactive', 'suspended', 'active'] as $status) {
                DB::table('customers')->where('id', 'qa-target')->update(['status' => $status]);
                $this->postJson($this->url($route), $this->payload($key, 'qa-invalid-otp'))
                    ->assertStatus(422)->assertJsonPath('error.code', 'otp_invalid');
                $this->assertDatabaseHas('customer_line_link_tokens', ['token_hash' => hash('sha256', 'qa-link-'.$key), 'status' => 'pending', 'consumed_at' => null]);
            }
        }
        $this->assertDatabaseCount('customers', 6);
    }

    public function test_qa_inactive_rejection_preserves_tokens_for_retry_then_replay_is_rejected(): void
    {
        $this->fixtures();
        foreach (self::ROUTES as $key => $route) {
            DB::table('customers')->where('id', 'qa-target')->update(['status' => 'inactive']);
            $this->link($key, str_starts_with($key, 'line') ? 'line' : $key);
            $this->otp($key);
            $payload = $this->payload($key, 'qa-otp-'.$key);
            $this->postJson($this->url($route), $payload)
                ->assertUnauthorized()->assertJsonPath('error.code', 'authentication_required');
            $this->assertDatabaseHas('otp_verifications', ['verification_token_hash' => hash('sha256', 'qa-otp-'.$key), 'status' => 'verified', 'consumed_at' => null]);
            $this->assertDatabaseHas('customer_line_link_tokens', ['token_hash' => hash('sha256', 'qa-link-'.$key), 'status' => 'pending', 'consumed_at' => null]);
            DB::table('customers')->where('id', 'qa-target')->update(['status' => 'active']);
            $this->postJson($this->url($route), $payload)->assertOk()->assertJsonPath('user.id', 'qa-target');
            $this->assertDatabaseHas('otp_verifications', ['verification_token_hash' => hash('sha256', 'qa-otp-'.$key), 'status' => 'consumed']);
            $this->postJson($this->url($route), $payload)->assertUnauthorized();
        }
        $this->assertDatabaseCount('customers', 1);
    }

    public function test_qa_legacy_line_rejects_google_handoff_with_verified_otp(): void
    {
        $this->fixtures();
        $this->link('cross', 'google');
        $this->otp('cross');
        $this->postJson($this->url('line/link-phone'), $this->payload('cross', 'qa-otp-cross'))->assertUnauthorized();
        $this->assertDatabaseHas('otp_verifications', ['verification_token_hash' => hash('sha256', 'qa-otp-cross'), 'status' => 'verified', 'consumed_at' => null]);
        $this->assertDatabaseCount('customer_line_identities', 0);
    }

    private function fixtures(): void
    {
        $this->assertSame('newpaotang_test', config('database.connections.'.config('database.default').'.database'));
        $this->assertTrue(app()->environment('testing'));
        DB::table('partners')->insert(['id' => 'qa-partner', 'code' => 'qa-partner', 'name' => 'QA Fixture', 'type' => 'partner_store', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('partner_tenants')->insert(['id' => 'qa-tenant', 'partner_id' => 'qa-partner', 'code' => 'qa', 'name' => 'QA Fixture', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('partner_tenant_domains')->insert(['id' => 'qa-domain', 'partner_id' => 'qa-partner', 'tenant_id' => 'qa-tenant', 'host' => 'qa-social.test', 'type' => 'subdomain', 'status' => 'active', 'is_primary' => true, 'verified_at' => now(), 'ssl_ready_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('customers')->insert($this->customer('qa-target', '0812345678', 'inactive'));
    }

    private function customer(string $id, string $phone, string $status): array
    {
        return ['id' => $id, 'tenant_id' => 'qa-tenant', 'phone' => $phone, 'name' => 'QA Fixture', 'status' => $status, 'created_at' => now(), 'updated_at' => now()];
    }

    private function link(string $key, string $provider): void
    {
        DB::table('customer_line_link_tokens')->insert([
            'id' => 'qa-link-'.$key, 'tenant_id' => 'qa-tenant', 'token_hash' => hash('sha256', 'qa-link-'.$key),
            'line_user_id' => ($provider === 'line' ? '' : $provider.':').'qa-user-'.$key,
            'display_name' => 'QA Fixture', 'friend_flag' => false, 'status' => 'pending',
            'expires_at' => now()->addMinutes(15), 'consumed_at' => null,
            'metadata_json' => json_encode(['provider' => $provider, 'profile' => ['id' => 'qa-user-'.$key, 'display_name' => 'QA Fixture']], JSON_THROW_ON_ERROR),
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function otp(string $key): void
    {
        DB::table('otp_verifications')->insert([
            'id' => 'qa-otp-'.$key, 'tenant_id' => 'qa-tenant', 'provider_id' => null, 'provider' => 'test',
            'purpose' => 'register', 'phone' => '0812345678', 'phone_normalized' => '0812345678',
            'otp_hash' => 'qa-fixture-only', 'verification_token_hash' => hash('sha256', 'qa-otp-'.$key),
            'status' => 'verified', 'attempts' => 1, 'max_attempts' => 5, 'expires_at' => now()->addMinutes(10),
            'verified_at' => now(), 'consumed_at' => null, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function payload(string $key, string $otp): array
    {
        return ['link_token' => 'qa-link-'.$key, 'phone' => '0812345678', 'otp_verification_token' => $otp, 'existing_only' => true];
    }

    private function url(string $route): string
    {
        return 'http://qa-social.test/api/v1/customer/auth/'.$route;
    }
}
