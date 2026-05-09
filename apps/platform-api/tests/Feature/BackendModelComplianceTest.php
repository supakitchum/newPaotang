<?php

namespace Tests\Feature;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use ReflectionClass;
use Tests\TestCase;

class BackendModelComplianceTest extends TestCase
{
    use RefreshDatabase;

    public function test_All_application_tables_have_concrete_eloquent_models(): void
    {
        $migrationTables = $this->domainMigrationTables();
        $modelTables = [];

        foreach ($this->concreteModelClasses() as $class) {
            $model = new $class();

            $this->assertFalse($model->getIncrementing(), $class.' must use string primary keys.');
            $this->assertSame('string', $model->getKeyType(), $class.' must declare string keys.');

            $modelTables[] = $model->getTable();
        }

        sort($modelTables);

        $this->assertSame([], array_values(array_diff($migrationTables, $modelTables)), 'Every application table must have an Eloquent model.');
        $this->assertContains('admin_permission_cache_versions', $modelTables);
        $this->assertContains('admin_user_roles', $modelTables);
        $this->assertContains('role_menus', $modelTables);
        $this->assertContains('role_permissions', $modelTables);
    }

    public function test_Concrete_models_define_explicit_fillable_and_base_models_do_not_unguard_globally(): void
    {
        foreach ($this->concreteModelClasses() as $class) {
            $reflection = new ReflectionClass($class);

            $this->assertTrue($reflection->hasProperty('fillable'), $class.' must declare $fillable.');

            $property = $reflection->getProperty('fillable');
            $this->assertSame($class, $property->getDeclaringClass()->getName(), $class.' must declare its own $fillable, not inherit one.');
            $this->assertNotEmpty((new $class())->getFillable(), $class.' must expose at least one fillable column.');
        }

        foreach ([app_path('Models/BaseModel.php'), app_path('Models/BasePivotModel.php')] as $path) {
            $contents = (string) file_get_contents($path);

            $this->assertStringNotContainsString('protected $guarded = []', $contents, $path.' must not globally unguard models.');
        }
    }

    public function test_App_source_has_no_direct_table_query_builder_or_raw_table_shortcuts(): void
    {
        foreach ($this->phpFiles(app_path()) as $file) {
            $contents = (string) file_get_contents($file->getPathname());
            $message = $file->getPathname().' must use Eloquent model query builders.';

            $this->assertStringNotContainsString('DB::table(', $contents, $message);
            $this->assertStringNotContainsString('DB::raw(', $contents, $message);
            $this->assertStringNotContainsString('->from(', $contents, $message);
        }
    }

    public function test_App_source_uses_imported_model_classes_instead_of_fully_qualified_model_calls(): void
    {
        foreach ($this->phpFiles(app_path()) as $file) {
            $contents = (string) file_get_contents($file->getPathname());
            $message = $file->getPathname().' must import App\\Models classes and use short class names.';

            $this->assertDoesNotMatchRegularExpression('/\\\\App\\\\Models\\\\[A-Za-z_][A-Za-z0-9_]*/', $contents, $message);
        }
    }

    public function test_Representative_services_use_model_query_builders_for_backend_paths(): void
    {
        $expectations = [
            'app/Providers/AppServiceProvider.php' => [
                'Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());',
            ],
            'app/Modules/Commerce/Services/CommerceService.php' => [
                'Order::query()->forTenant($tenantId)',
                'Wallet::query()->forTenant($tenantId)',
                'WalletLedger::query()',
                'SyncOutbox::query()',
            ],
            'app/Modules/Growth/Services/GrowthService.php' => [
                'Agent::query()->forTenant($tenantId)',
                'AffiliateAccount::query()->forTenant($tenantId)',
                'CommissionTransaction::query()',
                'WalletLedger::query()',
            ],
            'app/Modules/Partner/Services/PartnerProvisioningService.php' => [
                'AdminPermissionCacheVersion::query()',
                'AdminUserRole::query()',
                'RoleMenu::query()',
                'RolePermission::query()',
            ],
            'app/Modules/PartnerStore/Services/PartnerStoreService.php' => [
                'LocalStockItem::query()',
                'StockReservation::query()',
                'SyncOutbox::query()',
            ],
            'app/Modules/Rbac/Services/AdminUserManagementService.php' => [
                'AdminPermissionCacheVersion::query()',
                'AdminUserRole::query()',
                'RolePermission::query()',
            ],
            'app/Modules/Rbac/Services/MenuManagementService.php' => [
                'AdminUserRole::query()',
                'RoleMenu::query()',
            ],
            'app/Modules/Rbac/Services/RoleManagementService.php' => [
                'AdminPermissionCacheVersion::query()',
                'AdminUserRole::query()',
                'RolePermission::query()',
            ],
        ];

        foreach ($expectations as $path => $needles) {
            $contents = (string) file_get_contents(base_path($path));

            foreach ($needles as $needle) {
                $this->assertStringContainsString($needle, $contents, $path.' should use '.$needle);
            }
        }
    }

