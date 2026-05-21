<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $needsCustomerColumns = ! Schema::hasColumn('customers', 'first_name')
            || ! Schema::hasColumn('customers', 'last_name');

        if ($needsCustomerColumns) {
            Schema::table('customers', function (Blueprint $table): void {
                if (! Schema::hasColumn('customers', 'first_name')) {
                    $table->string('first_name')->nullable()->after('name');
                }

                if (! Schema::hasColumn('customers', 'last_name')) {
                    $table->string('last_name')->nullable()->after('first_name');
                }
            });
        }

        $needsReservationColumns = ! Schema::hasColumn('stock_reservation_items', 'price_amount')
            || ! Schema::hasColumn('stock_reservation_items', 'currency')
            || ! Schema::hasColumn('stock_reservation_items', 'sale_price_rule_snapshot_json');

        if ($needsReservationColumns) {
            Schema::table('stock_reservation_items', function (Blueprint $table): void {
                if (! Schema::hasColumn('stock_reservation_items', 'price_amount')) {
                    $table->unsignedBigInteger('price_amount')->nullable()->after('status');
                }

                if (! Schema::hasColumn('stock_reservation_items', 'currency')) {
                    $table->string('currency', 3)->nullable()->after('price_amount');
                }

                if (! Schema::hasColumn('stock_reservation_items', 'sale_price_rule_snapshot_json')) {
                    $table->json('sale_price_rule_snapshot_json')->nullable()->after('currency');
                }
            });
        }
    }

    public function down(): void
    {
        $reservationColumns = array_values(array_filter(
            ['price_amount', 'currency', 'sale_price_rule_snapshot_json'],
            fn (string $column): bool => Schema::hasColumn('stock_reservation_items', $column),
        ));

        if ($reservationColumns !== []) {
            Schema::table('stock_reservation_items', function (Blueprint $table) use ($reservationColumns): void {
                $table->dropColumn($reservationColumns);
            });
        }

        $customerColumns = array_values(array_filter(
            ['first_name', 'last_name'],
            fn (string $column): bool => Schema::hasColumn('customers', $column),
        ));

        if ($customerColumns !== []) {
            Schema::table('customers', function (Blueprint $table) use ($customerColumns): void {
                $table->dropColumn($customerColumns);
            });
        }
    }
};
