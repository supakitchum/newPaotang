<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const UNIQUE_NAME = 'reward_claims_tenant_id_winning_ticket_id_unique';
    private const INDEX_NAME = 'reward_claims_tenant_winning_ticket_idx';

    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE reward_claims DROP CONSTRAINT IF EXISTS '.self::UNIQUE_NAME);
            DB::statement('DROP INDEX IF EXISTS '.self::UNIQUE_NAME);
            DB::statement('CREATE INDEX IF NOT EXISTS '.self::INDEX_NAME.' ON reward_claims (tenant_id, winning_ticket_id)');

            return;
        }

        Schema::table('reward_claims', function (Blueprint $table): void {
            $table->dropUnique(self::UNIQUE_NAME);
            $table->index(['tenant_id', 'winning_ticket_id'], self::INDEX_NAME);
        });
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('DROP INDEX IF EXISTS '.self::INDEX_NAME);
            DB::statement(<<<'SQL'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'reward_claims_tenant_id_winning_ticket_id_unique'
            AND conrelid = 'reward_claims'::regclass
    ) THEN
        ALTER TABLE reward_claims
            ADD CONSTRAINT reward_claims_tenant_id_winning_ticket_id_unique UNIQUE (tenant_id, winning_ticket_id);
    END IF;
END
$$
SQL);

            return;
        }

        Schema::table('reward_claims', function (Blueprint $table): void {
            $table->dropIndex(self::INDEX_NAME);
            $table->unique(['tenant_id', 'winning_ticket_id']);
        });
    }
};
