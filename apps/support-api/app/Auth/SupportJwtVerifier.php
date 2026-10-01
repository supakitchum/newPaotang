<?php

namespace App\Auth;

use RuntimeException;

class SupportJwtVerifier
{
    /**
     * @return array<string, mixed>
     */
    public function verify(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new RuntimeException('Malformed support token.');
        }

        [$encodedHeader, $encodedPayload, $encodedSignature] = $parts;
        $header = $this->decodeJson($encodedHeader);
        $payload = $this->decodeJson($encodedPayload);
        $signature = $this->decode($encodedSignature);

        if (($header['alg'] ?? null) !== 'RS256') {
            throw new RuntimeException('Unsupported support token algorithm.');
        }

        $key = openssl_pkey_get_public($this->publicKey());
        if ($key === false || openssl_verify(
            $encodedHeader.'.'.$encodedPayload,
            $signature,
            $key,
            OPENSSL_ALGO_SHA256,
        ) !== 1) {
            throw new RuntimeException('Invalid support token signature.');
        }

        $now = time();
        $skew = max(0, (int) config('support.jwt.clock_skew_seconds', 30));
        if ((int) ($payload['exp'] ?? 0) < $now - $skew) {
            throw new RuntimeException('Support token has expired.');
        }
        if ((int) ($payload['nbf'] ?? 0) > $now + $skew) {
            throw new RuntimeException('Support token is not active.');
        }
        if (($payload['iss'] ?? null) !== config('support.jwt.issuer')) {
            throw new RuntimeException('Invalid support token issuer.');
        }

        $audience = $payload['aud'] ?? null;
        $validAudience = is_array($audience)
            ? in_array(config('support.jwt.audience'), $audience, true)
            : $audience === config('support.jwt.audience');
        if (! $validAudience) {
            throw new RuntimeException('Invalid support token audience.');
        }

        foreach (['sub', 'tenant_id', 'actor_type'] as $claim) {
            if (! is_string($payload[$claim] ?? null) || trim($payload[$claim]) === '') {
                throw new RuntimeException('Missing support token claim: '.$claim);
            }
        }
        if (! in_array($payload['actor_type'], ['customer', 'admin'], true)) {
            throw new RuntimeException('Invalid support actor type.');
        }

        return $payload;
    }

    private function publicKey(): string
    {
        $inline = trim((string) config('support.jwt.public_key'));
        if ($inline !== '') {
            return str_replace('\n', "\n", $inline);
        }

        $path = trim((string) config('support.jwt.public_key_path'));
        if ($path === '' || ! is_readable($path)) {
            throw new RuntimeException('Support JWT public key is not configured.');
        }

        $contents = file_get_contents($path);
        if (! is_string($contents) || trim($contents) === '') {
            throw new RuntimeException('Support JWT public key is empty.');
        }

        return $contents;
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJson(string $value): array
    {
        $decoded = json_decode($this->decode($value), true);
        if (! is_array($decoded)) {
            throw new RuntimeException('Malformed support token JSON.');
        }

        return $decoded;
    }

    private function decode(string $value): string
    {
        $padding = strlen($value) % 4;
        if ($padding !== 0) {
            $value .= str_repeat('=', 4 - $padding);
        }
        $decoded = base64_decode(strtr($value, '-_', '+/'), true);
        if ($decoded === false) {
            throw new RuntimeException('Malformed support token encoding.');
        }

        return $decoded;
    }
}
