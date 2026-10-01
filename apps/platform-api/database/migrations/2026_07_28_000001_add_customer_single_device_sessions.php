<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_auth_sessions', function (Blueprint $table): void {
            $table->boolean('activation_required')->default(false)->after('pin_verified_at');
            $table->timestampTz('activated_at')->nullable()->after('activation_required');
            $table->string('revoked_reason', 64)->nullable()->after('revoked_at');
            $table->string('replaced_by_session_id', 34)->nullable()->after('revoked_reason');

            $table->index(
                ['tenant_id', 'customer_id', 'activation_required', 'revoked_at'],
                'customer_auth_session_activation_index',
            );
            $table->index('revoked_reason', 'customer_auth_session_revoke_reason_index');
            $table->index('replaced_by_session_id', 'customer_auth_session_replacement_index');
        });
    }

    public function down(): void
    {
        Schema::table('customer_auth_sessions', function (Blueprint $table): void {
            $table->dropIndex('customer_auth_session_activation_index');
            $table->dropIndex('customer_auth_session_revoke_reason_index');
            $table->dropIndex('customer_auth_session_replacement_index');
            $table->dropColumn([
                'activation_required',
                'activated_at',
                'revoked_reason',
                'replaced_by_session_id',
            ]);
        });
    }
};
