<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $customerColumns = [
            'pin_hash',
            'pin_set_at',
            'pin_changed_at',
            'pin_failed_attempts',
            'pin_locked_until',
            'pin_last_verified_at',
        ];

        if ($this->missingAnyColumn('customers', $customerColumns)) {
            Schema::table('customers', function (Blueprint $table): void {
                if (! Schema::hasColumn('customers', 'pin_hash')) {
                    $table->string('pin_hash')->nullable()->after(Schema::hasColumn('customers', 'password_hash') ? 'password_hash' : 'status');
                }

                if (! Schema::hasColumn('customers', 'pin_set_at')) {
                    $table->timestampTz('pin_set_at')->nullable()->after('pin_hash');
                }

                if (! Schema::hasColumn('customers', 'pin_changed_at')) {
                    $table->timestampTz('pin_changed_at')->nullable()->after('pin_set_at');
                }

                if (! Schema::hasColumn('customers', 'pin_failed_attempts')) {
                    $table->unsignedTinyInteger('pin_failed_attempts')->default(0)->after('pin_changed_at');
                }

                if (! Schema::hasColumn('customers', 'pin_locked_until')) {
                    $table->timestampTz('pin_locked_until')->nullable()->after('pin_failed_attempts');
                }

                if (! Schema::hasColumn('customers', 'pin_last_verified_at')) {
                    $table->timestampTz('pin_last_verified_at')->nullable()->after('pin_locked_until');
                }
            });
        }

        if (! Schema::hasColumn('customer_auth_sessions', 'pin_verified_at')) {
            Schema::table('customer_auth_sessions', function (Blueprint $table): void {
                $table->timestampTz('pin_verified_at')->nullable()->after('last_used_at');
            });
        }
    }

    public function down(): void
    {
        $sessionColumns = array_values(array_filter(
            ['pin_verified_at'],
            fn (string $column): bool => Schema::hasColumn('customer_auth_sessions', $column),
        ));

        if ($sessionColumns !== []) {
            Schema::table('customer_auth_sessions', function (Blueprint $table) use ($sessionColumns): void {
                $table->dropColumn($sessionColumns);
            });
        }

        $customerColumns = array_values(array_filter(
            ['pin_hash', 'pin_set_at', 'pin_changed_at', 'pin_failed_attempts', 'pin_locked_until', 'pin_last_verified_at'],
            fn (string $column): bool => Schema::hasColumn('customers', $column),
        ));

        if ($customerColumns !== []) {
            Schema::table('customers', function (Blueprint $table) use ($customerColumns): void {
                $table->dropColumn($customerColumns);
            });
        }
    }

    /**
     * @param array<int, string> $columns
     */
    private function missingAnyColumn(string $table, array $columns): bool
    {
        foreach ($columns as $column) {
            if (! Schema::hasColumn($table, $column)) {
                return true;
            }
        }

        return false;
    }
};
