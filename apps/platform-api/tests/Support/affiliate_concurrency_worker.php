<?php

use App\Modules\Growth\Services\AffiliateTierService;
use App\Modules\Growth\Services\GrowthService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\Request;

require dirname(__DIR__, 2).'/vendor/autoload.php';

$application = require dirname(__DIR__, 2).'/bootstrap/app.php';
$application->make(Kernel::class)->bootstrap();

$payload = json_decode(
    base64_decode((string) ($argv[1] ?? ''), true),
    true,
    512,
    JSON_THROW_ON_ERROR,
);
$readyFile = (string) $payload['ready_file'];
$startFile = (string) $payload['start_file'];
touch($readyFile);

while (! is_file($startFile)) {
    usleep(1000);
}

$tenantId = (string) $payload['tenant_id'];
$customerId = (string) $payload['customer_id'];
$request = Request::create('/affiliate-concurrency-worker', 'POST');
$request->headers->set('Idempotency-Key', (string) $payload['idempotency_key']);
$customer = new CustomerSessionContext([
    'tenant_id' => $tenantId,
    'customer_id' => $customerId,
], [
    'id' => $customerId,
]);
$growth = app(GrowthService::class);

$result = match ((string) $payload['action']) {
    'payout' => $growth->createCustomerAffiliatePayout(
        $tenantId,
        $customer,
        [
            'amount' => ['amount' => 70000, 'currency' => 'THB'],
            'payout_method' => 'wallet_credit',
        ],
        $request,
    ),
    'register' => $growth->registerCustomerAffiliate(
        $tenantId,
        $customer,
        ['name' => (string) $payload['name']],
        $request,
    ),
    'campaign' => app(AffiliateTierService::class)->createCampaign(
        $tenantId,
        new AdminSessionContext([
            'scope_type' => 'tenant',
            'scope_id' => $tenantId,
            'tenant_id' => $tenantId,
        ], [
            'id' => (string) $payload['admin_id'],
        ], []),
        [
            'name' => (string) $payload['name'],
            'campaign_type' => 'fixed_threshold',
            'status' => 'scheduled',
            'starts_at' => (string) $payload['starts_at'],
            'ends_at' => (string) $payload['ends_at'],
        ],
        $request,
    ),
    'pay' => $growth->payPayout(
        $tenantId,
        new AdminSessionContext([
            'scope_type' => 'tenant',
            'scope_id' => $tenantId,
            'tenant_id' => $tenantId,
        ], [
            'id' => (string) $payload['admin_id'],
        ], []),
        (string) $payload['payout_id'],
        [
            'payment_reference' => (string) $payload['payment_reference'],
        ],
        $request,
    ),
    default => throw new RuntimeException('Unknown Affiliate concurrency action.'),
};

echo json_encode($result, JSON_THROW_ON_ERROR);
