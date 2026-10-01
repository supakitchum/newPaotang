<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            $table->string('lottery_product_label')->nullable()->after('support_url');
            $table->string('ticket_image_watermark')->nullable()->after('lottery_product_label');
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN primary_color SET DEFAULT '#087FF0'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN secondary_color SET DEFAULT '#19B8EF'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN accent_color SET DEFAULT '#FFD10B'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN text_color SET DEFAULT '#242833'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN font_family SET DEFAULT 'Kanit'");
        }

        DB::table('partner_tenant_themes')
            ->where('primary_color', '#0F766E')
            ->where('secondary_color', '#2563EB')
            ->where('accent_color', '#F59E0B')
            ->where('background_color', '#FFFFFF')
            ->where('text_color', '#111827')
            ->where('font_family', 'Inter, sans-serif')
            ->update([
                'primary_color' => '#087FF0',
                'secondary_color' => '#19B8EF',
                'accent_color' => '#FFD10B',
                'text_color' => '#242833',
                'font_family' => 'Kanit',
                'config_version' => DB::raw('config_version + 1'),
                'updated_at' => now(),
            ]);
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN primary_color SET DEFAULT '#0F766E'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN secondary_color SET DEFAULT '#2563EB'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN accent_color SET DEFAULT '#F59E0B'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN text_color SET DEFAULT '#111827'");
            DB::statement("ALTER TABLE partner_tenant_themes ALTER COLUMN font_family SET DEFAULT 'Inter, sans-serif'");
        }

        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            $table->dropColumn(['lottery_product_label', 'ticket_image_watermark']);
        });
    }
};
