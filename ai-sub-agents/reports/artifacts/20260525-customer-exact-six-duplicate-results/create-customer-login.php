<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

require '/var/www/html/vendor/autoload.php';

$app = require '/var/www/html/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$now = now();
$tenantId = 'ten_qa_exact6';
$customerId = 'cus_qa_exact6';
$phone = '0806543210';
$password = 'qa-password-654321';

DB::table('customer_auth_sessions')->where('customer_id', $customerId)->delete();
DB::table('wallets')->where('customer_id', $customerId)->delete();
DB::table('customers')->where('id', $customerId)->delete();

DB::table('customers')->insert([
    'id' => $customerId,
    'tenant_id' => $tenantId,
    'customer_no' => 'QAEXACT654321',
    'phone' => $phone,
    'email' => 'qa-exact-six@example.test',
    'password_hash' => Hash::make($password),
    'avatar_url' => null,
    'name' => 'QA Exact Six',
    'first_name' => 'QA',
    'last_name' => 'Exact Six',
    'status' => 'active',
    'last_login_at' => null,
    'created_at' => $now,
    'updated_at' => $now,
]);

echo json_encode([
    'app_env' => app()->environment(),
    'db_database' => DB::connection()->getDatabaseName(),
    'tenant_id' => $tenantId,
    'customer_id' => $customerId,
    'phone' => $phone,
    'role' => 'customer',
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
