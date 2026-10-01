<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_push_devices', function (Blueprint $table): void {
            $table->index(['revoked_at', 'last_seen_at'], 'customer_push_device_stale_idx');
        });
    }

    public function down(): void
    {
        Schema::table('customer_push_devices', function (Blueprint $table): void {
            $table->dropIndex('customer_push_device_stale_idx');
        });
    }
};
