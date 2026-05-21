<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $duplicates = DB::table('partner_tenants')
            ->select('partner_id', DB::raw('COUNT(*) as tenant_count'))
            ->groupBy('partner_id')
            ->havingRaw('COUNT(*) > 1')
            ->orderBy('partner_id')
            ->get()
            ->map(fn (object $row): string => $row->partner_id.' ('.$row->tenant_count.')')
            ->all();

        if ($duplicates !== []) {
            throw new RuntimeException(
                'Cannot enforce 1 Partner = 1 Tenant because duplicate partner_tenants.partner_id values exist: '
                .implode(', ', $duplicates),
            );
        }

        Schema::table('partner_tenants', function (Blueprint $table): void {
            $table->unique('partner_id', 'partner_tenants_partner_id_unique');
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenants', function (Blueprint $table): void {
            $table->dropUnique('partner_tenants_partner_id_unique');
        });
    }
};
