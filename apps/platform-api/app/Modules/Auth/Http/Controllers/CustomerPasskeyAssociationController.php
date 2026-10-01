<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Passkeys\CustomerPasskeyConfiguration;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerPasskeyAssociationController extends Controller
{
    public function __construct(
        private readonly CustomerPasskeyConfiguration $configuration,
        private readonly PartnerStoreService $partnerStore,
    ) {
    }

    public function apple(Request $request): JsonResponse
    {
        if (! $this->tenantDomainIsActive($request)) {
            return response()->json([], 404);
        }

        $appIds = $this->configuration->iosAppIds();

        return $this->json([
            'applinks' => [
                'apps' => [],
                'details' => $appIds === [] ? [] : [[
                    'appIDs' => $appIds,
                    'components' => [['/' => '/*']],
                ]],
            ],
            'webcredentials' => [
                'apps' => $appIds,
            ],
        ]);
    }

    public function android(Request $request): JsonResponse
    {
        if (! $this->tenantDomainIsActive($request)) {
            return response()->json([], 404);
        }

        $app = $this->configuration->androidApp();
        if ($app === null) {
            return $this->json([]);
        }

        return $this->json([[
            'relation' => [
                'delegate_permission/common.get_login_creds',
                'delegate_permission/common.handle_all_urls',
            ],
            'target' => [
                'namespace' => 'android_app',
                'package_name' => $app['package_name'],
                'sha256_cert_fingerprints' => $app['sha256_cert_fingerprints'],
            ],
        ]]);
    }

    /**
     * @param array<int|string, mixed> $payload
     */
    private function json(array $payload): JsonResponse
    {
        return response()
            ->json($payload, 200, [
                'Content-Type' => 'application/json',
                'Cache-Control' => 'public, max-age=300',
            ], JSON_UNESCAPED_SLASHES);
    }

    private function tenantDomainIsActive(Request $request): bool
    {
        $result = $this->partnerStore->tenantContextForRequest($request, false);

        return isset($result['context']['tenant_id']);
    }
}
