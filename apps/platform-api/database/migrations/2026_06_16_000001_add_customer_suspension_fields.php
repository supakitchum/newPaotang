<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if (! Schema::hasColumn('customers', 'suspended_at')) {
                $table->timestampTz('suspended_at')->nullable();
            }

            if (! Schema::hasColumn('customers', 'suspended_until')) {
                $table->timestampTz('suspended_until')->nullable();
            }

            if (! Schema::hasColumn('customers', 'suspension_reason')) {
                $table->text('suspension_reason')->nullable();
            }

            if (! Schema::hasColumn('customers', 'suspended_by_admin_id')) {
                $table->string('suspended_by_admin_id', 30)->nullable();
            }
        });

        Schema::table('customers', function (Blueprint $table): void {
            if (Schema::hasColumn('customers', 'suspended_until')) {
                $table->index(['tenant_id', 'status', 'suspended_until'], 'customers_tenant_status_suspended_until_idx');
            }
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if (Schema::hasColumn('customers', 'suspended_until')) {
                $table->dropIndex('customers_tenant_status_suspended_until_idx');
            }
        });

        Schema::table('customers', function (Blueprint $table): void {
            foreach (['suspended_by_admin_id', 'suspension_reason', 'suspended_until', 'suspended_at'] as $column) {
                if (Schema::hasColumn('customers', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
