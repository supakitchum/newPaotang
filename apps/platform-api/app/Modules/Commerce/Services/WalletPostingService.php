<?php

namespace App\Modules\Commerce\Services;

use App\Models\Wallet;
use App\Models\WalletLedger;
use App\Modules\Commerce\Events\CustomerWalletUpdated;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class WalletPostingService
{
    /**
     * @param array<string, mixed> $metadata
     * @return array{id: string, wallet_id: string, balance_after: int}
     */
    public function post(
        string $tenantId,
        string $walletId,
        string $customerId,
        string $entryType,
        int $amount,
        string $referenceType,
        string $referenceId,
        string $idempotencyKey,
        ?string $adminId = null,
        array $metadata = [],
    ): array {
        $allowedEntryTypes = ['credit', 'debit', 'hold', 'release', 'reversal', 'adjustment'];
        if (
            ! in_array($entryType, $allowedEntryTypes, true)
            || $amount === 0
            || ($entryType !== 'adjustment' && $amount < 0)
            || trim($idempotencyKey) === ''
        ) {
            throw new RuntimeException('wallet_ledger_invalid_post');
        }

        return DB::transaction(function () use (
            $tenantId,
            $walletId,
            $customerId,
            $entryType,
            $amount,
            $referenceType,
            $referenceId,
            $idempotencyKey,
            $adminId,
            $metadata,
        ): array {
            $wallet = Wallet::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $walletId)
                ->where('customer_id', $customerId)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();
            if ($wallet === null) {
                throw new RuntimeException('wallet_not_available');
            }

            $signedAmount = in_array($entryType, ['debit', 'hold'], true)
                ? -abs($amount)
                : $amount;
            $existing = WalletLedger::query()
                ->where('tenant_id', $tenantId)
                ->where('wallet_id', $walletId)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existing !== null) {
                if (
                    (string) $existing->customer_id !== $customerId
                    || (string) $existing->entry_type !== $entryType
                    || (int) $existing->amount !== $signedAmount
                    || (string) $existing->reference_type !== $referenceType
                    || (string) $existing->reference_id !== $referenceId
                ) {
                    throw new RuntimeException('wallet_ledger_idempotency_conflict');
                }

                return [
                    'id' => (string) $existing->id,
                    'wallet_id' => (string) $existing->wallet_id,
                    'balance_after' => (int) $existing->balance_after,
                ];
            }

            $balanceAfter = (int) $wallet->balance_amount + $signedAmount;
            if ($balanceAfter < 0) {
                throw new RuntimeException('wallet_insufficient_balance');
            }
            $ledgerId = 'wle_'.Str::ulid()->toBase32();
            $now = now();

            WalletLedger::query()->insert([
                'id' => $ledgerId,
                'tenant_id' => $tenantId,
                'wallet_id' => $walletId,
                'customer_id' => $customerId,
                'entry_type' => $entryType,
                'status' => 'posted',
                'amount' => $signedAmount,
                'currency' => (string) $wallet->currency,
                'balance_after' => $balanceAfter,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'idempotency_key' => $idempotencyKey,
                'created_by_admin_id' => $adminId,
                'metadata_json' => $metadata === [] ? null : json_encode($metadata, JSON_THROW_ON_ERROR),
                'posted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            Wallet::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $walletId)
                ->update([
                    'balance_amount' => $balanceAfter,
                    'updated_at' => $now,
                ]);

            DB::afterCommit(static fn () => CustomerWalletUpdated::dispatch([
                'event_type' => 'wallet.updated',
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'wallet_id' => $walletId,
                'ledger_id' => $ledgerId,
                'entry_type' => $entryType,
                'amount' => $signedAmount,
                'currency' => (string) $wallet->currency,
                'posted_balance' => $balanceAfter,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'updated_at' => $now->toISOString(),
            ]));

            return [
                'id' => $ledgerId,
                'wallet_id' => $walletId,
                'balance_after' => $balanceAfter,
            ];
        });
    }
}
