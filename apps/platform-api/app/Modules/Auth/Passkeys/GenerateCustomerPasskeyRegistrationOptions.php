<?php

namespace App\Modules\Auth\Passkeys;

use Laravel\Passkeys\Actions\GenerateRegistrationOptions;
use Webauthn\PublicKeyCredentialRpEntity;

class GenerateCustomerPasskeyRegistrationOptions extends GenerateRegistrationOptions
{
    public function __construct(
        private readonly string $rpId,
        private readonly string $rpName,
    ) {
    }

    protected function relyingParty(): PublicKeyCredentialRpEntity
    {
        return PublicKeyCredentialRpEntity::create(
            name: $this->rpName,
            id: $this->rpId,
        );
    }
}
