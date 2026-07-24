<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_notification_recipients', function (Blueprint $table): void {
            $table->index(
                ['tenant_id', 'customer_id', 'id'],
                'customer_notification_customer_cursor_idx',
            );
            $table->index(
                ['tenant_id', 'customer_id', 'read_at', 'id'],
                'customer_notification_unread_cursor_idx',
            );
        });
    }

    public function down(): void
    {
        Schema::table('customer_notification_recipients', function (Blueprint $table): void {
            $table->dropIndex('customer_notification_customer_cursor_idx');
            $table->dropIndex('customer_notification_unread_cursor_idx');
        });
    }
};