    public function test_Model_layer_represents_core_relationships_and_casts(): void
    {
        $relationships = [
            [\App\Models\AdminUserRole::class, 'adminUser'],
            [\App\Models\AdminUserRole::class, 'role'],
            [\App\Models\PartnerTenant::class, 'partner'],
            [\App\Models\PartnerTenant::class, 'domains'],
            [\App\Models\Order::class, 'items'],
            [\App\Models\Order::class, 'tickets'],
            [\App\Models\RoleMenu::class, 'role'],
            [\App\Models\RolePermission::class, 'permission'],
            [\App\Models\Ticket::class, 'winningTickets'],
            [\App\Models\Wallet::class, 'ledgerEntries'],
            [\App\Models\RewardResult::class, 'prizes'],
            [\App\Models\WinningTicket::class, 'rewardPrize'],
            [\App\Models\AffiliateAccount::class, 'links'],
            [\App\Models\AffiliateLink::class, 'attributions'],
            [\App\Models\CommissionTransaction::class, 'affiliateAccount'],
            [\App\Models\CommissionTransaction::class, 'commissionRule'],
            [\App\Models\AffiliatePayout::class, 'affiliateAccount'],
            [\App\Models\PartnerSettlement::class, 'tenant'],
        ];

        foreach ($relationships as [$class, $method]) {
            $this->assertInstanceOf(Relation::class, (new $class())->{$method}(), $class.'::'.$method);
        }

        $this->assertSame('boolean', (new \App\Models\PartnerTenantDomain())->getCasts()['is_primary'] ?? null);
        $this->assertSame('array', (new \App\Models\Game())->getCasts()['metadata_json'] ?? null);
        $this->assertSame('integer', (new \App\Models\Wallet())->getCasts()['balance_amount'] ?? null);
        $this->assertSame('array', (new \App\Models\WalletLedger())->getCasts()['metadata_json'] ?? null);
        $this->assertSame('array', (new \App\Models\RewardResult())->getCasts()['summary_json'] ?? null);
        $this->assertSame('array', (new \App\Models\AffiliateAccount())->getCasts()['payout_profile_json'] ?? null);
        $this->assertSame('array', (new \App\Models\ReportExportJob())->getCasts()['filters_json'] ?? null);
    }

    public function test_Growth_dynamic_table_helpers_resolve_to_model_query_builders(): void
    {
        $contents = (string) file_get_contents(base_path('app/Modules/Growth/Services/GrowthService.php'));

        foreach ([
            "'affiliate_accounts' => AffiliateAccount::query()",
            "'affiliate_attributions' => AffiliateAttribution::query()",
            "'affiliate_links' => AffiliateLink::query()",
            "'affiliate_payouts' => AffiliatePayout::query()",
            "'affiliate_programs' => AffiliateProgram::query()",
            "'agents' => Agent::query()",
            "'commission_rules' => CommissionRule::query()",
            "'commission_transactions' => CommissionTransaction::query()",
            "'orders' => Order::query()",
            "'wallet_ledger' => WalletLedger::query()",
        ] as $needle) {
            $this->assertStringContainsString($needle, $contents);
        }
    }

    /**
     * @return array<int, class-string<Model>>
     */
    private function concreteModelClasses(): array
    {
        $classes = [];

        foreach ($this->phpFiles(app_path('Models')) as $file) {
            $path = $file->getPathname();

            if (str_contains($path, DIRECTORY_SEPARATOR.'Concerns'.DIRECTORY_SEPARATOR)) {
                continue;
            }

            $relativePath = substr($path, strlen(app_path('Models')) + 1, -4);
            $class = 'App\\Models\\'.str_replace(DIRECTORY_SEPARATOR, '\\', $relativePath);

            if (! class_exists($class)) {
                continue;
            }

            $reflection = new ReflectionClass($class);

            if ($reflection->isAbstract() || ! $reflection->isSubclassOf(Model::class)) {
                continue;
            }

            $classes[] = $class;
        }

        sort($classes);

        return $classes;
    }

    /**
     * @return array<int, string>
     */
    private function domainMigrationTables(): array
    {
        $runtimeTables = ['cache', 'cache_locks', 'failed_jobs', 'jobs'];
        $tables = [];

        foreach ($this->phpFiles(database_path('migrations')) as $file) {
            $contents = (string) file_get_contents($file->getPathname());

            preg_match_all("/Schema::(?:create|table)\\('([^']+)'/", $contents, $matches);

            foreach ($matches[1] ?? [] as $table) {
                if (! in_array($table, $runtimeTables, true)) {
                    $tables[] = $table;
                }
            }
        }

        $tables = array_values(array_unique($tables));
        sort($tables);

        return $tables;
    }

    /**
     * @return \Generator<int, \SplFileInfo>
     */
    private function phpFiles(string $path): \Generator
    {
        $directory = new \RecursiveDirectoryIterator($path);
        $files = new \RecursiveIteratorIterator($directory);

        foreach ($files as $file) {
            if ($file instanceof \SplFileInfo && $file->getExtension() === 'php') {
                yield $file;
            }
        }
    }
}
