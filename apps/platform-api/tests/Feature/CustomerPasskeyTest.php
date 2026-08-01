<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\CustomerPasskey;
use App\Models\CustomerPasskeyChallenge;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Passkeys\Support\WebAuthn;
use ParagonIE\ConstantTime\Base64UrlSafe;
use Symfony\Component\Uid\Uuid;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;
use Webauthn\AuthenticatorData;
use Webauthn\CredentialRecord;
use Webauthn\PublicKeyCredentialCreationOptions;
use Webauthn\PublicKeyCredentialRequestOptions;
use Webauthn\TrustPath\EmptyTrustPath;
use Webauthn\U2FPublicKey;

class CustomerPasskeyTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_passkey_login_uses_a_tenant_challenge_and_issues_a_pin_gated_session_idempotently(): void
    {
        $this->insertActivePartnerTenantWithDomain(
            'par_passkey',
            'ten_passkey',
            'passkey.example.test',
        );
        $oldToken = $this->issueCustomerToken('ten_passkey', 'cus_passkey');
        $oldSessionId = (string) DB::table('customer_auth_sessions')
            ->where('access_token_hash', hash('sha256', $oldToken))
            ->value('id');
        $customer = Customer::query()->whereKey('cus_passkey')->firstOrFail();
        $credentialId = random_bytes(16);
        $keypair = $this->fixtureEcKeypair();
        $source = CredentialRecord::create(
            publicKeyCredentialId: $credentialId,
            type: 'public-key',
            transports: [],
            attestationType: 'none',
            trustPath: EmptyTrustPath::create(),
            aaguid: Uuid::v4(),
            credentialPublicKey: $keypair['cose_public_key'],
            userHandle: $customer->getPasskeyUserHandle(),
            counter: 0,
        );
        $passkey = CustomerPasskey::query()->create([
            'tenant_id' => 'ten_passkey',
            'user_id' => (string) $customer->id,
            'name' => 'Test iPhone',
            'credential_id' => Base64UrlSafe::encodeUnpadded($credentialId),
            'credential' => json_decode(
                WebAuthn::toJson($source),
                true,
                flags: JSON_THROW_ON_ERROR,
            ),
            'status' => 'active',
        ]);

        $optionsPayload = $this->postJson(
            'https://passkey.example.test/api/v1/customer/auth/passkeys/login/options',
        )
            ->assertOk()
            ->assertJsonPath('rp_id', 'passkey.example.test')
            ->assertJsonPath('options.rpId', 'passkey.example.test')
            ->assertJsonPath('options.userVerification', 'required')
            ->assertJsonPath('options.allowCredentials', [])
            ->json();

        $challenge = CustomerPasskeyChallenge::query()
            ->whereKey($optionsPayload['challenge_id'])
            ->firstOrFail();
        $this->assertSame('ten_passkey', (string) $challenge->tenant_id);
        $this->assertSame('authentication', (string) $challenge->ceremony);
        $this->assertContains(
            'https://passkey.example.test',
            $challenge->allowed_origins_json,
        );
        $options = WebAuthn::fromJson(
            json_encode($challenge->options_json, JSON_THROW_ON_ERROR),
            PublicKeyCredentialRequestOptions::class,
        );
        $credential = $this->signedAssertionPayload(
            $credentialId,
            $options->challenge,
            'passkey.example.test',
            $keypair['private_key_pem'],
        );
        $request = [
            'challenge_id' => $optionsPayload['challenge_id'],
            'credential' => $credential,
        ];

        $login = $this->postJson(
            'https://passkey.example.test/api/v1/customer/auth/passkeys/login/verify',
            $request,
            ['Idempotency-Key' => 'passkey-login-success'],
        )
            ->assertOk()
            ->assertJsonPath('passkey_login', true)
            ->assertJsonPath('pin_required', true)
            ->assertJsonPath('session_activation_required', true)
            ->assertJsonPath('user.id', 'cus_passkey')
            ->json();

        $this->assertDatabaseHas('customer_passkey_challenges', [
            'id' => $optionsPayload['challenge_id'],
            'tenant_id' => 'ten_passkey',
            'status' => 'consumed',
        ]);
        $this->assertNotNull($passkey->refresh()->last_used_at);
        $this->assertDatabaseHas('wallets', [
            'tenant_id' => 'ten_passkey',
            'customer_id' => 'cus_passkey',
            'type' => 'primary',
        ]);
        $this->assertNull(
            DB::table('customer_auth_sessions')
                ->where('id', $oldSessionId)
                ->value('revoked_at'),
        );

        $this->postJson(
            'https://passkey.example.test/api/v1/customer/auth/passkeys/login/verify',
            $request,
            ['Idempotency-Key' => 'passkey-login-success'],
        )
            ->assertOk()
            ->assertJsonPath('session_id', $login['session_id'])
            ->assertJsonPath('token', $login['token']);

        $this->withToken($login['token'])
            ->postJson(
                'https://passkey.example.test/api/v1/customer/auth/pin/verify',
                ['pin' => '246810'],
            )
            ->assertOk()
            ->assertJsonPath('pin_verified', true);

        $this->assertDatabaseHas('customer_auth_sessions', [
            'id' => $oldSessionId,
            'revoked_reason' => 'replaced_by_new_login',
            'replaced_by_session_id' => $login['session_id'],
        ]);
    }

    public function test_passkey_management_is_pin_and_tenant_scoped_and_rejects_expired_challenges(): void
    {
        $this->insertActivePartnerTenantWithDomain(
            'par_passkey_a',
            'ten_passkey_a',
            'passkey-a.example.test',
        );
        $this->insertActivePartnerTenantWithDomain(
            'par_passkey_b',
            'ten_passkey_b',
            'passkey-b.example.test',
        );
        $tokenA = $this->issueCustomerToken('ten_passkey_a', 'cus_passkey_a');
        $tokenB = $this->issueCustomerToken('ten_passkey_b', 'cus_passkey_b');
        $passkeyA = CustomerPasskey::query()->create([
            'tenant_id' => 'ten_passkey_a',
            'user_id' => 'cus_passkey_a',
            'name' => 'Customer A phone',
            'credential_id' => Base64UrlSafe::encodeUnpadded(random_bytes(16)),
            'credential' => [],
            'status' => 'active',
        ]);

        $this->withToken($tokenA)
            ->getJson('https://passkey-a.example.test/api/v1/customer/auth/passkeys')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', (string) $passkeyA->id)
            ->assertJsonPath('data.0.name', 'Customer A phone')
            ->assertJsonPath('enabled', true)
            ->assertJsonPath('can_register', true)
            ->assertJsonPath('rp_id', 'passkey-a.example.test');

        $this->withToken($tokenB)
            ->deleteJson(
                'https://passkey-b.example.test/api/v1/customer/auth/passkeys/'.$passkeyA->id,
            )
            ->assertNotFound();
        $this->assertDatabaseHas('customer_passkeys', [
            'id' => (string) $passkeyA->id,
            'status' => 'active',
        ]);

        $successfulRegistration = $this->withToken($tokenA)
            ->postJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys/register/options',
            )
            ->assertOk()
            ->json();
        $creationOptions = WebAuthn::fromJson(
            json_encode(
                CustomerPasskeyChallenge::query()
                    ->whereKey($successfulRegistration['challenge_id'])
                    ->firstOrFail()
                    ->options_json,
                JSON_THROW_ON_ERROR,
            ),
            PublicKeyCredentialCreationOptions::class,
        );
        $registrationCredentialId = random_bytes(16);
        $registrationKeypair = $this->fixtureEcKeypair();
        $registrationRequest = [
            'challenge_id' => $successfulRegistration['challenge_id'],
            'name' => 'Work iPhone',
            'credential' => $this->registrationCredentialPayload(
                $registrationCredentialId,
                $creationOptions->challenge,
                'passkey-a.example.test',
                $registrationKeypair['cose_public_key'],
            ),
        ];
        $createdPasskey = $this->withToken($tokenA)
            ->postJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys',
                $registrationRequest,
                ['Idempotency-Key' => 'passkey-register-success'],
            )
            ->assertCreated()
            ->assertJsonPath('data.name', 'Work iPhone')
            ->assertJsonPath('data.status', 'active')
            ->json('data');
        $this->assertDatabaseHas('customer_passkeys', [
            'id' => $createdPasskey['id'],
            'tenant_id' => 'ten_passkey_a',
            'user_id' => 'cus_passkey_a',
            'credential_id' => Base64UrlSafe::encodeUnpadded(
                $registrationCredentialId,
            ),
            'status' => 'active',
        ]);
        $this->withToken($tokenA)
            ->postJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys',
                $registrationRequest,
                ['Idempotency-Key' => 'passkey-register-success'],
            )
            ->assertCreated()
            ->assertJsonPath('data.id', $createdPasskey['id']);

        $registration = $this->withToken($tokenA)
            ->postJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys/register/options',
            )
            ->assertOk()
            ->assertJsonPath('rp_id', 'passkey-a.example.test')
            ->assertJsonPath('options.rp.id', 'passkey-a.example.test')
            ->assertJsonPath('options.user.name', '080'.substr(sha1('cus_passkey_a'), 0, 7))
            ->assertJsonPath('options.authenticatorSelection.residentKey', 'required')
            ->json();

        DB::table('customer_passkey_challenges')
            ->where('id', $registration['challenge_id'])
            ->update(['expires_at' => now()->subSecond()]);

        $this->withToken($tokenA)
            ->postJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys',
                [
                    'challenge_id' => $registration['challenge_id'],
                    'name' => 'Expired registration',
                    'credential' => $this->structuralCredential(),
                ],
                ['Idempotency-Key' => 'passkey-expired-register'],
            )
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'passkey_challenge_invalid');

        $this->withToken($tokenA)
            ->deleteJson(
                'https://passkey-a.example.test/api/v1/customer/auth/passkeys/'.$passkeyA->id,
            )
            ->assertOk()
            ->assertJsonPath('data.revoked', true);
        $this->assertDatabaseHas('customer_passkeys', [
            'id' => (string) $passkeyA->id,
            'tenant_id' => 'ten_passkey_a',
            'status' => 'revoked',
        ]);
    }

    public function test_passkey_feature_flag_and_platform_association_files_are_runtime_configured(): void
    {
        $this->insertActivePartnerTenantWithDomain(
            'par_passkey_config',
            'ten_passkey_config',
            'passkey-config.example.test',
        );
        DB::table('partner_tenant_feature_flags')->insert([
            'id' => 'ptf_passkey_config',
            'tenant_id' => 'ten_passkey_config',
            'feature_key' => 'passkey_login',
            'enabled' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->postJson(
            'https://passkey-config.example.test/api/v1/customer/auth/passkeys/login/options',
        )
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');
        $this->getJson(
            'https://passkey-config.example.test/api/v1/public/mobile/bootstrap',
        )
            ->assertOk()
            ->assertJsonPath('data.mobile.passkeys.enabled', false)
            ->assertJsonPath('data.mobile.passkeys.rp_id', 'passkey-config.example.test')
            ->assertJsonPath('data.mobile.feature_flags.passkey_login', false);

        config()->set('passkeys.customer.ios_app_ids', [
            'TEAM123456.com.example.customer',
        ]);
        config()->set('passkeys.customer.android.package_name', 'com.example.customer');
        config()->set('passkeys.customer.android.sha256_cert_fingerprints', [
            'AA:'.str_repeat('BB:', 30).'CC',
        ]);

        $this->getJson(
            'https://passkey-config.example.test/.well-known/apple-app-site-association',
        )
            ->assertOk()
            ->assertJsonPath(
                'webcredentials.apps.0',
                'TEAM123456.com.example.customer',
            );
        $this->getJson(
            'https://passkey-config.example.test/.well-known/assetlinks.json',
        )
            ->assertOk()
            ->assertJsonPath('0.target.package_name', 'com.example.customer')
            ->assertJsonPath(
                '0.relation.0',
                'delegate_permission/common.get_login_creds',
            );
    }

    /**
     * @return array{private_key_pem: string, cose_public_key: string}
     */
    private function fixtureEcKeypair(): array
    {
        $privateKeyPem = <<<'PEM'
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIExwigMuj7pGzk+XVIKVp72gYQc6AU//5HlUHb3X5HGRoAoGCCqGSM49
AwEHoUQDQgAE53mVK/HTD1mPae7VZ8uzETJC7ZLmAyWKa75YyZ9lNbHFl8oSKWJe
RYf/wGQSBmBTBSaU+rRuRbuVAx2zexNCzQ==
-----END EC PRIVATE KEY-----
PEM;
        $privateKey = openssl_pkey_get_private($privateKeyPem);
        $details = openssl_pkey_get_details($privateKey);
        $ec = $details['ec'];
        $u2fPublicKey = "\x04"
            .str_pad($ec['x'], 32, "\0", STR_PAD_LEFT)
            .str_pad($ec['y'], 32, "\0", STR_PAD_LEFT);

        return [
            'private_key_pem' => $privateKeyPem,
            'cose_public_key' => U2FPublicKey::convertToCoseKey($u2fPublicKey),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function signedAssertionPayload(
        string $credentialId,
        string $challenge,
        string $rpId,
        string $privateKeyPem,
    ): array {
        $origin = 'https://'.$rpId;
        $clientDataPayload = [
            'type' => 'webauthn.get',
            'challenge' => Base64UrlSafe::encodeUnpadded($challenge),
            'origin' => $origin,
        ];
        $clientDataRaw = json_encode($clientDataPayload, JSON_THROW_ON_ERROR);
        $rpIdHash = hash('sha256', $rpId, binary: true);
        $flags = chr(AuthenticatorData::FLAG_UP | AuthenticatorData::FLAG_UV);
        $authenticatorDataRaw = $rpIdHash.$flags.pack('N', 1);
        $signaturePayload = $authenticatorDataRaw
            .hash('sha256', $clientDataRaw, binary: true);
        $signature = '';
        openssl_sign(
            $signaturePayload,
            $signature,
            $privateKeyPem,
            OPENSSL_ALGO_SHA256,
        );

        $encodedCredentialId = Base64UrlSafe::encodeUnpadded($credentialId);

        return [
            'id' => $encodedCredentialId,
            'type' => 'public-key',
            'rawId' => $encodedCredentialId,
            'response' => [
                'clientDataJSON' => Base64UrlSafe::encodeUnpadded($clientDataRaw),
                'authenticatorData' => Base64UrlSafe::encodeUnpadded($authenticatorDataRaw),
                'signature' => Base64UrlSafe::encodeUnpadded($signature),
                'userHandle' => null,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function registrationCredentialPayload(
        string $credentialId,
        string $challenge,
        string $rpId,
        string $credentialPublicKey,
    ): array {
        $clientDataRaw = json_encode([
            'type' => 'webauthn.create',
            'challenge' => Base64UrlSafe::encodeUnpadded($challenge),
            'origin' => 'https://'.$rpId,
        ], JSON_THROW_ON_ERROR);
        $flags = chr(
            AuthenticatorData::FLAG_UP
            | AuthenticatorData::FLAG_UV
            | AuthenticatorData::FLAG_AT,
        );
        $authenticatorData = hash('sha256', $rpId, binary: true)
            .$flags
            .pack('N', 0)
            .str_repeat("\0", 16)
            .pack('n', strlen($credentialId))
            .$credentialId
            .$credentialPublicKey;
        $attestationObject = "\xA3"
            ."\x63fmt\x64none"
            ."\x67attStmt\xA0"
            ."\x68authData"
            .$this->cborByteString($authenticatorData);
        $encodedCredentialId = Base64UrlSafe::encodeUnpadded($credentialId);

        return [
            'id' => $encodedCredentialId,
            'rawId' => $encodedCredentialId,
            'type' => 'public-key',
            'response' => [
                'clientDataJSON' => Base64UrlSafe::encodeUnpadded($clientDataRaw),
                'attestationObject' => Base64UrlSafe::encodeUnpadded(
                    $attestationObject,
                ),
                'transports' => ['internal'],
            ],
        ];
    }

    private function cborByteString(string $value): string
    {
        $length = strlen($value);
        if ($length <= 23) {
            return chr(0x40 | $length).$value;
        }
        if ($length <= 0xff) {
            return "\x58".chr($length).$value;
        }

        return "\x59".pack('n', $length).$value;
    }

    /**
     * @return array<string, mixed>
     */
    private function structuralCredential(): array
    {
        $rawId = Base64UrlSafe::encodeUnpadded(random_bytes(16));

        return [
            'id' => $rawId,
            'rawId' => $rawId,
            'type' => 'public-key',
            'response' => [],
        ];
    }
}
