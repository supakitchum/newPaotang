<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class M10AdminSecurityLinePolicyClosureTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_M10AdminSecurityLinePolicy_routes_are_registered_for_all_remaining_openapi_gaps(): void
    {
        $routes = collect(Route::getRoutes())->map(fn ($route): string => implode('|', $route->methods()).' '.$route->uri())->all();

        foreach ([
            'POST api/v1/auth/admin/password/forgot',
            'POST api/v1/auth/admin/password/reset',
            'POST api/v1/auth/admin/password/change',
            'GET|HEAD api/v1/auth/admin/2fa',
            'DELETE api/v1/auth/admin/2fa',
            'POST api/v1/auth/admin/2fa/setup',
            'POST api/v1/auth/admin/2fa/enable',
            'POST api/v1/auth/admin/2fa/recovery-codes',
            'POST api/v1/auth/admin/2fa/verify',
            'POST api/v1/customer/auth/line/login',
            'GET|HEAD api/v1/customer/auth/line/callback',
        ] as $expected) {
            $this->assertContains($expected, $routes);
        }
    }

    public function test_M10AdminSecurityLinePolicy_password_reset_uses_hashes_expiry_single_use_audit_redaction_and_session_revocation(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['dashboard.view'], 'adm_security_reset', 'security-reset@example.test');

        $this->postJson('/api/v1/auth/admin/password/forgot', [
            'email' => 'security-reset@example.test',
        ], [
            'Idempotency-Key' => 'forgot-security-reset',
            'X-Request-Id' => 'req-forgot-security-reset',
        ])->assertStatus(202)
            ->assertContent('');

        $this->assertDatabaseHas('admin_password_reset_tokens', [
            'admin_user_id' => 'adm_security_reset',
            'status' => 'pending',
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('action', 'admin.password_reset_requested')
            ->where('actor_id', 'adm_security_reset')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);

        $this->assertSame('[REDACTED]', $auditPayload['reset_token']);

        $knownToken = 'npa_prt_known_reset_token_for_m10_security';
        DB::table('admin_password_reset_tokens')->insert([
            'id' => 'prt_known_security_reset',
            'admin_user_id' => 'adm_security_reset',
            'email_hash' => hash('sha256', 'security-reset@example.test'),
            'token_hash' => hash('sha256', $knownToken),
            'status' => 'pending',
            'expires_at' => now()->addMinutes(30),
            'consumed_at' => null,
            'requested_ip' => null,
            'requested_user_agent' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $knownToken,
            'password' => 'new-secret-password',
            'password_confirmation' => 'new-secret-password',
        ], [
            'Idempotency-Key' => 'reset-security-password',
            'X-Request-Id' => 'req-reset-security-password',
        ])->assertNoContent();

        $passwordHash = (string) DB::table('admin_users')->where('id', 'adm_security_reset')->value('password_hash');
        $this->assertTrue(Hash::check('new-secret-password', $passwordHash));
        $this->assertDatabaseHas('admin_password_reset_tokens', [
            'id' => 'prt_known_security_reset',
            'status' => 'consumed',
        ]);
        $this->assertNotNull(DB::table('admin_auth_sessions')->where('access_token_hash', hash('sha256', $login['access_token']))->value('revoked_at'));

        $resetAudit = json_decode((string) DB::table('audit_logs')
            ->where('action', 'admin.password_reset')
            ->where('actor_id', 'adm_security_reset')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);

        $this->assertSame('[REDACTED]', $resetAudit['token']);
        $this->assertSame('[REDACTED]', $resetAudit['password']);
        $this->assertSame('[REDACTED]', $resetAudit['password_confirmation']);
        $this->assertSame('[REDACTED]', $resetAudit['token_hash']);

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $knownToken,
            'password' => 'new-secret-password',
            'password_confirmation' => 'new-secret-password',
        ], [
            'Idempotency-Key' => 'reset-security-password',
        ])->assertNoContent();

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $knownToken,
            'password' => 'another-secret-password',
            'password_confirmation' => 'another-secret-password',
        ], [
            'Idempotency-Key' => 'reset-security-password-new-key',
        ])->assertUnauthorized();
    }

    public function test_M10AdminSecurityLinePolicy_support_impersonation_blocks_sensitive_admin_password_actions(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_support_security', 'ten_support_security', 'support-security.m10.test');
        $admin = $this->createTenantSession('ten_support_security', 'par_support_security', ['dashboard.view'], 'adm_support_security', 'support-security@example.test');
        $support = $this->createSupportImpersonationSession('ten_support_security', 'adm_support_security');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/auth/admin/password/change', [
                'current_password' => 'secret-password',
                'new_password' => 'blocked-password',
                'new_password_confirmation' => 'blocked-password',
            ], [
                'Idempotency-Key' => 'support-block-change-password',
                'X-Support-Impersonation-Session-Id' => $support['session_id'],
                'X-Support-Impersonation-Token' => $support['token'],
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->assertDatabaseHas('support_impersonation_blocked_actions', [
            'tenant_id' => 'ten_support_security',
            'support_impersonation_session_id' => $support['session_id'],
            'action' => 'change_password',
            'status' => 'blocked',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_support_security',
            'action' => 'support_impersonation.action_blocked',
            'target_type' => 'support_impersonation_blocked_action',
        ]);
    }

    public function test_M10AdminSecurityLinePolicy_two_factor_uses_real_totp_hashed_recovery_codes_challenge_replay_protection_and_redacted_idempotency(): void
    {
        $this->seedDefaultRbac();
        $admin = $this->createCentralSession(['dashboard.view'], 'adm_security_2fa', 'security-2fa@example.test');

        $setup = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/setup', [], [
                'Idempotency-Key' => 'setup-security-2fa',
            ])
            ->assertOk()
            ->assertJsonPath('two_factor_status', 'pending')
            ->assertJsonPath('recovery_codes_display_once', true)
            ->json();

        $this->assertNotEmpty($setup['secret']);
        $this->assertCount(8, $setup['recovery_codes']);
        $encryptedSecret = (string) DB::table('admin_two_factor_settings')->where('admin_user_id', 'adm_security_2fa')->value('secret_encrypted');
        $this->assertStringNotContainsString($setup['secret'], $encryptedSecret);
        $this->assertSame(0, DB::table('admin_two_factor_recovery_codes')->where('code_hash', $setup['recovery_codes'][0])->count());

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/setup', [], [
                'Idempotency-Key' => 'setup-security-2fa',
            ])
            ->assertOk()
            ->assertJsonPath('secret', '[REDACTED_DISPLAY_ONCE]')
            ->assertJsonPath('recovery_codes', [])
            ->assertJsonPath('recovery_codes_display_once', false);

        $totp = $this->totpCode($setup['secret']);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/enable', [
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'enable-security-2fa',
            ])
            ->assertOk()
            ->assertJsonPath('two_factor_enabled', true)
            ->assertJsonPath('two_factor_status', 'active');

        $challenge = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'security-2fa@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('requires_2fa', true)
            ->assertJsonPath('access_token', '')
            ->json();

        $verified = $this->postJson('/api/v1/auth/admin/2fa/verify', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $this->totpCode($setup['secret']),
        ])
            ->assertOk()
            ->assertJsonPath('requires_2fa', false)
            ->json();

        $this->assertNotSame('', $verified['access_token']);

        $this->postJson('/api/v1/auth/admin/2fa/verify', [
            'challenge_token' => $challenge['challenge_token'],
            'code' => $this->totpCode($setup['secret']),
        ])->assertUnauthorized();

        $rotated = $this->withToken($verified['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/recovery-codes', [
                'current_password' => 'secret-password',
                'code' => $this->totpCode($setup['secret']),
            ], [
                'Idempotency-Key' => 'rotate-security-2fa',
            ])
            ->assertOk()
            ->assertJsonPath('recovery_codes_display_once', true)
            ->json();

        $this->assertCount(8, $rotated['recovery_codes']);

        $this->withToken($verified['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/recovery-codes', [
                'current_password' => 'secret-password',
                'code' => $this->totpCode($setup['secret']),
            ], [
                'Idempotency-Key' => 'rotate-security-2fa',
            ])
            ->assertOk()
            ->assertJsonPath('recovery_codes', [])
            ->assertJsonPath('recovery_codes_display_once', false);

        $recoveryAudit = json_decode((string) DB::table('audit_logs')
            ->where('action', 'admin.2fa.recovery_codes_rotated')
            ->where('actor_id', 'adm_security_2fa')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $recoveryAudit['current_password']);
        $this->assertSame('[REDACTED]', $recoveryAudit['recovery_codes']);

        $this->withToken($verified['access_token'])
            ->deleteJson('/api/v1/auth/admin/2fa', [
                'current_password' => 'secret-password',
                'code' => $this->totpCode($setup['secret']),
            ], [
                'Idempotency-Key' => 'disable-security-2fa',
            ])
            ->assertNoContent();

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_security_2fa',
            'two_factor_enabled' => false,
        ]);
    }

    public function test_M10AdminSecurityLinePolicy_sensitive_idempotency_conflicts_use_fingerprints_and_do_not_mutate_twice(): void
    {
        $this->seedDefaultRbac();

        $this->createCentralSession(['dashboard.view'], 'adm_idem_reset', 'idem-reset@example.test');
        $resetTokenA = 'npa_prt_idem_reset_token_a';
        $resetTokenB = 'npa_prt_idem_reset_token_b';

        foreach ([['prt_idem_reset_a', $resetTokenA], ['prt_idem_reset_b', $resetTokenB]] as [$id, $token]) {
            DB::table('admin_password_reset_tokens')->insert([
                'id' => $id,
                'admin_user_id' => 'adm_idem_reset',
                'email_hash' => hash('sha256', 'idem-reset@example.test'),
                'token_hash' => hash('sha256', $token),
                'status' => 'pending',
                'expires_at' => now()->addMinutes(30),
                'consumed_at' => null,
                'requested_ip' => null,
                'requested_user_agent' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $resetTokenA,
            'password' => 'idem-reset-password-a',
            'password_confirmation' => 'idem-reset-password-a',
        ], [
            'Idempotency-Key' => 'idem-reset-fingerprint',
        ])->assertNoContent();

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $resetTokenA,
            'password' => 'idem-reset-password-a',
            'password_confirmation' => 'idem-reset-password-a',
        ], [
            'Idempotency-Key' => 'idem-reset-fingerprint',
        ])->assertNoContent();

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $resetTokenB,
            'password' => 'idem-reset-password-a',
            'password_confirmation' => 'idem-reset-password-a',
        ], [
            'Idempotency-Key' => 'idem-reset-fingerprint',
        ])->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $this->postJson('/api/v1/auth/admin/password/reset', [
            'token' => $resetTokenA,
            'password' => 'idem-reset-password-b',
            'password_confirmation' => 'idem-reset-password-b',
        ], [
            'Idempotency-Key' => 'idem-reset-fingerprint',
        ])->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $resetHash = (string) DB::table('admin_users')->where('id', 'adm_idem_reset')->value('password_hash');
        $this->assertTrue(Hash::check('idem-reset-password-a', $resetHash));
        $this->assertDatabaseHas('admin_password_reset_tokens', ['id' => 'prt_idem_reset_b', 'status' => 'pending']);

        $change = $this->createCentralSession(['dashboard.view'], 'adm_idem_change', 'idem-change@example.test');
        $this->withToken($change['access_token'])
            ->postJson('/api/v1/auth/admin/password/change', [
                'current_password' => 'secret-password',
                'new_password' => 'idem-change-password-a',
                'new_password_confirmation' => 'idem-change-password-a',
            ], [
                'Idempotency-Key' => 'idem-change-fingerprint',
            ])
            ->assertNoContent();

        $changeReplay = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'idem-change@example.test',
            'password' => 'idem-change-password-a',
            'scope' => 'central',
        ])->assertOk()->json();

        $this->withToken($changeReplay['access_token'])
            ->postJson('/api/v1/auth/admin/password/change', [
                'current_password' => 'secret-password',
                'new_password' => 'idem-change-password-a',
                'new_password_confirmation' => 'idem-change-password-a',
            ], [
                'Idempotency-Key' => 'idem-change-fingerprint',
            ])
            ->assertNoContent();

        foreach ([
            ['current_password' => 'changed-current-password', 'new_password' => 'idem-change-password-a', 'new_password_confirmation' => 'idem-change-password-a'],
            ['current_password' => 'secret-password', 'new_password' => 'idem-change-password-b', 'new_password_confirmation' => 'idem-change-password-b'],
        ] as $payload) {
            $this->withToken($changeReplay['access_token'])
                ->postJson('/api/v1/auth/admin/password/change', $payload, [
                    'Idempotency-Key' => 'idem-change-fingerprint',
                ])
                ->assertStatus(409)
                ->assertJsonPath('error.code', 'idempotency_conflict');
        }

        $changeHash = (string) DB::table('admin_users')->where('id', 'adm_idem_change')->value('password_hash');
        $this->assertTrue(Hash::check('idem-change-password-a', $changeHash));
        $this->assertSame(1, DB::table('audit_logs')->where('action', 'admin.password_changed')->where('actor_id', 'adm_idem_change')->count());

        $twoFactor = $this->createCentralSession(['dashboard.view'], 'adm_idem_2fa', 'idem-2fa@example.test');
        $setup = $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/setup', [], [
                'Idempotency-Key' => 'idem-2fa-setup',
            ])
            ->assertOk()
            ->json();

        $totp = $this->totpCode($setup['secret']);
        $changedTotp = $this->differentTotpCode($totp);

        $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/enable', [
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-enable',
            ])
            ->assertOk();

        $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/enable', [
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-enable',
            ])
            ->assertOk();

        $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/enable', [
                'code' => $changedTotp,
            ], [
                'Idempotency-Key' => 'idem-2fa-enable',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $this->assertSame(1, DB::table('audit_logs')->where('action', 'admin.2fa.enabled')->where('actor_id', 'adm_idem_2fa')->count());

        $rotated = $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/recovery-codes', [
                'current_password' => 'secret-password',
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-recovery',
            ])
            ->assertOk()
            ->json();

        $codeHashesAfterRotation = DB::table('admin_two_factor_recovery_codes')
            ->where('admin_user_id', 'adm_idem_2fa')
            ->orderBy('code_hash')
            ->pluck('code_hash')
            ->all();

        $this->withToken($twoFactor['access_token'])
            ->postJson('/api/v1/auth/admin/2fa/recovery-codes', [
                'current_password' => 'secret-password',
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-recovery',
            ])
            ->assertOk()
            ->assertJsonPath('recovery_codes', [])
            ->assertJsonPath('recovery_codes_display_once', false);

        foreach ([
            ['current_password' => 'changed-current-password', 'code' => $totp],
            ['current_password' => 'secret-password', 'code' => $changedTotp],
        ] as $payload) {
            $this->withToken($twoFactor['access_token'])
                ->postJson('/api/v1/auth/admin/2fa/recovery-codes', $payload, [
                    'Idempotency-Key' => 'idem-2fa-recovery',
                ])
                ->assertStatus(409)
                ->assertJsonPath('error.code', 'idempotency_conflict');
        }

        $this->assertSame($codeHashesAfterRotation, DB::table('admin_two_factor_recovery_codes')
            ->where('admin_user_id', 'adm_idem_2fa')
            ->orderBy('code_hash')
            ->pluck('code_hash')
            ->all());
        $this->assertSame(1, DB::table('audit_logs')->where('action', 'admin.2fa.recovery_codes_rotated')->where('actor_id', 'adm_idem_2fa')->count());

        $this->withToken($twoFactor['access_token'])
            ->deleteJson('/api/v1/auth/admin/2fa', [
                'current_password' => 'secret-password',
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-disable',
            ])
            ->assertNoContent();

        $this->withToken($twoFactor['access_token'])
            ->deleteJson('/api/v1/auth/admin/2fa', [
                'current_password' => 'secret-password',
                'code' => $totp,
            ], [
                'Idempotency-Key' => 'idem-2fa-disable',
            ])
            ->assertNoContent();

        foreach ([
            ['current_password' => 'changed-current-password', 'code' => $totp],
            ['current_password' => 'secret-password', 'code' => $changedTotp],
        ] as $payload) {
            $this->withToken($twoFactor['access_token'])
                ->deleteJson('/api/v1/auth/admin/2fa', $payload, [
                    'Idempotency-Key' => 'idem-2fa-disable',
                ])
                ->assertStatus(409)
                ->assertJsonPath('error.code', 'idempotency_conflict');
        }

        $this->assertDatabaseHas('admin_users', ['id' => 'adm_idem_2fa', 'two_factor_enabled' => false]);
        $this->assertSame(0, DB::table('admin_two_factor_recovery_codes')->where('admin_user_id', 'adm_idem_2fa')->count());
        $this->assertSame(1, DB::table('audit_logs')->where('action', 'admin.2fa.disabled')->where('actor_id', 'adm_idem_2fa')->count());

        $this->assertNoRawSensitiveValuesInIdempotencyOrAudit([
            $resetTokenA,
            $resetTokenB,
            'idem-reset-password-a',
            'idem-reset-password-b',
            'secret-password',
            'changed-current-password',
            'idem-change-password-a',
            'idem-change-password-b',
            $totp,
            $changedTotp,
            $setup['secret'],
            $setup['recovery_codes'][0],
            $rotated['recovery_codes'][0],
        ]);
    }

    public function test_M10AdminSecurityLinePolicy_line_routes_are_tenant_bound_and_do_not_fake_provider_success(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_line_a', 'ten_line_a', 'line-a.m10.test');
        $this->insertActivePartnerTenantWithDomain('par_line_b', 'ten_line_b', 'line-b.m10.test');
        DB::table('partner_tenant_domains')->insert([
            'id' => 'dom_line_a_alt',
            'partner_id' => 'par_line_a',
            'tenant_id' => 'ten_line_a',
            'host' => 'line-a-alt.m10.test',
            'type' => 'custom',
            'status' => 'active',
            'is_primary' => false,
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson('http://line-a.m10.test/api/v1/customer/auth/line/login')
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'provider_not_configured')
            ->assertJsonPath('error.details.provider_status', 'blocked_external')
            ->assertJsonPath('error.details.production_line_ready', false);

        config([
            'platform.line.client_id' => 'line-client-id',
            'platform.line.client_secret' => 'line-client-secret',
            'platform.line.callback_url' => 'https://line-a.m10.test/api/v1/customer/auth/line/callback',
        ]);

        $redirect = $this->postJson('http://line-a.m10.test/api/v1/customer/auth/line/login', [
            'store_id' => 'store-alpha',
        ])
            ->assertOk()
            ->assertJsonPath('provider', 'line')
            ->assertJsonPath('production_line_ready', false)
            ->json();

        parse_str((string) parse_url($redirect['url'], PHP_URL_QUERY), $query);
        $this->assertSame('line-client-id', $query['client_id']);
        $this->assertNotEmpty($query['state']);
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_line_a',
            'provider' => 'line',
            'state_hash' => hash('sha256', (string) $query['state']),
            'status' => 'pending',
        ]);

        $this->getJson('http://line-b.m10.test/api/v1/customer/auth/line/callback?code=line-code&state='.$query['state'])
            ->assertUnauthorized();

        $this->getJson('http://line-a-alt.m10.test/api/v1/customer/auth/line/callback?code=line-code&state='.$query['state'])
            ->assertUnauthorized();

        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_line_a',
            'state_hash' => hash('sha256', (string) $query['state']),
            'status' => 'pending',
        ]);

        $this->getJson('http://line-a.m10.test/api/v1/customer/auth/line/callback?code=line-code&state='.$query['state'])
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'provider_exchange_blocked')
            ->assertJsonPath('error.details.provider_status', 'blocked_external')
            ->assertJsonPath('error.details.production_line_ready', false)
            ->assertJsonPath('error.details.line_code', '[REDACTED]');

        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_line_a',
            'state_hash' => hash('sha256', (string) $query['state']),
            'status' => 'consumed',
        ]);

        $this->getJson('http://line-a.m10.test/api/v1/customer/auth/line/callback?code=line-code&state='.$query['state'])
            ->assertUnauthorized();
    }

    /**
     * @return array{session_id: string, token: string}
     */
    private function createSupportImpersonationSession(string $tenantId, string $adminId): array
    {
        $token = 'support-token-m10-security';

        DB::table('support_access_requests')->insert([
            'id' => 'sar_security_block',
            'tenant_id' => $tenantId,
            'target_user_id' => 'cus_support_target',
            'target_user_type' => 'customer',
            'scope' => 'customer_limited_write',
            'status' => 'approved',
            'reason' => 'security test',
            'ticket_id' => 'SUP-SECURITY',
            'requested_by_admin_id' => $adminId,
            'approved_by_admin_id' => $adminId,
            'approved_at' => now(),
            'expires_at' => now()->addHour(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('support_impersonation_sessions')->insert([
            'id' => 'sis_security_block',
            'tenant_id' => $tenantId,
            'support_access_request_id' => 'sar_security_block',
            'target_user_id' => 'cus_support_target',
            'target_user_type' => 'customer',
            'scope' => 'customer_limited_write',
            'status' => 'active',
            'token_hash' => hash('sha256', $token),
            'token_last_four' => substr($token, -4),
            'issued_to_admin_id' => $adminId,
            'started_at' => now(),
            'expires_at' => now()->addHour(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return ['session_id' => 'sis_security_block', 'token' => $token];
    }

    private function totpCode(string $secret): string
    {
        $key = $this->base32Decode($secret);
        $counter = intdiv(time(), 30);
        $binaryCounter = pack('N2', intdiv($counter, 4294967296), $counter % 4294967296);
        $hash = hash_hmac('sha1', $binaryCounter, $key, true);
        $offset = ord($hash[19]) & 0x0f;
        $value = ((ord($hash[$offset]) & 0x7f) << 24)
            | ((ord($hash[$offset + 1]) & 0xff) << 16)
            | ((ord($hash[$offset + 2]) & 0xff) << 8)
            | (ord($hash[$offset + 3]) & 0xff);

        return str_pad((string) ($value % 1000000), 6, '0', STR_PAD_LEFT);
    }

    private function differentTotpCode(string $code): string
    {
        return $code === '000000' ? '000001' : '000000';
    }

    /**
     * @param array<int, string> $values
     */
    private function assertNoRawSensitiveValuesInIdempotencyOrAudit(array $values): void
    {
        $idempotencyBodies = DB::table('idempotency_keys')
            ->pluck('response_body_json')
            ->filter()
            ->implode("\n");
        $auditPayloads = DB::table('audit_logs')
            ->pluck('payload_redacted_json')
            ->filter()
            ->implode("\n");

        foreach ($values as $value) {
            $this->assertStringNotContainsString($value, $idempotencyBodies, 'Raw sensitive value leaked into idempotency response body.');
            $this->assertStringNotContainsString($value, $auditPayloads, 'Raw sensitive value leaked into audit payload.');
        }
    }

    private function base32Decode(string $secret): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $bits = '';

        foreach (str_split(strtoupper($secret)) as $char) {
            $position = strpos($alphabet, $char);

            if ($position !== false) {
                $bits .= str_pad(decbin($position), 5, '0', STR_PAD_LEFT);
            }
        }

        $bytes = '';

        foreach (str_split($bits, 8) as $chunk) {
            if (strlen($chunk) === 8) {
                $bytes .= chr(bindec($chunk));
            }
        }

        return $bytes;
    }
}
