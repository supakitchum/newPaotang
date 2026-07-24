<?php

namespace App\Modules\CustomerSupport\Services;

use Illuminate\Support\Str;
use RuntimeException;

class SupportSessionTokenService
{
    /**
     * @param array<string, mixed> $claims
     * @return array{token: string, expires_at: string}
     */
    public function issue(array $claims): array
    {
        $now = now();
        $expires = $now->copy()->addSeconds(max(60, (int) config('support.jwt.ttl_seconds', 600)));
        $payload = [
            'iss' => (string) config('support.jwt.issuer'),
            'aud' => (string) config('support.jwt.audience'),
            'iat' => $now->getTimestamp(),
            'nbf' => $now->getTimestamp() - 5,
            'exp' => $expires->getTimestamp(),
            'jti' => (string) Str::uuid(),
            ...$claims,
        ];
        $unsigned = $this->encode(['alg' => 'RS256', 'typ' => 'JWT']).'.'.$this->encode($payload);
        $signature = '';
        if (! openssl_sign($unsigned, $signature, $this->privateKey(), OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Unable to sign the support session token.');
        }

        return [
            'token' => $unsigned.'.'.$this->base64UrlEncode($signature),
            'expires_at' => $expires->toIso8601String(),
        ];
    }

    private function privateKey(): \OpenSSLAsymmetricKey
    {
        $inline = trim((string) config('support.jwt.private_key'));
        $path = trim((string) config('support.jwt.private_key_path'));
        $pem = $inline !== '' ? str_replace('\n', "\n", $inline) : '';
        if ($pem === '' && $path !== '' && is_readable($path)) {
            $pem = (string) file_get_contents($path);
        }
        $key = $pem === '' ? false : openssl_pkey_get_private($pem);
        if (! $key instanceof \OpenSSLAsymmetricKey) {
            throw new RuntimeException('The Support JWT private key is not configured.');
        }

        return $key;
    }

    /**
     * @param array<string, mixed> $value
     */
    private function encode(array $value): string
    {
        return $this->base64UrlEncode(json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
