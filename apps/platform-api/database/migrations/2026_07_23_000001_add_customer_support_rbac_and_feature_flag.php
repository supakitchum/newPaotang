<?php

use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        (new DefaultRbacMenuSeeder())->run();

        $now = now();
        foreach (DB::table('partner_tenants')->pluck('id') as $tenantId) {
            DB::table('partner_tenant_feature_flags')->insertOrIgnore([
                'id' => 'pff_'.substr(sha1($tenantId.':customer_support'), 0, 20),
                'tenant_id' => $tenantId,
                'feature_key' => 'customer_support',
                'enabled' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        // The migration is intentionally additive; existing role assignments
        // and feature choices must not be removed by a rollback.
    }
};
