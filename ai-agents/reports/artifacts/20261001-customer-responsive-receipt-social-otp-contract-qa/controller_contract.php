<?php

require '/var/www/html/vendor/autoload.php';

use App\Modules\Auth\Http\Controllers\CustomerLineAuthController;
use App\Modules\Auth\Http\Controllers\CustomerSocialAuthController;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Auth\Services\CustomerLineAuthService;
use App\Modules\Auth\Services\CustomerSocialAccountService;
use App\Modules\Auth\Services\CustomerSocialAuthService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use Illuminate\Container\Container;
use Illuminate\Contracts\Routing\ResponseFactory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Shared\Auth\CustomerSessionResolver;

// Exercise production serializers/controllers with all persistence replaced in memory.
$container = new Container();
Container::setInstance($container);
$factory = Mockery::mock(ResponseFactory::class);
$factory->shouldReceive('json')->andReturnUsing(fn ($data, $status) => new JsonResponse($data, $status));
$container->instance(ResponseFactory::class, $factory);

$wallet = Mockery::mock('alias:App\Models\Wallet');
$walletQuery = Mockery::mock();
$walletQuery->shouldReceive('where', 'orderByRaw', 'orderBy')->andReturnSelf();
$walletQuery->shouldReceive('first')->andReturn(null);
$wallet->shouldReceive('query')->andReturn($walletQuery);

$auth = (new ReflectionClass(CustomerAuthService::class))->newInstanceWithoutConstructor();
$tenant = ['tenant_id' => 'ten_fictional'];
$requestPayload = [
    'link_token' => 'fictional-handoff', 'phone' => '0812345678',
    'otp_verification_token' => 'fictional-register-otp', 'existing_only' => true,
];
$records = [];
$assertions = 0;
foreach (['sparse', 'populated'] as $profileKind) {
    $customer = (object) [
        'id' => 'cus_fictional', 'tenant_id' => 'ten_fictional', 'name' => 'Example Member',
        'phone' => '0812345678', 'status' => 'active', 'pin_hash' => '',
        'email' => $profileKind === 'sparse' ? null : 'example@example.test',
        'avatar_url' => $profileKind === 'sparse' ? null : 'https://example.test/avatar.png',
        'preferred_locale' => $profileKind === 'sparse' ? null : 'th-TH',
        'reward_payout_bank_account_json' => $profileKind === 'sparse' ? null : [
            'bank_name' => 'Fictional Bank', 'account_name' => 'Example Member', 'account_number' => '0000000000',
        ],
    ];
    $profileMethod = new ReflectionMethod(CustomerAuthService::class, 'customerProfile');
    $profile = $profileMethod->invoke($auth, $customer, false);
    // The session scalar envelope is traced from issueSession, not issued here.
    $session = [
        'session_id' => 'cas_fictional', 'token' => 'fictional-access-not-issued',
        'refresh_token' => 'fictional-refresh-not-issued', 'expires_in' => 3600,
        'pin_verified' => false, 'session_activation_required' => true,
        'pin_setup_required' => true, 'pin_required' => false, 'user' => $profile,
    ];
    foreach (['google', 'apple', 'facebook', 'line', 'legacy-line'] as $provider) {
        foreach (['session', 'registration'] as $branch) {
            $resource = $branch === 'session' ? $session : ['registration_required' => true];
            $partner = Mockery::mock(PartnerStoreService::class);
            $partner->shouldReceive('tenantContextForRequest')->once()->with(Mockery::type(Request::class), true)
                ->andReturn(['context' => $tenant]);
            $line = Mockery::mock(CustomerLineAuthService::class);
            $social = Mockery::mock(CustomerSocialAuthService::class);
            if (in_array($provider, ['line', 'legacy-line'], true)) {
                $line->shouldReceive('linkPhone')->once()->with($tenant, $requestPayload)
                    ->andReturn(['resource' => $resource, 'status' => 200]);
            } else {
                $social->shouldReceive('linkPhone')->once()->with($tenant, $provider, $requestPayload)
                    ->andReturn(['resource' => $resource, 'status' => 200]);
            }
            $sessions = Mockery::mock(CustomerSessionResolver::class);
            $request = Request::create('/api/v1/customer/auth/fictional/link-phone', 'POST', $requestPayload);
            if ($provider === 'legacy-line') {
                $controller = new CustomerLineAuthController($partner, $line, $sessions);
                $response = $controller->linkPhone($request);
            } else {
                $controller = new CustomerSocialAuthController(
                    $partner, $social, Mockery::mock(CustomerSocialAccountService::class), $line, $sessions,
                );
                $response = $controller->linkPhone($request, $provider);
            }
            $body = json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR);
            foreach ([$response->getStatusCode() === 200, $body === $resource, !array_key_exists('resource', $body)] as $ok) {
                $assertions++;
                if (!$ok) throw new RuntimeException('Controller top-level response mismatch');
            }
            $records[] = ['provider' => $provider, 'profile' => $profileKind, 'branch' => $branch, 'status' => 200, 'body' => $body];
        }
    }
}
Mockery::close();
file_put_contents('/evidence/controller-responses.json', json_encode($records, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR).PHP_EOL);
echo 'PHP '.PHP_VERSION.PHP_EOL;
echo 'Network disabled; application and vendor mounts read-only; no app bootstrap, DB connection, migration or token issuance.'.PHP_EOL;
echo 'Controller/production-profile serializer cases='.count($records).'; assertions='.$assertions.'; PASS'.PHP_EOL;
