<?php

namespace Tests\Unit;

use App\Shared\Audit\AuditLogger;
use Tests\TestCase;

class AuditLoggerTest extends TestCase
{
    public function test_audit_payload_redacts_sensitive_fields_recursively(): void
    {
        $redacted = app(AuditLogger::class)->redactPayload([
            'email' => 'admin@example.test',
            'password' => 'secret-password',
            'payload_hash' => 'hash-value',
            'invitation_url' => 'https://example.test/invite/abc',
            'invitation_code' => 'INVITE-CODE',
            'invite_link' => 'https://example.test/join/abc',
            'nested' => [
                'access_token' => 'token-value',
                'refresh_token_hash' => 'refresh-token-hash',
                'client_secret' => 'secret-value',
                'invite_payload' => [
                    'material' => 'invite-material',
                ],
                'public_note' => 'keep me',
            ],
            'credentials' => [
                'api_key' => 'key-value',
            ],
        ]);

        $this->assertSame('[REDACTED]', $redacted['password']);
        $this->assertSame('[REDACTED]', $redacted['payload_hash']);
        $this->assertSame('[REDACTED]', $redacted['invitation_url']);
        $this->assertSame('[REDACTED]', $redacted['invitation_code']);
        $this->assertSame('[REDACTED]', $redacted['invite_link']);
        $this->assertSame('[REDACTED]', $redacted['nested']['access_token']);
        $this->assertSame('[REDACTED]', $redacted['nested']['refresh_token_hash']);
        $this->assertSame('[REDACTED]', $redacted['nested']['client_secret']);
        $this->assertSame('[REDACTED]', $redacted['nested']['invite_payload']);
        $this->assertSame('[REDACTED]', $redacted['credentials']);
        $this->assertSame('keep me', $redacted['nested']['public_note']);
    }
}
