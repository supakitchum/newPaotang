<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected string $privateKey = '';

    public function createApplication(): Application
    {
        putenv('APP_ENV=testing');
        $_ENV['APP_ENV'] = 'testing';
        $_SERVER['APP_ENV'] = 'testing';

        $app = require __DIR__.'/../bootstrap/app.php';
        $app->loadEnvironmentFrom('.env.example');
        $app->make(Kernel::class)->bootstrap();

        return $app;
    }

    protected function setUp(): void
    {
        parent::setUp();

        $key = openssl_pkey_new([
            'digest_alg' => 'sha256',
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ]);
        openssl_pkey_export($key, $this->privateKey);
        $details = openssl_pkey_get_details($key);

        config([
            'app.url' => 'http://localhost',
            'broadcasting.default' => 'null',
            'cache.default' => 'array',
            'queue.default' => 'sync',
            'support.jwt.public_key' => $details['key'],
            'support.jwt.public_key_path' => null,
        ]);
        $this->app['url']->forceRootUrl('http://localhost');
    }

    /**
     * @param array<int, string> $permissions
     * @param array<string, mixed> $overrides
     */
    protected function supportToken(
        string $actorType,
        string $subject,
        string $tenantId = 'tenant_test_one',
        array $permissions = [],
        array $overrides = [],
    ): string {
        $now = time();
        $payload = [
            'iss' => config('support.jwt.issuer'),
            'aud' => config('support.jwt.audience'),
            'iat' => $now,
            'nbf' => $now - 1,
            'exp' => $now + 600,
            'jti' => bin2hex(random_bytes(12)),
            'sub' => $subject,
            'tenant_id' => $tenantId,
            'tenant_name' => 'Test Tenant',
            'actor_type' => $actorType,
            'name' => $actorType === 'customer' ? 'Test Customer' : 'Support Agent',
            'locale' => 'th-TH',
            'support_enabled' => true,
            'permissions' => $permissions,
            ...$overrides,
        ];
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $encodedHeader = $this->base64Url(json_encode($header, JSON_THROW_ON_ERROR));
        $encodedPayload = $this->base64Url(json_encode($payload, JSON_THROW_ON_ERROR));
        openssl_sign(
            $encodedHeader.'.'.$encodedPayload,
            $signature,
            $this->privateKey,
            OPENSSL_ALGO_SHA256,
        );

        return $encodedHeader.'.'.$encodedPayload.'.'.$this->base64Url($signature);
    }

    /**
     * @return array<string, string>
     */
    protected function supportHeaders(string $token, ?string $idempotencyKey = null): array
    {
        return [
            'Authorization' => 'Bearer '.$token,
            'Accept' => 'application/json',
            'Accept-Language' => 'th-TH',
            ...($idempotencyKey === null ? [] : ['Idempotency-Key' => $idempotencyKey]),
        ];
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
