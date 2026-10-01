<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if (! Schema::hasColumn('customers', 'preferred_locale')) {
                $table->string('preferred_locale', 12)->nullable()->after('status');
            }
        });

        Schema::table('admin_users', function (Blueprint $table): void {
            if (! Schema::hasColumn('admin_users', 'preferred_locale')) {
                $table->string('preferred_locale', 12)->nullable()->after('status');
            }
        });

        Schema::table('tenant_announcements', function (Blueprint $table): void {
            if (! Schema::hasColumn('tenant_announcements', 'title_i18n')) {
                $table->json('title_i18n')->nullable()->after('title');
            }

            if (! Schema::hasColumn('tenant_announcements', 'summary_i18n')) {
                $table->json('summary_i18n')->nullable()->after('summary');
            }

            if (! Schema::hasColumn('tenant_announcements', 'body_i18n')) {
                $table->json('body_i18n')->nullable()->after('body');
            }
        });

        Schema::table('tenant_activities', function (Blueprint $table): void {
            if (! Schema::hasColumn('tenant_activities', 'name_i18n')) {
                $table->json('name_i18n')->nullable()->after('name');
            }
        });

        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (! Schema::hasColumn('partner_tenant_settings', 'site_name_i18n')) {
                $table->json('site_name_i18n')->nullable()->after('site_name');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'display_name_i18n')) {
                $table->json('display_name_i18n')->nullable()->after('display_name');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'maintenance_message_i18n')) {
                $table->json('maintenance_message_i18n')->nullable()->after('maintenance_message');
            }

            if (! Schema::hasColumn('partner_tenant_settings', 'terms_content_i18n')) {
                $table->json('terms_content_i18n')->nullable()->after('terms_content');
            }
        });

        Schema::table('partner_tenant_maintenance_settings', function (Blueprint $table): void {
            if (! Schema::hasColumn('partner_tenant_maintenance_settings', 'message_i18n')) {
                $table->json('message_i18n')->nullable()->after('message');
            }
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            foreach (['terms_content_i18n', 'maintenance_message_i18n', 'display_name_i18n', 'site_name_i18n'] as $column) {
                if (Schema::hasColumn('partner_tenant_settings', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        Schema::table('partner_tenant_maintenance_settings', function (Blueprint $table): void {
            if (Schema::hasColumn('partner_tenant_maintenance_settings', 'message_i18n')) {
                $table->dropColumn('message_i18n');
            }
        });

        Schema::table('tenant_activities', function (Blueprint $table): void {
            if (Schema::hasColumn('tenant_activities', 'name_i18n')) {
                $table->dropColumn('name_i18n');
            }
        });

        Schema::table('tenant_announcements', function (Blueprint $table): void {
            foreach (['body_i18n', 'summary_i18n', 'title_i18n'] as $column) {
                if (Schema::hasColumn('tenant_announcements', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        Schema::table('admin_users', function (Blueprint $table): void {
            if (Schema::hasColumn('admin_users', 'preferred_locale')) {
                $table->dropColumn('preferred_locale');
            }
        });

        Schema::table('customers', function (Blueprint $table): void {
            if (Schema::hasColumn('customers', 'preferred_locale')) {
                $table->dropColumn('preferred_locale');
            }
        });
    }
};
