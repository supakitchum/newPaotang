<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (
            Schema::hasTable('tenant_payment_provider_connections')
            && ! Schema::hasColumn('tenant_payment_provider_connections', 'webhook_secret_encrypted')
        ) {
            Schema::table('tenant_payment_provider_connections', function (Blueprint $table): void {
                $table->text('webhook_secret_encrypted')->nullable();
            });
        }
    }

    public function down(): void
    {
        if (
            Schema::hasTable('tenant_payment_provider_connections')
            && Schema::hasColumn('tenant_payment_provider_connections', 'webhook_secret_encrypted')
        ) {
            Schema::table('tenant_payment_provider_connections', function (Blueprint $table): void {
                $table->dropColumn('webhook_secret_encrypted');
            });
        }
    }
};
