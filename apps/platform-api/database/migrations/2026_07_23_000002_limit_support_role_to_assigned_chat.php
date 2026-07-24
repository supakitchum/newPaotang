<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $faqViewPermissionId = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'support_faq.view')
            ->value('id');
        if ($faqViewPermissionId === null) {
            return;
        }

        $supportRoleIds = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->where('code', 'support')
            ->pluck('id');
        if ($supportRoleIds->isEmpty()) {
            return;
        }

        DB::table('role_permissions')
            ->whereIn('role_id', $supportRoleIds)
            ->where('permission_id', $faqViewPermissionId)
            ->delete();
    }

    public function down(): void
    {
        $faqViewPermissionId = DB::table('permissions')
            ->where('scope_type', 'tenant')
            ->where('code', 'support_faq.view')
            ->value('id');
        if ($faqViewPermissionId === null) {
            return;
        }

        $now = now();
        $rows = DB::table('roles')
            ->where('scope_type', 'tenant')
            ->where('code', 'support')
            ->pluck('id')
            ->map(fn (string $roleId): array => [
                'role_id' => $roleId,
                'permission_id' => $faqViewPermissionId,
                'created_at' => $now,
                'updated_at' => $now,
            ])
            ->all();
        if ($rows !== []) {
            DB::table('role_permissions')->insertOrIgnore($rows);
        }
    }
};
