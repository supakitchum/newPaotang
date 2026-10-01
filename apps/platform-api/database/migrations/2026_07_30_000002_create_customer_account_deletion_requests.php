<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->timestampTz('deleted_at')->nullable()->after('status');
            $table->timestampTz('phone_reuse_after')->nullable()->after('deleted_at');
        });
        Schema::table('customer_social_identities', function (Blueprint $table): void {
            $table->timestampTz('revoked_at')->nullable()->after('last_login_at');
        });
        Schema::table('customer_line_identities', function (Blueprint $table): void {
            $table->timestampTz('revoked_at')->nullable()->after('last_login_at');
        });

        Schema::create('customer_account_deletion_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('status', 24)->default('pending');
            $table->string('reason_code', 40);
            $table->text('reason_detail')->nullable();
            $table->string('idempotency_key', 128);
            $table->string('payload_hash', 64);
            $table->timestampTz('pin_verified_at');
            $table->timestampTz('otp_verified_at');
            $table->timestampTz('requested_at');
            $table->timestampTz('scheduled_for');
            $table->timestampTz('last_checked_at')->nullable();
            $table->timestampTz('reminder_sent_at')->nullable();
            $table->timestampTz('blocked_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->json('blockers_json')->nullable();
            $table->text('identity_snapshot_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'idempotency_key'], 'customer_deletion_idempotency_unique');
            $table->index(['status', 'scheduled_for'], 'customer_deletion_due_index');
            $table->index(['tenant_id', 'customer_id', 'status'], 'customer_deletion_customer_status_index');
        });

        DB::statement(
            "CREATE UNIQUE INDEX customer_deletion_open_unique
             ON customer_account_deletion_requests (tenant_id, customer_id)
             WHERE status IN ('pending', 'blocked')"
        );

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropUnique('customers_tenant_id_phone_unique');
        });
        DB::statement(
            "CREATE UNIQUE INDEX customers_tenant_phone_active_unique
             ON customers (tenant_id, phone)
             WHERE phone IS NOT NULL AND status <> 'deleted'"
        );

        Schema::table('customer_social_identities', function (Blueprint $table): void {
            $table->dropUnique('customer_social_provider_user_unique');
            $table->dropUnique('customer_social_customer_provider_unique');
        });
        DB::statement(
            'CREATE UNIQUE INDEX customer_social_provider_user_active_unique
             ON customer_social_identities (tenant_id, provider, provider_user_id)
             WHERE revoked_at IS NULL'
        );
        DB::statement(
            'CREATE UNIQUE INDEX customer_social_customer_provider_active_unique
             ON customer_social_identities (tenant_id, customer_id, provider)
             WHERE revoked_at IS NULL'
        );

        Schema::table('customer_line_identities', function (Blueprint $table): void {
            $table->dropUnique('customer_line_identities_tenant_id_customer_id_unique');
            $table->dropUnique('customer_line_identities_tenant_id_line_user_id_unique');
        });
        DB::statement(
            'CREATE UNIQUE INDEX customer_line_customer_active_unique
             ON customer_line_identities (tenant_id, customer_id)
             WHERE revoked_at IS NULL'
        );
        DB::statement(
            'CREATE UNIQUE INDEX customer_line_user_active_unique
             ON customer_line_identities (tenant_id, line_user_id)
             WHERE revoked_at IS NULL'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS customer_line_user_active_unique');
        DB::statement('DROP INDEX IF EXISTS customer_line_customer_active_unique');
        Schema::table('customer_line_identities', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'customer_id']);
            $table->unique(['tenant_id', 'line_user_id']);
        });

        DB::statement('DROP INDEX IF EXISTS customer_social_customer_provider_active_unique');
        DB::statement('DROP INDEX IF EXISTS customer_social_provider_user_active_unique');
        Schema::table('customer_social_identities', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'provider', 'provider_user_id'], 'customer_social_provider_user_unique');
            $table->unique(['tenant_id', 'customer_id', 'provider'], 'customer_social_customer_provider_unique');
        });

        DB::statement('DROP INDEX IF EXISTS customers_tenant_phone_active_unique');
        Schema::table('customers', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'phone']);
        });

        DB::statement('DROP INDEX IF EXISTS customer_deletion_open_unique');
        Schema::dropIfExists('customer_account_deletion_requests');

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropColumn(['deleted_at', 'phone_reuse_after']);
        });
        Schema::table('customer_social_identities', function (Blueprint $table): void {
            $table->dropColumn('revoked_at');
        });
        Schema::table('customer_line_identities', function (Blueprint $table): void {
            $table->dropColumn('revoked_at');
        });
    }
};
