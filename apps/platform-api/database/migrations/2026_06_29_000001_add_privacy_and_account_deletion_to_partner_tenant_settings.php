<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (! Schema::hasColumn('partner_tenant_settings', 'privacy_content')) {
                $table->text('privacy_content')->nullable()->after('terms_content_i18n');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'privacy_content_i18n')) {
                $table->json('privacy_content_i18n')->nullable()->after('privacy_content');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'privacy_policy_url')) {
                $table->string('privacy_policy_url', 2048)->nullable()->after('privacy_content_i18n');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'account_deletion_url')) {
                $table->string('account_deletion_url', 2048)->nullable()->after('privacy_policy_url');
            }
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            foreach (['account_deletion_url', 'privacy_policy_url', 'privacy_content_i18n', 'privacy_content'] as $column) {
                if (Schema::hasColumn('partner_tenant_settings', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
