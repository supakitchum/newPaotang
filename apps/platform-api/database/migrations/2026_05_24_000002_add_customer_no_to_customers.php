<?php

use App\Support\CustomerNo;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('customers', 'customer_no')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->string('customer_no', 64)->nullable()->after('tenant_id');
            });
        }

        $tenantCodes = DB::table('partner_tenants')->pluck('code', 'id')->all();

        DB::table('customers')
            ->whereNull('customer_no')
            ->orderBy('id')
            ->chunkById(500, function ($customers) use ($tenantCodes): void {
                foreach ($customers as $customer) {
                    $customerNo = $this->newCustomerNo((string) $customer->tenant_id, $tenantCodes[(string) $customer->tenant_id] ?? null);

                    DB::table('customers')
                        ->where('id', $customer->id)
                        ->update([
                            'customer_no' => $customerNo,
                            'updated_at' => $customer->updated_at,
                        ]);
                }
            }, 'id');

        Schema::table('customers', function (Blueprint $table): void {
            if (! $this->indexExists('customers', 'customers_customer_no_unique')) {
                $table->unique('customer_no', 'customers_customer_no_unique');
            }

            if (! $this->indexExists('customers', 'customers_tenant_customer_no_index')) {
                $table->index(['tenant_id', 'customer_no'], 'customers_tenant_customer_no_index');
            }
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if ($this->indexExists('customers', 'customers_tenant_customer_no_index')) {
                $table->dropIndex('customers_tenant_customer_no_index');
            }

            if ($this->indexExists('customers', 'customers_customer_no_unique')) {
                $table->dropUnique('customers_customer_no_unique');
            }
        });

        if (Schema::hasColumn('customers', 'customer_no')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->dropColumn('customer_no');
            });
        }
    }

    private function newCustomerNo(string $tenantId, ?string $tenantCode): string
    {
        do {
            $customerNo = CustomerNo::generate($tenantCode, $tenantId);
        } while (DB::table('customers')->where('customer_no', $customerNo)->exists());

        return $customerNo;
    }

    private function indexExists(string $table, string $indexName): bool
    {
        return collect(Schema::getIndexes($table))->contains(fn (array $index): bool => ($index['name'] ?? null) === $indexName);
    }
};
