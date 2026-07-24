<?php

namespace Tests\Unit;

use App\Modules\CustomerSupport\Services\SupportSessionTokenService;
use Tests\TestCase;

class SupportSessionTokenServiceTest extends TestCase
{
    public function test_it_issues_a_ten_minute_rs256_support_token(): void
    {
        $key = openssl_pkey_new([
            'digest_alg' => 'sha256',
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);
        $privateKey = '';
        openssl_pkey_export($key, $privateKey);
        $details = openssl_pkey_get_details($key);
        config([
            'support.jwt.private_key' => $privateKey,
            'support.jwt.private_key_path' => null,
            'support.jwt.ttl_seconds' => 600,
        ]);

        $result = app(SupportSessionTokenService::class)->issue([
            'sub' => 'customer-test',
            'tenant_id' => 'tenant-test',
            'actor_type' => 'customer',
            'permissions' => [],
        ]);
        [$encodedHeader, $encodedPayload, $encodedSignature] = explode('.', $result['token']);
        $header = json_decode($this->decode($encodedHeader), true, flags: JSON_THROW_ON_ERROR);
        $payload = json_decode($this->decode($encodedPayload), true, flags: JSON_THROW_ON_ERROR);
        $signature = $this->decode($encodedSignature);

        $this->assertSame('RS256', $header['alg']);
        $this->assertSame('newpaotang-support', $payload['aud']);
        $this->assertSame('customer-test', $payload['sub']);
        $this->assertSame('tenant-test', $payload['tenant_id']);
        $this->assertSame(600, $payload['exp'] - $payload['iat']);
        $this->assertSame(
            1,
            openssl_verify(
                $encodedHeader.'.'.$encodedPayload,
                $signature,
                $details['key'],
                OPENSSL_ALGO_SHA256,
            ),
        );
        $this->assertSame($payload['exp'], strtotime($result['expires_at']));
    }

    private function decode(string $value): string
    {
        $padding = strlen($value) % 4;
        if ($padding !== 0) {
            $value .= str_repeat('=', 4 - $padding);
        }

        return base64_decode(strtr($value, '-_', '+/'), true);
    }
}
