<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_push_devices', function (Blueprint $table): void {
            $table->dropForeign(['customer_id']);
            $table->string('customer_id', 30)->nullable()->change();
            $table->string('installation_secret_hash', 64)->nullable()->after('installation_id');
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->index(
                ['tenant_id', 'customer_id', 'revoked_at', 'last_seen_at'],
                'customer_push_audience_idx',
            );
        });

        Schema::table('customer_notification_deliveries', function (Blueprint $table): void {
            $table->dropForeign(['recipient_id']);
            $table->string('recipient_id', 30)->nullable()->change();
            $table->string('notification_id', 30)->nullable()->after('tenant_id');
            $table->foreign('recipient_id')->references('id')->on('customer_notification_recipients')->nullOnDelete();
            $table->foreign('notification_id')->references('id')->on('customer_notifications')->cascadeOnDelete();
        });

        DB::table('customer_notification_deliveries')
            ->whereNull('notification_id')
            ->orderBy('id')
            ->chunkById(500, function ($deliveries): void {
                $recipientIds = $deliveries->pluck('recipient_id')->filter()->unique()->values()->all();
                $notificationIds = DB::table('customer_notification_recipients')
                    ->whereIn('id', $recipientIds)
                    ->pluck('notification_id', 'id');

                foreach ($deliveries as $delivery) {
                    $notificationId = $notificationIds->get($delivery->recipient_id);
                    if ($notificationId !== null) {
                        DB::table('customer_notification_deliveries')
                            ->where('id', $delivery->id)
                            ->update(['notification_id' => $notificationId]);
                    }
                }
            });

        Schema::table('customer_notification_deliveries', function (Blueprint $table): void {
            $table->string('notification_id', 30)->nullable(false)->change();
            $table->unique(
                ['notification_id', 'device_id'],
                'customer_notification_device_delivery_unique',
            );
            $table->index(
                ['tenant_id', 'notification_id', 'status'],
                'customer_notification_delivery_stats_idx',
            );
        });
    }

    public function down(): void
    {
        DB::table('customer_notification_deliveries')->whereNull('recipient_id')->delete();
        DB::table('customer_push_devices')->whereNull('customer_id')->delete();

        Schema::table('customer_notification_deliveries', function (Blueprint $table): void {
            $table->dropUnique('customer_notification_device_delivery_unique');
            $table->dropIndex('customer_notification_delivery_stats_idx');
            $table->dropForeign(['notification_id']);
            $table->dropForeign(['recipient_id']);
            $table->dropColumn('notification_id');
            $table->string('recipient_id', 30)->nullable(false)->change();
            $table->foreign('recipient_id')->references('id')->on('customer_notification_recipients')->cascadeOnDelete();
        });

        Schema::table('customer_push_devices', function (Blueprint $table): void {
            $table->dropIndex('customer_push_audience_idx');
            $table->dropForeign(['customer_id']);
            $table->dropColumn('installation_secret_hash');
            $table->string('customer_id', 30)->nullable(false)->change();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
        });
    }
};
