<?php

namespace App\Modules\Auth\Passkeys;

use App\Models\CustomerPasskey;
use Laravel\Passkeys\Actions\VerifyPasskey;
use Laravel\Passkeys\Exceptions\InvalidPasskeyException;
use Laravel\Passkeys\Passkey;
use ParagonIE\ConstantTime\Base64UrlSafe;
use Webauthn\PublicKeyCredential;

class VerifyCustomerPasskey extends VerifyPasskey
{
    public function __construct(private readonly string $tenantId)
    {
    }

    public function getPasskey(PublicKeyCredential $credential, bool $lock = false): Passkey
    {
        $credentialId = Base64UrlSafe::encodeUnpadded($credential->rawId);
        $query = CustomerPasskey::query()
            ->where('tenant_id', $this->tenantId)
            ->where('credential_id', $credentialId)
            ->where('status', 'active')
            ->whereNull('revoked_at');

        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first()
            ?? throw InvalidPasskeyException::make(
                'Passkey not recognized. It may have been removed from your account.',
            );
    }
}
