<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('topup_requests', function (Blueprint $table): void {
            $table->timestampTz('payment_expires_at')->nullable()->after('transfer_at');
            $table->index(['status', 'payment_expires_at'], 'topup_payment_expiry_index');
        });
    }

    public function down(): void
    {
        Schema::table('topup_requests', function (Blueprint $table): void {
            $table->dropIndex('topup_payment_expiry_index');
            $table->dropColumn('payment_expires_at');
        });
    }
};
