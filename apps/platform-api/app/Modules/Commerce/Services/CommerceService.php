<?php

namespace App\Modules\Commerce\Services;

use App\Jobs\GenerateSoldTicketImageJob;
use App\Models\Customer;
use App\Models\LocalStockItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\PartnerTenant;
use App\Models\Payment;
use App\Models\StockItem;
use App\Models\StockReservation;
use App\Models\StockReservationItem;
use App\Models\SyncInbox;
use App\Models\SyncOutbox;
use App\Models\TenantPaymentSetting;
use App\Models\Ticket;
use App\Models\TopupRequest;
use App\Models\Wallet;
use App\Models\WalletLedger;
use App\Models\WebhookCallback;
use App\Modules\Commerce\Events\CustomerTopupUpdated;
use App\Modules\Commerce\Events\TopupUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Growth\Services\GrowthService;
use App\Modules\PartnerStore\Services\VirtualLotteryImageService;
use App\Modules\PartnerStore\Services\VirtualStockService;
use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use App\Support\PublicUrl;
use App\Support\ThaiBankCatalog;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class CommerceService
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly CustomerAuthService $customerAuth,
        private readonly IdempotencyService $idempotency,
        private readonly VirtualStockService $virtualStock,
        private readonly VirtualLotteryImageService $virtualImages,
        private readonly LotterySalePriceService $salePrices,
        private readonly GrowthService $growth,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function cartForCustomer(string $tenantId, CustomerSessionContext $customer): array
    {
        $reservations = StockReservation::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('status', 'active')
            ->where('expires_at', '>', now())
            ->orderBy('created_at')
            ->get()
            ->all();

        $reservationIds = array_map(fn (object $reservation): string => (string) $reservation->id, $reservations);
        $cartRows = $this->reservationStockRowsForPricing($reservationIds, $tenantId);
        $cartPricing = $this->salePrices->pricesForReservationStockRows($tenantId, $cartRows);
        $resources = array_map(fn (object $reservation): array => $this->reservationResource($reservation, $cartPricing), $reservations);
        $itemCount = count($cartRows);
        $total = (int) $cartPricing['total_amount'];

        return [
            'server_time' => now()->toISOString(),
            'reservations' => $resources,
            'total' => $this->money($total),
            'subtotal' => $this->money($total),
            'discount_total' => $this->money(0),
            'fee_total' => $this->money(0),
            'item_count' => $itemCount,
            'warnings' => [],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function walletsForCustomer(string $tenantId, CustomerSessionContext $customer): array
    {
        $this->customerAuth->ensurePrimaryWallet($tenantId, $customer->customerId());

        $wallets = Wallet::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->orderBy('type')
            ->get()
            ->all();

        return ['data' => array_map(fn (object $wallet): array => $this->walletResource($wallet), $wallets)];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateCheckoutPayload(array $payload): array
    {
        $errors = [];

        $reservationIds = $payload['reservation_ids'] ?? null;
        $hasReservationIds = is_array($reservationIds) && array_values(array_filter($reservationIds, fn (mixed $id): bool => trim((string) $id) !== '')) !== [];

        if (trim((string) ($payload['reservation_id'] ?? '')) === '' && ! $hasReservationIds) {
            $errors['reservation_id'][] = 'The reservation_id field is required.';
        }

        if ($reservationIds !== null && ! is_array($reservationIds)) {
            $errors['reservation_ids'][] = 'The reservation_ids field must be an array.';
        }

        if (! in_array((string) ($payload['payment_method'] ?? ''), ['wallet', 'external_payment'], true)) {
            $errors['payment_method'][] = 'The payment_method field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function checkout(array $tenant, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $reservationIds = $this->checkoutReservationIds($payload);
        $normalized = [
            'reservation_id' => $reservationIds[0] ?? '',
            'reservation_ids' => $reservationIds,
            'payment_method' => (string) $payload['payment_method'],
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenant, $customer, $normalized, $request, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict($tenant['tenant_id'], 'customer', $customer->customerId(), 'customer.checkout', $idempotencyKey, $normalized, lock: true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $reservationsById = StockReservation::query()
                ->where('tenant_id', $tenant['tenant_id'])
                ->where('customer_id', $customer->customerId())
                ->whereIn('id', $normalized['reservation_ids'])
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            if ($reservationsById->count() !== count($normalized['reservation_ids'])) {
                return ['error' => 'not_found'];
            }

            $reservations = array_map(fn (string $reservationId): object => $reservationsById->get($reservationId), $normalized['reservation_ids']);
            $reservation = $reservations[0];

            foreach ($reservations as $cartReservation) {
                if ($cartReservation->status !== 'active' || (string) $cartReservation->game_id !== (string) $reservation->game_id) {
                    return ['error' => 'resource_conflict'];
                }

                if (Carbon::parse((string) $cartReservation->expires_at)->isPast()) {
                    return ['error' => 'reservation_expired'];
                }
            }

            $stockRows = $this->lockedReservationStockRows($normalized['reservation_ids'], (string) $tenant['tenant_id']);

            if ($stockRows === []) {
                return ['error' => 'resource_conflict'];
            }

            $stockReservationIds = array_values(array_unique(array_map(
                fn (object $stock): string => (string) ($stock->reservation_item_reservation_id ?? ''),
                $stockRows,
            )));

            if (array_values(array_diff($normalized['reservation_ids'], $stockReservationIds)) !== []) {
                return ['error' => 'resource_conflict'];
            }

            foreach ($stockRows as $stock) {
                if ($stock->status !== 'reserved') {
                    return ['error' => 'reservation_unavailable'];
                }
            }

            $pricing = $this->salePrices->pricesForReservationStockRows((string) $tenant['tenant_id'], $stockRows);
            $totalAmount = (int) $pricing['total_amount'];

            if ($normalized['payment_method'] === 'wallet') {
                $order = $this->createPaidWalletOrder($tenant, $customer, $reservation, $stockRows, $pricing, $totalAmount, $idempotencyKey, $request, $normalized['reservation_ids']);
            } else {
                $order = $this->createPendingExternalOrder($tenant, $customer, $reservation, $stockRows, $pricing, $totalAmount, $idempotencyKey, $request, $normalized['reservation_ids']);
            }

            if (isset($order['error'])) {
                return ['error' => $order['error']];
            }

            $status = 201;
            $this->idempotency->storeResponse($tenant['tenant_id'], 'customer', $customer->customerId(), 'customer.checkout', $idempotencyKey, $normalized, $status, $order);

            return ['resource' => $order, 'status' => $status];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerOrder(string $tenantId, CustomerSessionContext $customer, string $orderId): ?array
    {
        $order = Order::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('id', $orderId)
            ->first();

        return $order === null ? null : $this->orderResource($order);
    }

    /**
     * @return array<string, mixed>
     */
    public function customerTickets(string $tenantId, CustomerSessionContext $customer, array $queryParams, bool $history = false): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = Ticket::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->with('localStockItem')
            ->orderBy('id')
            ->limit($limit + 1);

        if ($history) {
            $query->whereIn('status', ['cancelled', 'non_winning', 'paid_out', 'voided']);
        } else {
            $query->whereNotIn('status', ['cancelled', 'non_winning', 'paid_out', 'voided']);
        }

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $ticket): array => $this->ticketResource($ticket), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerTicket(string $tenantId, CustomerSessionContext $customer, string $ticketId): ?array
    {
        $ticket = Ticket::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('id', $ticketId)
            ->with('localStockItem')
            ->first();

        return $ticket === null ? null : $this->ticketDetailResource($ticket);
    }

    /**
     * @return array<string, mixed>
     */
    public function customerTopups(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $perPage = max(1, min(100, (int) ($queryParams['per_page'] ?? 20)));
        $page = max(1, (int) ($queryParams['page'] ?? 1));
        $query = TopupRequest::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->orderByDesc('created_at');
        $total = (clone $query)->count();
        $rows = $query->offset(($page - 1) * $perPage)->limit($perPage)->get()->all();
        $waiting = TopupRequest::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->whereIn('status', ['pending', 'processing'])
            ->orderByDesc('created_at')
            ->first();

        return [
            'bank' => $this->tenantTopupBank($tenantId),
            'waiting' => $waiting === null ? null : $this->topupResource($waiting),
            'histories' => array_map(fn (object $topup): array => $this->topupResource($topup), $rows),
            'meta' => [
                'current_page' => $page,
                'last_page' => (int) ceil($total / $perPage),
                'per_page' => $perPage,
                'total' => $total,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function createCustomerTopup(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request, bool $credit = false): array
    {
        $slipFile = $request->file('slip');
        $slip = $this->topupSlipUpload($slipFile instanceof UploadedFile ? $slipFile : null);

        if (($slip['error'] ?? null) === 'validation_failed') {
            return ['error' => 'validation_failed'];
        }

        $normalized = [
            'channel' => $credit ? 'credit_card' : (string) ($payload['channel'] ?? ''),
            'amount' => (int) ($payload['amount'] ?? 0),
            'transfer_at' => (string) ($payload['transfer_at'] ?? ''),
        ];
        if ($slip !== null) {
            $normalized['slip_sha256'] = $slip['checksum'];
        }
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        if ($normalized['amount'] < ($credit ? 400 : 1)) {
            return ['error' => 'validation_failed'];
        }

        if (! in_array($normalized['channel'], ['qr', 'bank_transfer', 'credit_card'], true)) {
            return ['error' => 'validation_failed'];
        }

        return DB::transaction(function () use ($tenantId, $customer, $normalized, $idempotencyKey, $credit, $slip): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'customer', $customer->customerId(), $credit ? 'customer.topups.credit' : 'customer.topups.create', $idempotencyKey, $normalized, lock: true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $walletId = $this->customerAuth->ensurePrimaryWallet($tenantId, $customer->customerId());
            $now = now();
            $topupId = 'top_'.Str::ulid()->toBase32();
            $paymentId = null;
            $reference = 'TOP-'.Str::upper(Str::random(10));
            $slipAsset = $slip === null ? null : $this->storeTopupSlipAsset($tenantId, $topupId, $slip);

            if ($credit) {
                $paymentId = 'pay_'.Str::ulid()->toBase32();
                Payment::query()->insert([
                    'id' => $paymentId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $customer->customerId(),
                    'order_id' => null,
                    'topup_request_id' => null,
                    'provider' => 'credit_card',
                    'status' => 'pending',
                    'amount' => $normalized['amount'],
                    'currency' => 'THB',
                    'reference' => $reference,
                    'redirect_url' => 'https://payments.example.test/topups/'.$topupId,
                    'idempotency_key' => $idempotencyKey,
                    'payload_hash' => $this->idempotency->payloadHash($normalized),
                    'provider_event_id' => null,
                    'provider_reference' => $reference,
                    'provider_payload_json' => null,
                    'paid_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            TopupRequest::query()->insert([
                'id' => $topupId,
                'tenant_id' => $tenantId,
                'customer_id' => $customer->customerId(),
                'wallet_id' => $walletId,
                'payment_id' => $paymentId,
                'provider' => $credit ? 'credit_card' : 'manual',
                'channel' => $normalized['channel'],
                'status' => $credit ? 'processing' : 'pending',
                'amount' => $normalized['amount'],
                'bonus_amount' => 0,
                'currency' => 'THB',
                'reference' => $reference,
                'transfer_at' => $normalized['transfer_at'] === '' ? null : Carbon::parse($normalized['transfer_at']),
                'slip_url' => $slipAsset['url'] ?? null,
                'slip_thumb_url' => $slipAsset['thumb_url'] ?? null,
                'slip_storage_path' => $slipAsset['storage_path'] ?? null,
                'slip_thumb_storage_path' => $slipAsset['thumb_storage_path'] ?? null,
                'slip_expires_at' => $slipAsset['expires_at'] ?? null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $this->idempotency->payloadHash($normalized),
                'reviewed_by_admin_id' => null,
                'reviewed_at' => null,
                'admin_note' => null,
                'provider_payload_json' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            if ($paymentId !== null) {
                Payment::query()->where('id', $paymentId)->update(['topup_request_id' => $topupId]);
            }

            $resource = $this->topupResource(TopupRequest::where('id', $topupId)->first());
            $this->idempotency->storeResponse($tenantId, 'customer', $customer->customerId(), $credit ? 'customer.topups.credit' : 'customer.topups.create', $idempotencyKey, $normalized, 201, $resource);
            $this->queueTopupUpdatedBroadcast($tenantId, $topupId);

            return ['resource' => $resource, 'status' => 201];
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerTopup(string $tenantId, CustomerSessionContext $customer, string $topupId): ?array
    {
        $topup = TopupRequest::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('id', $topupId)
            ->first();

        return $topup === null ? null : $this->topupResource($topup);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function uploadCustomerTopupSlip(string $tenantId, CustomerSessionContext $customer, string $topupId, array $payload, Request $request): array
    {
        $slipFile = $request->file('slip');
        $slip = $this->topupSlipUpload($slipFile instanceof UploadedFile ? $slipFile : null);

        if (! is_array($slip) || ($slip['error'] ?? null) === 'validation_failed') {
            return ['error' => 'validation_failed'];
        }

        $normalized = [
            'topup_id' => $topupId,
            'slip_sha256' => $slip['checksum'],
            'transfer_at' => (string) ($payload['transfer_at'] ?? ''),
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $customer, $topupId, $normalized, $idempotencyKey, $slip): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'customer', $customer->customerId(), 'customer.topups.slip:'.$topupId, $idempotencyKey, $normalized, lock: true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $topup = TopupRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('id', $topupId)
                ->lockForUpdate()
                ->first();

            if ($topup === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $topup->status, ['pending', 'processing'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $oldPaths = [
                trim((string) ($topup->slip_storage_path ?? '')),
                trim((string) ($topup->slip_thumb_storage_path ?? '')),
            ];
            $slipAsset = $this->storeTopupSlipAsset($tenantId, $topupId, $slip);
            $updates = [
                'slip_url' => $slipAsset['url'],
                'slip_thumb_url' => $slipAsset['thumb_url'],
                'slip_storage_path' => $slipAsset['storage_path'],
                'slip_thumb_storage_path' => $slipAsset['thumb_storage_path'],
                'slip_expires_at' => $slipAsset['expires_at'],
                'updated_at' => now(),
            ];

            if ($normalized['transfer_at'] !== '') {
                $updates['transfer_at'] = Carbon::parse($normalized['transfer_at']);
            }

            TopupRequest::query()->where('id', $topupId)->update($updates);

            $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));
            foreach ($oldPaths as $path) {
                if ($path !== '') {
                    $disk->delete($path);
                }
            }

            $resource = $this->topupResource(TopupRequest::where('id', $topupId)->first());
            $this->idempotency->storeResponse($tenantId, 'customer', $customer->customerId(), 'customer.topups.slip:'.$topupId, $idempotencyKey, $normalized, 200, $resource);
            $this->queueTopupUpdatedBroadcast($tenantId, $topupId);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function cancelCustomerTopup(string $tenantId, CustomerSessionContext $customer, string $topupId, array $payload, Request $request): array
    {
        $normalized = [
            'topup_id' => $topupId,
            'reason' => trim((string) ($payload['reason'] ?? '')),
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $customer, $topupId, $normalized, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'customer', $customer->customerId(), 'customer.topups.cancel:'.$topupId, $idempotencyKey, $normalized, lock: true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $topup = TopupRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('id', $topupId)
                ->lockForUpdate()
                ->first();

            if ($topup === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $topup->status, ['pending', 'processing'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $payment = $topup->payment_id === null ? null : Payment::query()->where('id', $topup->payment_id)->lockForUpdate()->first();

            if ($payment !== null && ! in_array((string) $payment->status, ['pending', 'processing'], true)) {
                return ['error' => 'resource_conflict'];
            }

            TopupRequest::query()->where('id', $topupId)->update([
                'status' => 'cancelled',
                'admin_note' => $normalized['reason'] === '' ? null : $normalized['reason'],
                'updated_at' => now(),
            ]);

            if ($payment !== null) {
                Payment::query()->where('id', $payment->id)->update([
                    'status' => 'cancelled',
                    'updated_at' => now(),
                ]);
            }

            $resource = $this->topupResource(TopupRequest::where('id', $topupId)->first());
            $this->idempotency->storeResponse($tenantId, 'customer', $customer->customerId(), 'customer.topups.cancel:'.$topupId, $idempotencyKey, $normalized, 200, $resource);
            $this->queueTopupUpdatedBroadcast($tenantId, $topupId);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function adminOrders(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = Order::query()
            ->select('orders.*')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'orders.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->forTenant($tenantId);

        foreach (['status', 'payment_status', 'game_id', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where('orders.'.$field, trim((string) $queryParams[$field]));
            }
        }

        $customerNo = trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'] ?? ''));
        if ($customerNo !== '') {
            $query->where('customers.customer_no', 'like', '%'.strtoupper($customerNo).'%');
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('orders.id', '>', trim((string) $queryParams['cursor']));
        }

        $this->applyAdminOrderSort($query, $queryParams);
        $query->limit($limit + 1);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $order): array => $this->adminOrderSummaryResource($order), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    public function adminOrder(string $tenantId, string $orderId): ?array
    {
        $order = Order::query()->forTenant($tenantId)->where('id', $orderId)->first();

        return $order === null ? null : $this->adminOrderDetailResource($order);
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyAdminOrderSort(mixed $query, array $queryParams): void
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'id');
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'orders.id',
            'order_id' => 'orders.id',
            'customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'customer_name' => 'customers.name',
            'total.amount' => 'orders.total_amount',
            'status' => 'orders.status',
            'created_at' => 'orders.created_at',
        ];
        $column = $columns[$sortBy] ?? 'orders.id';

        $query->reorder($column, $direction);

        if ($column !== 'orders.id') {
            $query->orderBy('orders.id');
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function updateAdminOrder(string $tenantId, AdminSessionContext $actor, string $orderId, array $payload, Request $request): array
    {
        $normalized = array_filter([
            'status' => $payload['status'] ?? null,
            'payment_status' => $payload['payment_status'] ?? null,
            'admin_note' => $payload['admin_note'] ?? null,
            'reason' => $payload['reason'] ?? null,
        ], fn (mixed $value): bool => $value !== null);

        return $this->adminOrderWrite($tenantId, $actor, $orderId, $normalized, $request, 'admin.tenant.orders.patch', 'order.update', function (object $order) use ($normalized): void {
            $updates = ['updated_at' => now()];

            foreach (['status', 'payment_status', 'admin_note'] as $field) {
                if (array_key_exists($field, $normalized)) {
                    $updates[$field] = $normalized[$field];
                }
            }

            Order::query()->where('id', $order->id)->update($updates);
        }, 'order.updated');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function cancelAdminOrder(string $tenantId, AdminSessionContext $actor, string $orderId, array $payload, Request $request): array
    {
        return $this->adminOrderWrite($tenantId, $actor, $orderId, $payload, $request, 'admin.tenant.orders.cancel', 'order.cancel', function (object $order) use ($payload, $request, $actor): void {
            Order::query()->where('id', $order->id)->update([
                'status' => 'cancelled',
                'payment_status' => $order->payment_status === 'paid' ? 'refunded' : $order->payment_status,
                'cancelled_at' => now(),
                'updated_at' => now(),
            ]);

            if (($payload['refund_policy'] ?? 'none') === 'wallet_refund' && $order->wallet_id !== null && $order->payment_status === 'paid') {
                $this->postLedger((string) $order->tenant_id, (string) $order->wallet_id, (string) $order->customer_id, 'reversal', (int) $order->total_amount, 'order_cancel', (string) $order->id, (string) $request->header('Idempotency-Key'), $actor->adminUser['id']);
            }
        }, 'order.cancelled');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function refundAdminOrder(string $tenantId, AdminSessionContext $actor, string $orderId, array $payload, Request $request): array
    {
        return $this->adminOrderWrite($tenantId, $actor, $orderId, $payload, $request, 'admin.tenant.orders.refund', 'order.refund', function (object $order) use ($payload, $request, $actor): void {
            $amount = $this->moneyAmount($payload['amount'] ?? null, (int) $order->total_amount);

            if ($order->wallet_id !== null) {
                $this->postLedger((string) $order->tenant_id, (string) $order->wallet_id, (string) $order->customer_id, 'reversal', $amount, 'order_refund', (string) $order->id, (string) $request->header('Idempotency-Key'), $actor->adminUser['id']);
            }

            Order::query()->where('id', $order->id)->update([
                'status' => 'refunded',
                'payment_status' => 'refunded',
                'refunded_at' => now(),
                'updated_at' => now(),
            ]);
        }, 'order.refunded');
    }

    /**
     * @param callable(object): void $mutator
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    private function adminOrderWrite(string $tenantId, AdminSessionContext $actor, string $orderId, array $payload, Request $request, string $routeKey, string $permissionCode, callable $mutator, string $auditAction): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $actor, $orderId, $payload, $request, $routeKey, $permissionCode, $mutator, $auditAction, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', $actor->adminUser['id'], $routeKey.':'.$orderId, $idempotencyKey, $payload, $permissionCode, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $order = Order::query()->where('tenant_id', $tenantId)->where('id', $orderId)->lockForUpdate()->first();

            if ($order === null) {
                return ['error' => 'not_found'];
            }

            $mutator($order);
            $resource = $this->adminOrderDetailResource(Order::where('id', $orderId)->first());
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', $actor->adminUser['id'], $routeKey.':'.$orderId, $idempotencyKey, $payload, 200, $resource, $permissionCode);
            $this->auditAdmin($actor, $request, $auditAction, 'order', $orderId, $payload, $tenantId);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function adminTickets(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = Ticket::query()->forTenant($tenantId)->orderBy('id')->limit($limit + 1);

        foreach (['status', 'game_id', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $ticket): array => $this->ticketDetailResource($ticket), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    public function adminTicket(string $tenantId, string $ticketId): ?array
    {
        $ticket = Ticket::query()->forTenant($tenantId)->where('id', $ticketId)->first();

        return $ticket === null ? null : $this->ticketDetailResource($ticket);
    }

    /**
     * @return array<string, mixed>
     */
    public function adminWallets(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = Wallet::query()
            ->select('wallets.*')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'wallets.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->with('customer')
            ->forTenant($tenantId);

        if (($queryParams['customer_id'] ?? null) !== null && trim((string) $queryParams['customer_id']) !== '') {
            $query->where('wallets.customer_id', trim((string) $queryParams['customer_id']));
        }

        if (($queryParams['customer_no'] ?? $queryParams['member_no'] ?? null) !== null && trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'])) !== '') {
            $customerNo = strtoupper(trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'])));
            $query->where('customers.customer_no', 'like', '%'.$customerNo.'%');
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('wallets.id', '>', trim((string) $queryParams['cursor']));
        }

        $this->applyWalletSort($query, $queryParams);
        $query->limit($limit + 1);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $wallet): array => $this->adminWalletResource($wallet), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    public function adminWallet(string $tenantId, string $walletId): ?array
    {
        $wallet = Wallet::query()->with('customer')->forTenant($tenantId)->where('id', $walletId)->first();

        return $wallet === null ? null : $this->adminWalletResource($wallet);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function adminWalletLedger(string $tenantId, string $walletId, array $queryParams): ?array
    {
        if (! Wallet::query()->forTenant($tenantId)->where('id', $walletId)->exists()) {
            return null;
        }

        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = WalletLedger::query()
            ->forTenant($tenantId)
            ->where('wallet_id', $walletId);

        if (($queryParams['entry_type'] ?? null) !== null && trim((string) $queryParams['entry_type']) !== '') {
            $query->where('entry_type', trim((string) $queryParams['entry_type']));
        }

        if (($queryParams['created_from'] ?? null) !== null && trim((string) $queryParams['created_from']) !== '') {
            $query->where('created_at', '>=', Carbon::parse((string) $queryParams['created_from']));
        }

        if (($queryParams['created_to'] ?? null) !== null && trim((string) $queryParams['created_to']) !== '') {
            $query->where('created_at', '<=', Carbon::parse((string) $queryParams['created_to']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $this->applyWalletLedgerSort($query, $queryParams);
        $query->limit($limit + 1);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $ledger): array => $this->ledgerResource($ledger), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function adjustAdminWallet(string $tenantId, AdminSessionContext $actor, string $walletId, array $payload, Request $request): array
    {
        $amount = $this->moneyAmount($payload['amount'] ?? null, 0);
        $transactionType = (string) ($payload['transaction_type'] ?? '');

        if ($transactionType === 'withdraw') {
            $amount = -abs($amount);
        } elseif ($transactionType === 'deposit') {
            $amount = abs($amount);
        }

        $normalized = [
            'amount' => $amount,
            'transaction_type' => $transactionType,
            'reason' => (string) ($payload['reason'] ?? ''),
            'note' => (string) ($payload['note'] ?? ''),
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $actor, $walletId, $payload, $request, $amount, $normalized, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', $actor->adminUser['id'], 'admin.tenant.wallets.adjust:'.$walletId, $idempotencyKey, $normalized, 'wallet.adjust', true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $wallet = Wallet::query()->where('tenant_id', $tenantId)->where('id', $walletId)->lockForUpdate()->first();

            if ($wallet === null) {
                return ['error' => 'not_found'];
            }

            $this->postLedger($tenantId, $walletId, (string) $wallet->customer_id, 'adjustment', $amount, 'admin_wallet_adjust', $walletId, $idempotencyKey, $actor->adminUser['id'], $payload);
            $resource = $this->adminWalletResource(Wallet::where('id', $walletId)->first());
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', $actor->adminUser['id'], 'admin.tenant.wallets.adjust:'.$walletId, $idempotencyKey, $normalized, 200, $resource, 'wallet.adjust');
            $this->auditAdmin($actor, $request, 'wallet.adjusted', 'wallet', $walletId, $payload, $tenantId);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyWalletSort(mixed $query, array $queryParams): void
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'customer_no');
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'wallets.id',
            'customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'customer_name' => 'customers.name',
            'balance' => 'wallets.balance_amount',
            'balance.amount' => 'wallets.balance_amount',
            'status' => 'wallets.status',
            'created_at' => 'wallets.created_at',
            'updated_at' => 'wallets.updated_at',
        ];
        $column = $columns[$sortBy] ?? 'customers.customer_no';

        $query->reorder($column, $direction);

        if ($column !== 'wallets.id') {
            $query->orderBy('wallets.id');
        }
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyWalletLedgerSort(mixed $query, array $queryParams): void
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'created_at');
        $defaultDirection = $sortBy === 'created_at' ? 'desc' : 'asc';
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? $defaultDirection)) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'id',
            'entry_type' => 'entry_type',
            'status' => 'status',
            'amount.amount' => 'amount',
            'balance_after.amount' => 'balance_after',
            'reference_type' => 'reference_type',
            'created_at' => 'created_at',
        ];
        $column = $columns[$sortBy] ?? 'created_at';

        $query->reorder($column, $direction);

        if ($column !== 'id') {
            $query->orderBy('id', $direction);
        }
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyTopupSort(mixed $query, array $queryParams): string
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'created_at');
        $defaultDirection = in_array($sortBy, ['id', 'created_at', 'updated_at'], true) ? 'desc' : 'asc';
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? $defaultDirection)) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'topup_requests.id',
            'customer_no' => 'customers.customer_no',
            'customer.customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'customer_name' => 'customers.name',
            'customer.name' => 'customers.name',
            'amount' => 'topup_requests.amount',
            'amount.amount' => 'topup_requests.amount',
            'status' => 'topup_requests.status',
            'channel' => 'topup_requests.channel',
            'created_at' => 'topup_requests.created_at',
            'updated_at' => 'topup_requests.updated_at',
        ];
        $column = $columns[$sortBy] ?? 'topup_requests.created_at';

        $query->reorder($column, $direction);

        if ($column !== 'topup_requests.id') {
            $query->orderBy('topup_requests.id', $direction);
        }

        return $direction;
    }

    /**
     * @return array<string, mixed>
     */
    public function adminTopups(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TopupRequest::query()
            ->select('topup_requests.*')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'topup_requests.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->forTenant($tenantId);

        foreach (['customer_id', 'channel'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where('topup_requests.'.$field, trim((string) $queryParams[$field]));
            }
        }

        $customerNo = trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'] ?? ''));
        if ($customerNo !== '') {
            $query->where('customers.customer_no', 'like', '%'.strtoupper($customerNo).'%');
        }

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->whereIn('topup_requests.status', $this->storedTopupStatusesForPresentation(trim((string) $queryParams['status'])));
        }

        $section = trim((string) ($queryParams['section'] ?? ''));
        if ($section === 'pending') {
            $query->whereIn('topup_requests.status', ['pending', 'processing']);
        } elseif ($section === 'history') {
            $query->whereNotIn('topup_requests.status', ['pending', 'processing']);
        }

        $sortDirection = $this->applyTopupSort($query, $queryParams);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $operator = $sortDirection === 'desc' ? '<' : '>';
            $query->where('topup_requests.id', $operator, trim((string) $queryParams['cursor']));
        }

        $query->limit($limit + 1);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $topup): array => $this->adminTopupSummaryResource($topup), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    public function adminTopup(string $tenantId, string $topupId): ?array
    {
        $topup = TopupRequest::query()->forTenant($tenantId)->where('id', $topupId)->first();

        return $topup === null ? null : $this->adminTopupDetailResource($topup);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approveAdminTopup(string $tenantId, AdminSessionContext $actor, string $topupId, array $payload, Request $request): array
    {
        return $this->adminTopupWrite($tenantId, $actor, $topupId, $payload, $request, 'admin.tenant.topups.approve', 'topup.approve', function (object $topup) use ($payload, $request, $actor): void {
            $amount = (int) $topup->amount;
            $bonus = $this->moneyAmount($payload['bonus_amount'] ?? null, (int) $topup->bonus_amount);
            $adminNote = $this->optionalAdminNote($payload);

            $ledger = $this->postLedger((string) $topup->tenant_id, (string) $topup->wallet_id, (string) $topup->customer_id, 'credit', $amount + $bonus, 'topup', (string) $topup->id, (string) $request->header('Idempotency-Key'), $actor->adminUser['id'], $payload);

            TopupRequest::query()->where('id', $topup->id)->update([
                'status' => 'succeeded',
                'bonus_amount' => $bonus,
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => now(),
                'admin_note' => $adminNote,
                'updated_at' => now(),
            ]);

            $this->insertOutboxEvent('wallet.updated.v1', (string) $topup->tenant_id, null, null, 'wallet', (string) $topup->wallet_id, (string) $request->header('Idempotency-Key'), $request->header('X-Request-Id'), [
                'tenant_id' => (string) $topup->tenant_id,
                'customer_id' => (string) $topup->customer_id,
                'wallet_id' => (string) $topup->wallet_id,
                'ledger_id' => $ledger['id'],
                'entry_type' => 'credit',
                'amount' => $amount + $bonus,
                'currency' => 'THB',
                'posted_balance' => $ledger['balance_after'],
            ]);
        }, 'topup.approved');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function rejectAdminTopup(string $tenantId, AdminSessionContext $actor, string $topupId, array $payload, Request $request): array
    {
        return $this->adminTopupWrite($tenantId, $actor, $topupId, $payload, $request, 'admin.tenant.topups.reject', 'topup.reject', function (object $topup) use ($payload, $actor): void {
            TopupRequest::query()->where('id', $topup->id)->update([
                'status' => 'failed',
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => now(),
                'admin_note' => $this->optionalAdminNote($payload),
                'updated_at' => now(),
            ]);
        }, 'topup.rejected');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function cancelAdminTopup(string $tenantId, AdminSessionContext $actor, string $topupId, array $payload, Request $request): array
    {
        return $this->adminTopupWrite($tenantId, $actor, $topupId, $payload, $request, 'admin.tenant.topups.cancel', 'topup.cancel', function (object $topup) use ($payload, $actor): void {
            TopupRequest::query()->where('id', $topup->id)->update([
                'status' => 'cancelled',
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => now(),
                'admin_note' => $this->optionalAdminNote($payload),
                'updated_at' => now(),
            ]);
        }, 'topup.cancelled');
    }

    /**
     * @param callable(object): void $mutator
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    private function adminTopupWrite(string $tenantId, AdminSessionContext $actor, string $topupId, array $payload, Request $request, string $routeKey, string $permissionCode, callable $mutator, string $auditAction): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $actor, $topupId, $payload, $request, $routeKey, $permissionCode, $mutator, $auditAction, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', $actor->adminUser['id'], $routeKey.':'.$topupId, $idempotencyKey, $payload, $permissionCode, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $topup = TopupRequest::query()->where('tenant_id', $tenantId)->where('id', $topupId)->lockForUpdate()->first();

            if ($topup === null) {
                return ['error' => 'not_found'];
            }

            if (in_array((string) $topup->status, ['succeeded', 'failed', 'cancelled', 'expired', 'reversed'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $mutator($topup);
            $resource = $this->adminTopupDetailResource(TopupRequest::where('id', $topupId)->first());
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', $actor->adminUser['id'], $routeKey.':'.$topupId, $idempotencyKey, $payload, 200, $resource, $permissionCode);
            $this->auditAdmin($actor, $request, $auditAction, 'topup_request', $topupId, $payload, $tenantId);
            $this->queueTopupUpdatedBroadcast($tenantId, $topupId);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function acceptWebhook(string $domain, string $provider, array $payload, Request $request): array
    {
        $callbackKey = $this->webhookCallbackKey($payload);
        $payloadHash = $this->idempotency->payloadHash($payload);

        return DB::transaction(function () use ($domain, $provider, $payload, $request, $callbackKey, $payloadHash): array {
            $existing = WebhookCallback::query()
                ->where('domain', $domain)
                ->where('provider', $provider)
                ->where('callback_key', $callbackKey)
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                if ($existing->payload_hash !== $payloadHash) {
                    return ['error' => 'resource_conflict'];
                }

                return ['resource' => [
                    'accepted' => true,
                    'duplicate' => true,
                    'correlation_id' => $request->header('X-Request-Id'),
                    'message' => 'Duplicate callback ignored.',
                ], 'status' => 202];
            }

            $payment = $this->paymentForWebhook($domain, $provider, $payload);
            $topup = $this->topupForWebhook($domain, $provider, $payload, $payment);
            $callbackId = 'whc_'.Str::ulid()->toBase32();
            $response = [
                'accepted' => true,
                'duplicate' => false,
                'correlation_id' => $request->header('X-Request-Id'),
                'message' => 'Callback accepted.',
            ];

            WebhookCallback::query()->insert([
                'id' => $callbackId,
                'domain' => $domain,
                'provider' => $provider,
                'callback_key' => $callbackKey,
                'payload_hash' => $payloadHash,
                'status' => 'accepted',
                'payment_id' => $payment?->id,
                'topup_request_id' => $topup?->id,
                'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
                'response_json' => json_encode($response, JSON_THROW_ON_ERROR),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            if ($this->webhookIsSuccessful($payload)) {
                if ($domain === 'payments' && $payment !== null && $payment->order_id !== null) {
                    $this->finalizeExternalPayment($payment, $request);
                }

                if ($domain === 'topups' && $topup !== null) {
                    $this->finalizeCreditTopup($topup, $request);
                }
            }

            return ['resource' => $response, 'status' => 202];
        });
    }

    public function processSoldSync(int $limit = 100): int
    {
        $events = SyncOutbox::query()
            ->where('event_type', 'stock.sold.v1')
            ->where('status', 'pending')
            ->where('available_at', '<=', now())
            ->orderBy('id')
            ->limit(max(1, min(500, $limit)))
            ->get()
            ->all();
        $processed = 0;

        foreach ($events as $event) {
            if ($this->processSoldEvent($event)) {
                $processed++;
            }
        }

        return $processed;
    }

    public function pruneExpiredTopupSlips(int $limit = 100): int
    {
        $rows = TopupRequest::query()
            ->whereNotNull('slip_expires_at')
            ->where('slip_expires_at', '<=', now())
            ->orderBy('slip_expires_at')
            ->limit(max(1, min(500, $limit)))
            ->get()
            ->all();
        $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));
        $pruned = 0;

        foreach ($rows as $row) {
            foreach ([$row->slip_storage_path, $row->slip_thumb_storage_path] as $path) {
                $path = trim((string) $path);

                if ($path !== '') {
                    $disk->delete($path);
                }
            }

            TopupRequest::query()
                ->where('id', $row->id)
                ->update([
                    'slip_url' => null,
                    'slip_thumb_url' => null,
                    'slip_storage_path' => null,
                    'slip_thumb_storage_path' => null,
                    'slip_expires_at' => null,
                    'updated_at' => now(),
                ]);

            $pruned++;
        }

        return $pruned;
    }

    private function processSoldEvent(object $event): bool
    {
        return DB::transaction(function () use ($event): bool {
            $payloadHash = $this->hashJsonValue($event->payload_json);
            $existingInbox = SyncInbox::query()->where('event_id', $event->event_id)->lockForUpdate()->first();
            $now = now();

            if ($existingInbox !== null && $existingInbox->status === 'processed') {
                SyncOutbox::query()->where('id', $event->id)->update([
                    'status' => 'processed',
                    'processed_at' => $now,
                    'updated_at' => $now,
                ]);

                return false;
            }

            if ($existingInbox === null) {
                SyncInbox::query()->insert([
                    'id' => 'inb_'.Str::ulid()->toBase32(),
                    'event_id' => (string) $event->event_id,
                    'event_type' => (string) $event->event_type,
                    'event_version' => (int) $event->event_version,
                    'consumer' => 'central_stock',
                    'tenant_id' => $event->tenant_id,
                    'partner_id' => $event->partner_id,
                    'game_id' => $event->game_id,
                    'idempotency_key' => $event->idempotency_key,
                    'payload_hash' => $payloadHash,
                    'status' => 'processing',
                    'processed_at' => null,
                    'last_error' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            $payload = $this->decodeJsonObject($event->payload_json);
            $items = is_array($payload['items'] ?? null) ? $payload['items'] : [];

            foreach ($items as $item) {
                if (! is_array($item) || ($item['stock_item_id'] ?? null) === null) {
                    continue;
                }

                StockItem::query()
                    ->where('id', (string) $item['stock_item_id'])
                    ->where('tenant_id', $event->tenant_id)
                    ->where('game_id', $event->game_id)
                    ->where('status', '!=', 'sold')
                    ->update([
                        'status' => 'sold',
                        'updated_at' => $now,
                    ]);
            }

            SyncInbox::query()->where('event_id', $event->event_id)->update([
                'status' => 'processed',
                'processed_at' => $now,
                'updated_at' => $now,
            ]);

            SyncOutbox::query()->where('id', $event->id)->update([
                'status' => 'processed',
                'processed_at' => $now,
                'updated_at' => $now,
            ]);

            return true;
        });
    }

    /**
     * @param array<int, object> $stockRows
     * @return array<string, mixed>
     */
    private function createPaidWalletOrder(array $tenant, CustomerSessionContext $customer, object $reservation, array $stockRows, array $pricing, int $totalAmount, string $idempotencyKey, Request $request, array $reservationIds): array
    {
        $walletId = $this->customerAuth->ensurePrimaryWallet((string) $tenant['tenant_id'], $customer->customerId());
        $wallet = Wallet::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('id', $walletId)
            ->lockForUpdate()
            ->first();

        if ($wallet === null || $wallet->status !== 'active') {
            return ['error' => 'resource_conflict'];
        }

        if ((int) $wallet->balance_amount < $totalAmount) {
            return ['error' => 'wallet_insufficient_balance'];
        }

        $now = now();
        $orderId = 'ord_'.Str::ulid()->toBase32();
        $order = $this->insertOrder($orderId, $tenant, $customer, $reservation, 'wallet', 'paid', 'paid', $totalAmount, $walletId, $idempotencyKey, $now);
        $tickets = $this->createSoldOrderItemsAndTickets((string) $tenant['tenant_id'], $customer, $orderId, $stockRows, $pricing, $now);
        $ledger = $this->postLedger((string) $tenant['tenant_id'], $walletId, $customer->customerId(), 'debit', $totalAmount, 'order', $orderId, $idempotencyKey);

        StockReservation::query()->whereIn('id', $reservationIds)->update([
            'status' => 'converted',
            'converted_at' => $now,
            'updated_at' => $now,
        ]);
        StockReservationItem::query()->whereIn('reservation_id', $reservationIds)->update([
            'status' => 'converted',
            'updated_at' => $now,
        ]);
        LocalStockItem::query()
            ->where('tenant_id', $tenant['tenant_id'])
            ->whereIn('id', array_map(fn (object $stock): string => (string) $stock->id, $stockRows))
            ->update([
                'status' => 'sold',
                'sold_at' => $now,
                'updated_at' => $now,
            ]);
        $this->virtualStock->convertReservedRowsToSold(
            stockRows: $stockRows,
            tenantId: (string) $tenant['tenant_id'],
            partnerId: (string) $tenant['partner_id'],
            gameId: (string) $reservation->game_id,
            customerId: $customer->customerId(),
        );

        $this->insertPaidOrderEvents($tenant, $customer, $orderId, (string) $reservation->game_id, $stockRows, $tickets, $totalAmount, $ledger, $idempotencyKey, $request);
        $this->calculateAffiliateCommissionForOrder($orderId, (string) $tenant['tenant_id']);

        return $this->orderResource(Order::where('id', $order->id)->first());
    }

    /**
     * @param array<int, object> $stockRows
     * @return array<string, mixed>
     */
    private function createPendingExternalOrder(array $tenant, CustomerSessionContext $customer, object $reservation, array $stockRows, array $pricing, int $totalAmount, string $idempotencyKey, Request $request, array $reservationIds): array
    {
        $now = now();
        $orderId = 'ord_'.Str::ulid()->toBase32();
        $order = $this->insertOrder($orderId, $tenant, $customer, $reservation, 'external_payment', 'pending_payment', 'pending', $totalAmount, null, $idempotencyKey, $now);
        $this->createPendingOrderItems((string) $tenant['tenant_id'], $orderId, $stockRows, $pricing, $now);
        $paymentId = 'pay_'.Str::ulid()->toBase32();
        $reference = 'PAY-'.Str::upper(Str::random(10));
        $redirectUrl = 'https://payments.example.test/orders/'.$orderId;

        Payment::query()->insert([
            'id' => $paymentId,
            'tenant_id' => $tenant['tenant_id'],
            'customer_id' => $customer->customerId(),
            'order_id' => $orderId,
            'topup_request_id' => null,
            'provider' => 'external_payment',
            'status' => 'pending',
            'amount' => $totalAmount,
            'currency' => 'THB',
            'reference' => $reference,
            'redirect_url' => $redirectUrl,
            'idempotency_key' => $idempotencyKey,
            'payload_hash' => $this->idempotency->payloadHash(['order_id' => $orderId, 'reservation_ids' => $reservationIds]),
            'provider_event_id' => null,
            'provider_reference' => $reference,
            'provider_payload_json' => null,
            'paid_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        Order::query()->where('id', $orderId)->update([
            'reference' => $reference,
            'updated_at' => $now,
        ]);

        $resource = $this->orderResource(Order::where('id', $order->id)->first());
        $resource['redirect_url'] = $redirectUrl;

        return $resource;
    }

    /**
     * @param array<string, mixed> $tenant
     */
    private function insertOrder(string $orderId, array $tenant, CustomerSessionContext $customer, object $reservation, string $paymentMethod, string $status, string $paymentStatus, int $totalAmount, ?string $walletId, string $idempotencyKey, Carbon $now): object
    {
        Order::query()->insert([
            'id' => $orderId,
            'tenant_id' => $tenant['tenant_id'],
            'customer_id' => $customer->customerId(),
            'reservation_id' => $reservation->id,
            'game_id' => $reservation->game_id,
            'wallet_id' => $walletId,
            'payment_method' => $paymentMethod,
            'status' => $status,
            'payment_status' => $paymentStatus,
            'total_amount' => $totalAmount,
            'currency' => 'THB',
            'reference' => 'ORD-'.Str::upper(Str::random(10)),
            'admin_note' => null,
            'idempotency_key' => $idempotencyKey,
            'payload_hash' => $this->idempotency->payloadHash(['reservation_id' => $reservation->id, 'payment_method' => $paymentMethod]),
            'paid_at' => $status === 'paid' ? $now : null,
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return Order::where('id', $orderId)->first();
    }

    /**
     * @param array<int, object> $stockRows
     */
    private function createPendingOrderItems(string $tenantId, string $orderId, array $stockRows, array $pricing, Carbon $now): void
    {
        foreach ($stockRows as $stock) {
            $price = $pricing['items'][(string) $stock->id] ?? null;

            OrderItem::query()->insert([
                'id' => 'oit_'.Str::ulid()->toBase32(),
                'tenant_id' => $tenantId,
                'order_id' => $orderId,
                'local_stock_item_id' => $stock->id,
                'ticket_id' => null,
                'status' => 'reserved',
                'price_amount' => (int) ($price['amount'] ?? 0),
                'currency' => (string) ($price['currency'] ?? 'THB'),
                'sale_price_rule_snapshot_json' => json_encode($price['snapshot'] ?? [], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    /**
     * @param array<int, object> $stockRows
     * @return array<int, array<string, mixed>>
     */
    private function createSoldOrderItemsAndTickets(string $tenantId, CustomerSessionContext $customer, string $orderId, array $stockRows, array $pricing, Carbon $now): array
    {
        $tickets = [];

        foreach ($stockRows as $stock) {
            $ticketId = 'tic_'.Str::ulid()->toBase32();
            $orderItemId = 'oit_'.Str::ulid()->toBase32();
            $image = $this->queuedSoldTicketImage($ticketId, $stock, $now);

            Ticket::query()->insert([
                'id' => $ticketId,
                'tenant_id' => $tenantId,
                'customer_id' => $customer->customerId(),
                'order_id' => $orderId,
                'local_stock_item_id' => $stock->id,
                'game_id' => $stock->game_id,
                'full_number' => $stock->full_number,
                'status' => 'active',
                'image_url' => $image['image_url'],
                'image_thumb_url' => $image['image_thumb_url'],
                'image_render_snapshot_json' => $image['snapshot'] === [] ? null : json_encode($image['snapshot'], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $this->dispatchSoldTicketImageGeneration($ticketId, $stock);

            $existingOrderItem = OrderItem::query()
                ->where('tenant_id', $tenantId)
                ->where('order_id', $orderId)
                ->where('local_stock_item_id', $stock->id)
                ->first();

            if ($existingOrderItem === null) {
                OrderItem::query()->insert([
                    'id' => $orderItemId,
                    'tenant_id' => $tenantId,
                    'order_id' => $orderId,
                    'local_stock_item_id' => $stock->id,
                    'ticket_id' => $ticketId,
                    'status' => 'sold',
                    'price_amount' => (int) ($pricing['items'][(string) $stock->id]['amount'] ?? 0),
                    'currency' => (string) ($pricing['items'][(string) $stock->id]['currency'] ?? 'THB'),
                    'sale_price_rule_snapshot_json' => json_encode($pricing['items'][(string) $stock->id]['snapshot'] ?? [], JSON_THROW_ON_ERROR),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            } else {
                OrderItem::query()->where('id', $existingOrderItem->id)->update([
                    'ticket_id' => $ticketId,
                    'status' => 'sold',
                    'updated_at' => $now,
                ]);
            }

            $tickets[] = ['id' => $ticketId, 'stock' => $stock];
        }

        return $tickets;
    }

    /**
     * @return array{image_url: ?string, image_thumb_url: ?string, snapshot: array<string, mixed>}
     */
    private function queuedSoldTicketImage(string $ticketId, object $stock, Carbon $now): array
    {
        $isVirtual = ($stock->virtual_stock_ref ?? null) !== null;

        return [
            'image_url' => PublicUrl::normalizeAssetUrl($stock->image_url ?? null),
            'image_thumb_url' => PublicUrl::normalizeAssetUrl($stock->image_thumb_url ?? null),
            'snapshot' => $isVirtual
                ? [
                    'ticket_id' => $ticketId,
                    'virtual_stock_ref' => (string) ($stock->virtual_stock_ref ?? ''),
                    'render_status' => 'queued',
                    'queued_at' => $now->toISOString(),
                ]
                : [],
        ];
    }

    private function dispatchSoldTicketImageGeneration(string $ticketId, object $stock): void
    {
        if (($stock->virtual_stock_ref ?? null) === null) {
            return;
        }

        DB::afterCommit(static function () use ($ticketId): void {
            GenerateSoldTicketImageJob::dispatch($ticketId);
        });
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<int, object> $stockRows
     * @param array<int, array<string, mixed>> $tickets
     * @param array<string, mixed> $ledger
     */
    private function insertPaidOrderEvents(array $tenant, CustomerSessionContext $customer, string $orderId, string $gameId, array $stockRows, array $tickets, int $totalAmount, ?array $ledger, string $idempotencyKey, Request $request): void
    {
        $ticketIds = array_map(fn (array $ticket): string => $ticket['id'], $tickets);
        $soldAt = now()->toISOString();

        $this->insertOutboxEvent('order.paid.v1', (string) $tenant['tenant_id'], (string) $tenant['partner_id'], $gameId, 'order', $orderId, $idempotencyKey, $request->header('X-Request-Id'), [
            'order_id' => $orderId,
            'tenant_id' => $tenant['tenant_id'],
            'customer_id' => $customer->customerId(),
            'game_id' => $gameId,
            'amount' => $totalAmount,
            'currency' => 'THB',
            'ticket_ids' => $ticketIds,
        ]);

        $this->insertOutboxEvent('stock.sold.v1', (string) $tenant['tenant_id'], (string) $tenant['partner_id'], $gameId, 'order', $orderId, $idempotencyKey, $request->header('X-Request-Id'), [
            'order_id' => $orderId,
            'tenant_id' => $tenant['tenant_id'],
            'partner_id' => $tenant['partner_id'],
            'game_id' => $gameId,
            'items' => array_map(function (object $stock, int $index) use ($tickets, $soldAt): array {
                return [
                    'stock_item_id' => (string) $stock->stock_item_id,
                    'local_stock_item_id' => (string) $stock->id,
                    'ticket_id' => $tickets[$index]['id'],
                    'sold_at' => $soldAt,
                ];
            }, $stockRows, array_keys($stockRows)),
        ]);

        $this->insertOutboxEvent('stock.unavailable.v1', (string) $tenant['tenant_id'], (string) $tenant['partner_id'], $gameId, 'order', $orderId, $idempotencyKey, $request->header('X-Request-Id'), [
            'tenant_id' => $tenant['tenant_id'],
            'game_id' => $gameId,
            'local_stock_item_ids' => array_map(fn (object $stock): string => (string) $stock->id, $stockRows),
            'reason' => 'reserved_or_sold',
        ]);

        if ($ledger !== null) {
            $this->insertOutboxEvent('wallet.updated.v1', (string) $tenant['tenant_id'], (string) $tenant['partner_id'], null, 'wallet', $ledger['wallet_id'], $idempotencyKey, $request->header('X-Request-Id'), [
                'tenant_id' => $tenant['tenant_id'],
                'customer_id' => $customer->customerId(),
                'wallet_id' => $ledger['wallet_id'],
                'ledger_id' => $ledger['id'],
                'entry_type' => 'debit',
                'amount' => $totalAmount,
                'currency' => 'THB',
                'posted_balance' => $ledger['balance_after'],
            ]);
        }
    }

    /**
     * @return array<int, object>
     */
    private function checkoutReservationIds(array $payload): array
    {
        $ids = is_array($payload['reservation_ids'] ?? null) ? $payload['reservation_ids'] : [];

        if (array_values(array_filter($ids, fn (mixed $id): bool => trim((string) $id) !== '')) === []) {
            $ids = [$payload['reservation_id'] ?? null];
        }

        return array_values(array_unique(array_values(array_filter(
            array_map(fn (mixed $id): string => trim((string) $id), $ids),
            fn (string $id): bool => $id !== '',
        ))));
    }

    /**
     * @param string|array<int, string> $reservationIds
     * @return array<int, object>
     */
    private function lockedReservationStockRows(string|array $reservationIds, string $tenantId): array
    {
        $ids = is_array($reservationIds) ? array_values($reservationIds) : [$reservationIds];

        return StockReservationItem::query()
            ->join('local_stock_items', 'local_stock_items.id', '=', 'stock_reservation_items.local_stock_item_id')
            ->where('stock_reservation_items.tenant_id', $tenantId)
            ->whereIn('stock_reservation_items.reservation_id', $ids)
            ->where('stock_reservation_items.status', 'active')
            ->whereNotNull('local_stock_items.virtual_stock_ref')
            ->orderBy('stock_reservation_items.reservation_id')
            ->orderBy('local_stock_items.id')
            ->select(
                'local_stock_items.*',
                'stock_reservation_items.reservation_id as reservation_item_reservation_id',
                'stock_reservation_items.price_amount as reservation_price_amount',
                'stock_reservation_items.currency as reservation_currency',
                'stock_reservation_items.sale_price_rule_snapshot_json as reservation_sale_price_rule_snapshot_json',
            )
            ->lockForUpdate()
            ->get()
            ->all();
    }

    /**
     * @param array<int, string> $reservationIds
     * @return array<int, object>
     */
    private function reservationStockRowsForPricing(array $reservationIds, string $tenantId): array
    {
        $ids = array_values(array_filter($reservationIds, fn (string $id): bool => $id !== ''));

        if ($ids === []) {
            return [];
        }

        return StockReservationItem::query()
            ->join('local_stock_items', 'local_stock_items.id', '=', 'stock_reservation_items.local_stock_item_id')
            ->where('stock_reservation_items.tenant_id', $tenantId)
            ->whereIn('stock_reservation_items.reservation_id', $ids)
            ->where('stock_reservation_items.status', 'active')
            ->whereNotNull('local_stock_items.virtual_stock_ref')
            ->orderBy('stock_reservation_items.reservation_id')
            ->orderBy('local_stock_items.id')
            ->select(
                'local_stock_items.*',
                'stock_reservation_items.reservation_id as reservation_item_reservation_id',
                'stock_reservation_items.price_amount as reservation_price_amount',
                'stock_reservation_items.currency as reservation_currency',
                'stock_reservation_items.sale_price_rule_snapshot_json as reservation_sale_price_rule_snapshot_json',
            )
            ->get()
            ->all();
    }

    /**
     * @param array<string, mixed> $metadata
     * @return array{id: string, wallet_id: string, balance_after: int}
     */
    public function postLedger(string $tenantId, string $walletId, string $customerId, string $entryType, int $amount, string $referenceType, string $referenceId, string $idempotencyKey, ?string $adminId = null, array $metadata = []): array
    {
        $existing = WalletLedger::query()
            ->where('tenant_id', $tenantId)
            ->where('wallet_id', $walletId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($existing !== null) {
            return [
                'id' => (string) $existing->id,
                'wallet_id' => (string) $existing->wallet_id,
                'balance_after' => (int) $existing->balance_after,
            ];
        }

        $wallet = Wallet::query()->where('tenant_id', $tenantId)->where('id', $walletId)->lockForUpdate()->first();
        $signedAmount = in_array($entryType, ['debit', 'hold'], true) ? -abs($amount) : $amount;
        $balanceAfter = (int) $wallet->balance_amount + $signedAmount;
        $ledgerId = 'wle_'.Str::ulid()->toBase32();

        WalletLedger::query()->insert([
            'id' => $ledgerId,
            'tenant_id' => $tenantId,
            'wallet_id' => $walletId,
            'customer_id' => $customerId,
            'entry_type' => $entryType,
            'status' => 'posted',
            'amount' => $signedAmount,
            'currency' => 'THB',
            'balance_after' => $balanceAfter,
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
            'idempotency_key' => $idempotencyKey,
            'created_by_admin_id' => $adminId,
            'metadata_json' => $metadata === [] ? null : json_encode($metadata, JSON_THROW_ON_ERROR),
            'posted_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        Wallet::query()->where('id', $walletId)->update([
            'balance_amount' => $balanceAfter,
            'updated_at' => now(),
        ]);

        return [
            'id' => $ledgerId,
            'wallet_id' => $walletId,
            'balance_after' => $balanceAfter,
        ];
    }

    private function finalizeExternalPayment(object $payment, Request $request): void
    {
        $payment = Payment::query()->where('id', $payment->id)->lockForUpdate()->first();

        if ($payment === null || $payment->status === 'succeeded' || $payment->order_id === null) {
            return;
        }

        $order = Order::query()->where('id', $payment->order_id)->lockForUpdate()->first();

        if ($order === null || $order->status === 'paid') {
            return;
        }

        $tenant = PartnerTenant::where('id', $order->tenant_id)->first();
        $reservation = StockReservation::query()->where('id', $order->reservation_id)->lockForUpdate()->first();
        $stockRows = $this->lockedReservationStockRows((string) $order->reservation_id, (string) $order->tenant_id);
        $customer = new CustomerSessionContext(
            session: ['tenant_id' => (string) $order->tenant_id, 'customer_id' => (string) $order->customer_id],
            customer: ['id' => (string) $order->customer_id, 'tenant_id' => (string) $order->tenant_id],
        );

        $pricing = $this->salePrices->allocatePricesForStockRows((string) $order->tenant_id, $stockRows);
        $tickets = $this->createSoldOrderItemsAndTickets((string) $order->tenant_id, $customer, (string) $order->id, $stockRows, $pricing, now());
        Order::query()->where('id', $order->id)->update([
            'status' => 'paid',
            'payment_status' => 'paid',
            'paid_at' => now(),
            'updated_at' => now(),
        ]);
        Payment::query()->where('id', $payment->id)->update([
            'status' => 'succeeded',
            'paid_at' => now(),
            'updated_at' => now(),
        ]);
        StockReservation::query()->where('id', $reservation->id)->update([
            'status' => 'converted',
            'converted_at' => now(),
            'updated_at' => now(),
        ]);
        StockReservationItem::query()->where('reservation_id', $reservation->id)->update(['status' => 'converted', 'updated_at' => now()]);
        LocalStockItem::query()->whereIn('id', array_map(fn (object $stock): string => (string) $stock->id, $stockRows))->update(['status' => 'sold', 'sold_at' => now(), 'updated_at' => now()]);
        $this->virtualStock->convertReservedRowsToSold(
            stockRows: $stockRows,
            tenantId: (string) $order->tenant_id,
            partnerId: (string) $tenant->partner_id,
            gameId: (string) $order->game_id,
            customerId: (string) $order->customer_id,
        );

        $this->insertPaidOrderEvents(
            ['tenant_id' => (string) $order->tenant_id, 'partner_id' => (string) $tenant->partner_id],
            $customer,
            (string) $order->id,
            (string) $order->game_id,
            $stockRows,
            $tickets,
            (int) $order->total_amount,
            null,
            (string) $payment->reference,
            $request,
        );
        $this->calculateAffiliateCommissionForOrder((string) $order->id, (string) $order->tenant_id);
    }

    private function calculateAffiliateCommissionForOrder(string $orderId, string $tenantId): void
    {
        try {
            $this->growth->calculateCommissions($orderId, $tenantId, 1);
        } catch (\Throwable $exception) {
            report($exception);
        }
    }

    private function finalizeCreditTopup(object $topup, Request $request): void
    {
        $topup = TopupRequest::query()->where('id', $topup->id)->lockForUpdate()->first();

        if ($topup === null || $topup->status === 'succeeded') {
            return;
        }

        $ledger = $this->postLedger((string) $topup->tenant_id, (string) $topup->wallet_id, (string) $topup->customer_id, 'credit', (int) $topup->amount, 'topup_webhook', (string) $topup->id, 'webhook-'.$topup->id);
        TopupRequest::query()->where('id', $topup->id)->update(['status' => 'succeeded', 'reviewed_at' => now(), 'updated_at' => now()]);
        Payment::query()->where('id', $topup->payment_id)->update(['status' => 'succeeded', 'paid_at' => now(), 'updated_at' => now()]);
        $this->insertOutboxEvent('wallet.updated.v1', (string) $topup->tenant_id, null, null, 'wallet', (string) $topup->wallet_id, 'webhook-'.$topup->id, $request->header('X-Request-Id'), [
            'tenant_id' => (string) $topup->tenant_id,
            'customer_id' => (string) $topup->customer_id,
            'wallet_id' => (string) $topup->wallet_id,
            'ledger_id' => $ledger['id'],
            'entry_type' => 'credit',
            'amount' => (int) $topup->amount,
            'currency' => 'THB',
            'posted_balance' => $ledger['balance_after'],
        ]);
        $this->queueTopupUpdatedBroadcast((string) $topup->tenant_id, (string) $topup->id);
    }

    private function paymentForWebhook(string $domain, string $provider, array $payload): ?object
    {
        if ($domain !== 'payments') {
            return null;
        }

        $reference = (string) ($payload['reference'] ?? data_get($payload, 'payload.reference', ''));

        if ($reference === '') {
            return null;
        }

        return Payment::where('provider', $provider)->where('reference', $reference)->first()
            ?? Payment::where('reference', $reference)->first();
    }

    private function topupForWebhook(string $domain, string $provider, array $payload, ?object $payment): ?object
    {
        if ($domain !== 'topups') {
            return null;
        }

        if ($payment !== null && $payment->topup_request_id !== null) {
            return TopupRequest::where('id', $payment->topup_request_id)->first();
        }

        $reference = (string) ($payload['reference'] ?? data_get($payload, 'payload.reference', ''));

        if ($reference === '') {
            return null;
        }

        return TopupRequest::where('reference', $reference)->first();
    }

    private function webhookCallbackKey(array $payload): string
    {
        foreach (['id', 'reference', 'event'] as $field) {
            if (($payload[$field] ?? null) !== null && trim((string) $payload[$field]) !== '') {
                return trim((string) $payload[$field]);
            }
        }

        return hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
    }

    private function webhookIsSuccessful(array $payload): bool
    {
        $status = strtolower((string) ($payload['status'] ?? $payload['event'] ?? data_get($payload, 'payload.status', '')));

        return in_array($status, ['success', 'succeeded', 'paid', 'payment.succeeded', 'topup.succeeded'], true);
    }

    private function insertOutboxEvent(string $eventType, string $tenantId, ?string $partnerId, ?string $gameId, string $aggregateType, string $aggregateId, ?string $idempotencyKey, ?string $correlationId, array $payload): void
    {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => $eventType,
            'event_version' => 1,
            'producer' => 'partner_store',
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'game_id' => $gameId,
            'aggregate_type' => $aggregateType,
            'aggregate_id' => $aggregateId,
            'idempotency_key' => $idempotencyKey,
            'correlation_id' => $correlationId,
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function reservationResource(object $reservation, ?array $cartPricing = null): array
    {
        $items = StockReservationItem::query()
            ->join('local_stock_items', 'local_stock_items.id', '=', 'stock_reservation_items.local_stock_item_id')
            ->where('stock_reservation_items.reservation_id', $reservation->id)
            ->whereNotNull('local_stock_items.virtual_stock_ref')
            ->orderBy('local_stock_items.id')
            ->select(
                'local_stock_items.*',
                'stock_reservation_items.price_amount as reservation_price_amount',
                'stock_reservation_items.currency as reservation_currency',
                'stock_reservation_items.sale_price_rule_snapshot_json as reservation_sale_price_rule_snapshot_json',
            )
            ->get()
            ->all();

        $pricing = $cartPricing ?? $this->salePrices->pricesForReservationStockRows((string) $reservation->tenant_id, $items);
        $reservationTotal = array_sum(array_map(
            fn (object $stock): int => (int) ($pricing['items'][(string) $stock->id]['amount'] ?? 0),
            $items,
        ));

        return [
            'id' => (string) $reservation->id,
            'game_id' => (string) $reservation->game_id,
            'status' => (string) $reservation->status,
            'expires_at' => $this->dateTimeIso($reservation->expires_at),
            'expires_in_seconds' => $this->remainingSeconds($reservation->expires_at),
            'server_time' => now()->toISOString(),
            'items' => array_map(fn (object $stock): array => $this->localStockResource($stock, $pricing['items'][(string) $stock->id] ?? null), $items),
            'total' => $this->money((int) $reservationTotal, (string) $pricing['currency']),
        ];
    }

    private function dateTimeIso(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return Carbon::parse((string) $value)->toISOString();
    }

    private function remainingSeconds(mixed $expiresAt): int
    {
        if ($expiresAt === null || $expiresAt === '') {
            return 0;
        }

        return max(0, Carbon::parse((string) $expiresAt)->getTimestamp() - now()->getTimestamp());
    }

    private function orderResource(object $order): array
    {
        $tickets = Ticket::query()->where('order_id', $order->id)->orderBy('id')->get()->all();
        $wallet = $order->wallet_id === null ? null : Wallet::where('id', $order->wallet_id)->first();
        $payment = Payment::where('order_id', $order->id)->first();

        return [
            'id' => (string) $order->id,
            'status' => (string) $order->status,
            'total' => $this->money((int) $order->total_amount, (string) $order->currency),
            'redirect_url' => $payment?->redirect_url,
            'tickets' => array_map(fn (object $ticket): array => $this->ticketResource($ticket), $tickets),
            'paid_at' => $order->paid_at,
            'reference' => $order->reference,
            'wallet' => $wallet === null ? null : $this->walletResource($wallet),
            'store' => null,
        ];
    }

    private function adminOrderSummaryResource(object $order): array
    {
        $customer = Customer::where('id', $order->customer_id)->first();

        return [
            'id' => (string) $order->id,
            'tenant_id' => (string) $order->tenant_id,
            'reference' => $order->reference,
            'status' => (string) $order->status,
            'payment_status' => (string) $order->payment_status,
            'total' => $this->money((int) $order->total_amount, (string) $order->currency),
            'ticket_count' => Ticket::where('order_id', $order->id)->count(),
            'customer' => $customer === null ? null : $this->customerProfile($customer),
            'store' => null,
            'game_id' => $order->game_id,
            'created_at' => $order->created_at,
            'paid_at' => $order->paid_at,
        ];
    }

    private function adminOrderDetailResource(object $order): array
    {
        return $this->adminOrderSummaryResource($order) + [
            'tickets' => array_map(fn (object $ticket): array => $this->ticketResource($ticket), Ticket::query()->where('order_id', $order->id)->orderBy('id')->get()->all()),
            'wallet' => $order->wallet_id === null ? null : $this->walletResource(Wallet::where('id', $order->wallet_id)->first()),
            'payment' => (array) (Payment::where('order_id', $order->id)->first() ?? []),
            'admin_note' => $order->admin_note,
            'audit' => [],
        ];
    }

    private function topupResource(object $topup): array
    {
        $payment = $topup->payment_id === null ? null : Payment::where('id', $topup->payment_id)->first();

        return [
            'id' => (string) $topup->id,
            'amount' => $this->money((int) $topup->amount, (string) $topup->currency),
            'bonus_amount' => $this->money((int) $topup->bonus_amount, (string) $topup->currency),
            'status' => $this->topupPresentationStatus($topup),
            'transfer_at' => $topup->transfer_at,
            'created_at' => $topup->created_at,
            'slip' => $this->topupSlipResource($topup),
            'slip_url' => PublicUrl::normalizeAssetUrl($topup->slip_url ?? null),
            'slip_thumb_url' => PublicUrl::normalizeAssetUrl($topup->slip_thumb_url ?? null),
            'payment' => [
                'qr_code' => in_array((string) $topup->channel, ['qr', 'credit_card'], true) ? 'stub-qr-'.$topup->reference : null,
                'redirect_url' => $payment?->redirect_url,
                'message' => null,
            ],
        ];
    }

    private function adminTopupSummaryResource(object $topup): array
    {
        $customer = Customer::where('id', $topup->customer_id)->first();

        return $this->topupResource($topup) + [
            'tenant_id' => (string) $topup->tenant_id,
            'reference' => $topup->reference,
            'channel' => (string) $topup->channel,
            'customer' => $customer === null ? null : $this->customerProfile($customer),
            'reviewed_at' => $topup->reviewed_at,
            'reviewed_by_admin_id' => $topup->reviewed_by_admin_id,
        ];
    }

    private function adminTopupDetailResource(object $topup): array
    {
        return $this->adminTopupSummaryResource($topup) + [
            'wallet' => $this->walletResource(Wallet::where('id', $topup->wallet_id)->first()),
            'slip_url' => PublicUrl::normalizeAssetUrl($topup->slip_url ?? null),
            'slip_thumb_url' => PublicUrl::normalizeAssetUrl($topup->slip_thumb_url ?? null),
            'slip_expires_at' => $topup->slip_expires_at,
            'provider_payload' => $this->decodeJsonObject($topup->provider_payload_json),
            'admin_note' => $topup->admin_note,
            'audit' => [],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantTopupBank(string $tenantId): array
    {
        $settings = TenantPaymentSetting::query()->forTenant($tenantId)->first();
        $config = is_array($settings?->config_json) ? $settings->config_json : [];
        $bankConfig = is_array($config['bank_transfer'] ?? null) ? $config['bank_transfer'] : $config;
        $bankCode = trim((string) ($bankConfig['bank_code'] ?? ''));
        $bankName = trim((string) ($bankConfig['bank_name'] ?? ''));
        $catalogBank = ThaiBankCatalog::findByCodeOrName($bankCode !== '' ? $bankCode : $bankName);
        $name = $catalogBank['name'] ?? ($bankName !== '' ? $bankName : 'ธนาคารกสิกรไทย');
        $code = $catalogBank['code'] ?? ($bankCode !== '' ? $bankCode : 'kbank');
        $icon = (string) ($bankConfig['bank_icon'] ?? ($catalogBank['icon'] ?? 'bi-bank'));
        $accountName = (string) ($bankConfig['account_name'] ?? 'Tenant Wallet');
        $accountNumber = (string) ($bankConfig['account_number'] ?? '000-000-0000');

        return [
            'bank_code' => $code,
            'bank_name' => $name,
            'bank_icon' => $icon,
            'account_name' => $accountName,
            'account_number' => $accountNumber,
            'bank_deposit_name' => $accountName,
            'bank_deposit_number' => $accountNumber,
            'bank' => [
                'code' => $code,
                'name' => $name,
                'icon' => $icon,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function topupSlipResource(object $topup): ?array
    {
        $url = PublicUrl::normalizeAssetUrl($topup->slip_url ?? null);

        if ($url === null) {
            return null;
        }

        return [
            'url' => $url,
            'full_url' => $url,
            'thumb_url' => PublicUrl::normalizeAssetUrl($topup->slip_thumb_url ?? null) ?? $url,
            'expires_at' => $topup->slip_expires_at,
        ];
    }

    /**
     * @return array{bytes: string, thumb_bytes: string, checksum: string, source_name: string, source_type: string}|array{error: string}|null
     */
    private function topupSlipUpload(?UploadedFile $file): ?array
    {
        if (! $file instanceof UploadedFile) {
            return null;
        }

        if (! $file->isValid()) {
            return ['error' => 'validation_failed'];
        }

        $mime = (string) ($file->getMimeType() ?: $file->getClientMimeType());
        if (! in_array($mime, ['image/webp', 'image/png', 'image/jpeg'], true)) {
            return ['error' => 'validation_failed'];
        }

        if ((int) $file->getSize() > 5 * 1024 * 1024) {
            return ['error' => 'validation_failed'];
        }

        $sourceBytes = file_get_contents($file->getRealPath()) ?: '';
        $fullBytes = $this->topupSlipWebpBytes($sourceBytes, null, 82)
            ?? ($mime === 'image/webp' ? $sourceBytes : null);
        $thumbBytes = $this->topupSlipWebpBytes($sourceBytes, 360, 72)
            ?? $fullBytes;

        if ($fullBytes === null || $fullBytes === '') {
            return ['error' => 'validation_failed'];
        }

        return [
            'bytes' => $fullBytes,
            'thumb_bytes' => $thumbBytes,
            'checksum' => hash('sha256', $sourceBytes),
            'source_name' => (string) $file->getClientOriginalName(),
            'source_type' => $mime,
        ];
    }

    /**
     * @param array{bytes: string, thumb_bytes: string, checksum: string, source_name: string, source_type: string} $slip
     * @return array{url: string, thumb_url: string, storage_path: string, thumb_storage_path: string, expires_at: Carbon}
     */
    private function storeTopupSlipAsset(string $tenantId, string $topupId, array $slip): array
    {
        $token = Str::lower(Str::ulid()->toBase32());
        $basePath = 'tenants/'.$tenantId.'/topup-slips';
        $storagePath = $basePath.'/'.$topupId.'-'.$token.'.webp';
        $thumbStoragePath = $basePath.'/'.$topupId.'-'.$token.'-thumb.webp';
        $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));

        $disk->put($storagePath, $slip['bytes'], ['ContentType' => 'image/webp']);
        $disk->put($thumbStoragePath, $slip['thumb_bytes'], ['ContentType' => 'image/webp']);

        return [
            'url' => PublicUrl::asset($storagePath),
            'thumb_url' => PublicUrl::asset($thumbStoragePath),
            'storage_path' => $storagePath,
            'thumb_storage_path' => $thumbStoragePath,
            'expires_at' => now()->addDays(30),
        ];
    }

    private function topupSlipWebpBytes(string $sourceBytes, ?int $maxWidth, int $quality): ?string
    {
        if (! extension_loaded('gd') || ! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) {
            return null;
        }

        $source = @imagecreatefromstring($sourceBytes);

        if ($source === false) {
            return null;
        }

        $target = $source;

        try {
            imagepalettetotruecolor($source);
            imagealphablending($source, true);
            imagesavealpha($source, true);

            $width = imagesx($source);
            $height = imagesy($source);

            if ($maxWidth !== null && $width > $maxWidth) {
                $targetHeight = max(1, (int) round($height * ($maxWidth / $width)));
                $target = imagecreatetruecolor($maxWidth, $targetHeight);
                imagealphablending($target, true);
                imagesavealpha($target, true);
                imagecopyresampled($target, $source, 0, 0, 0, 0, $maxWidth, $targetHeight, $width, $height);
            }

            ob_start();
            $ok = imagewebp($target, null, $quality);
            $bytes = ob_get_clean();

            return $ok && is_string($bytes) && $bytes !== '' ? $bytes : null;
        } finally {
            if ($target !== $source) {
                imagedestroy($target);
            }

            imagedestroy($source);
        }
    }

    private function walletResource(?object $wallet): ?array
    {
        if ($wallet === null) {
            return null;
        }

        return [
            'id' => (string) $wallet->id,
            'name' => (string) $wallet->name,
            'type' => (string) $wallet->type,
            'balance' => $this->money((int) $wallet->balance_amount, (string) $wallet->currency),
        ];
    }

    private function adminWalletResource(object $wallet): array
    {
        $customer = $wallet->relationLoaded('customer')
            ? $wallet->customer
            : Customer::query()->forTenant((string) $wallet->tenant_id)->where('id', $wallet->customer_id)->first();

        return $this->walletResource($wallet) + [
            'tenant_id' => (string) $wallet->tenant_id,
            'customer_id' => (string) $wallet->customer_id,
            'customer_no' => $customer === null
                ? CustomerNo::legacyMemberNo((string) $wallet->customer_id)
                : CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'member_no' => $customer === null
                ? CustomerNo::legacyMemberNo((string) $wallet->customer_id)
                : CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'customer_name' => (string) ($customer->name ?? ''),
            'customer' => $customer === null ? null : [
                'id' => (string) $customer->id,
                'customer_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
                'member_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
                'name' => (string) $customer->name,
                'phone' => (string) $customer->phone,
                'email' => $customer->email,
                'status' => (string) $customer->status,
            ],
            'status' => (string) $wallet->status,
            'created_at' => $wallet->created_at,
            'updated_at' => $wallet->updated_at,
        ];
    }

    private function ledgerResource(object $ledger): array
    {
        $metadata = is_array($ledger->metadata_json)
            ? $ledger->metadata_json
            : (is_string($ledger->metadata_json) && $ledger->metadata_json !== '' ? json_decode($ledger->metadata_json, true) : []);
        $metadata = is_array($metadata) ? $metadata : [];
        $reason = (string) ($metadata['reason'] ?? $metadata['note'] ?? '');

        return [
            'id' => (string) $ledger->id,
            'tenant_id' => (string) $ledger->tenant_id,
            'wallet_id' => (string) $ledger->wallet_id,
            'customer_id' => (string) $ledger->customer_id,
            'entry_type' => (string) $ledger->entry_type,
            'status' => (string) $ledger->status,
            'amount' => $this->money((int) $ledger->amount, (string) $ledger->currency),
            'balance_after' => $this->money((int) $ledger->balance_after, (string) $ledger->currency),
            'reason' => $reason,
            'reference_type' => $ledger->reference_type,
            'reference_id' => $ledger->reference_id,
            'created_at' => $ledger->created_at,
        ];
    }

    private function ticketResource(object $ticket): array
    {
        $image = $this->ticketImageResource($ticket);
        $rewardStatus = $this->ticketRewardStatusResource($ticket);

        return [
            'id' => (string) $ticket->id,
            'game_id' => (string) $ticket->game_id,
            'full_number' => (string) $ticket->full_number,
            'status' => $this->customerVisibleTicketStatus((string) $ticket->status, $rewardStatus),
            'reward_status' => $rewardStatus,
            'prize_type' => $rewardStatus['prize_type'] ?? null,
            'prize_number' => $rewardStatus['prize_number'] ?? null,
            'prize_amount' => $rewardStatus['prize_amount'] ?? null,
            'claimable' => $rewardStatus['claimable'] ?? false,
            'image_thumb_url' => $image['image_thumb_url'],
            'image_url' => $image['image_url'],
            'preview_image_url' => $image['preview_image_url'],
            'image_status' => $image['image_status'],
            'image_error' => $image['image_error'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function ticketRewardStatusResource(object $ticket): array
    {
        $winning = DB::table('winning_tickets')
            ->join('reward_results', 'reward_results.id', '=', 'winning_tickets.reward_result_id')
            ->where('winning_tickets.tenant_id', (string) $ticket->tenant_id)
            ->where('winning_tickets.ticket_id', (string) $ticket->id)
            ->select([
                'winning_tickets.id',
                'winning_tickets.reward_result_id',
                'winning_tickets.prize_type',
                'winning_tickets.prize_number',
                'winning_tickets.amount',
                'winning_tickets.currency',
                'winning_tickets.status',
                'reward_results.status as reward_result_status',
            ])
            ->orderByDesc('winning_tickets.created_at')
            ->first();
        $claim = DB::table('reward_claims')
            ->where('tenant_id', (string) $ticket->tenant_id)
            ->where('ticket_id', (string) $ticket->id)
            ->orderByDesc('created_at')
            ->first();

        if ($claim !== null) {
            return [
                'ticket_id' => (string) $ticket->id,
                'status' => (string) $claim->status,
                'claimable' => false,
                'prize_type' => $winning?->prize_type,
                'prize_number' => $winning?->prize_number,
                'prize_amount' => $this->money((int) $claim->prize_amount, (string) $claim->currency),
                'reward_result_id' => $winning?->reward_result_id,
                'reward_claim_id' => (string) $claim->id,
            ];
        }

        if ($winning !== null && in_array((string) $winning->reward_result_status, ['verified', 'published'], true)) {
            return [
                'ticket_id' => (string) $ticket->id,
                'status' => 'winning',
                'claimable' => (string) $winning->reward_result_status === 'published' && in_array((string) $winning->status, ['pending', 'verified'], true),
                'prize_type' => (string) $winning->prize_type,
                'prize_number' => (string) $winning->prize_number,
                'prize_amount' => $this->money((int) $winning->amount, (string) $winning->currency),
                'reward_result_id' => (string) $winning->reward_result_id,
                'reward_claim_id' => null,
            ];
        }

        $published = DB::table('reward_results')
            ->where('game_id', (string) $ticket->game_id)
            ->where('status', 'published')
            ->exists();

        return [
            'ticket_id' => (string) $ticket->id,
            'status' => $published ? 'non_winning' : 'pending_result',
            'claimable' => false,
            'prize_type' => null,
            'prize_number' => null,
            'prize_amount' => null,
            'reward_result_id' => null,
            'reward_claim_id' => null,
        ];
    }

    /**
     * @param array<string, mixed> $rewardStatus
     */
    private function customerVisibleTicketStatus(string $ticketStatus, array $rewardStatus): string
    {
        $status = strtolower(trim($ticketStatus));
        $rewardStatusValue = strtolower(trim((string) ($rewardStatus['status'] ?? '')));

        if (in_array($rewardStatusValue, ['winning', 'claim_submitted', 'approved', 'claim_approved', 'paid', 'paid_out'], true)) {
            return in_array($rewardStatusValue, ['paid', 'paid_out'], true) ? 'paid_out' : 'winning';
        }

        if ($rewardStatusValue === 'non_winning') {
            return 'non_winning';
        }

        if (in_array($status, ['winning', 'non_winning', 'paid_out'], true)) {
            return 'reward_pending';
        }

        return $ticketStatus;
    }

    /**
     * @return array{image_url: ?string, image_thumb_url: ?string, preview_image_url: ?string, image_status: string, image_error: ?string}
     */
    private function ticketImageResource(object $ticket): array
    {
        $imageUrl = PublicUrl::normalizeAssetUrl($ticket->image_url ?? null);
        $thumbUrl = PublicUrl::normalizeAssetUrl($ticket->image_thumb_url ?? null);
        $previewUrl = $thumbUrl;
        $status = ($imageUrl || $thumbUrl) ? 'ready' : 'missing';
        $error = null;

        if (! $thumbUrl && ! $imageUrl) {
            $stock = method_exists($ticket, 'relationLoaded') && $ticket->relationLoaded('localStockItem')
                ? $ticket->localStockItem
                : LocalStockItem::query()->whereKey((string) ($ticket->local_stock_item_id ?? ''))->first();

            if ($stock !== null && ($stock->virtual_stock_ref ?? null) !== null) {
                $thumbPreview = $this->virtualImages->previewDescriptor(
                    (string) $stock->tenant_id,
                    (string) $stock->partner_id,
                    (string) $stock->game_id,
                    (string) $stock->full_number,
                    (int) ($stock->virtual_copy_index ?? 0),
                    'thumb',
                );
                $fullPreview = $this->virtualImages->previewDescriptor(
                    (string) $stock->tenant_id,
                    (string) $stock->partner_id,
                    (string) $stock->game_id,
                    (string) $stock->full_number,
                    (int) ($stock->virtual_copy_index ?? 0),
                    'full',
                );
                $imageUrl = $fullPreview['url'];
                $thumbUrl = $thumbPreview['url'];
                $previewUrl = $thumbPreview['url'];
                $status = $imageUrl || $thumbUrl ? 'ready' : (string) ($fullPreview['status'] ?? $thumbPreview['status']);
                $error = $fullPreview['error'] ?: $thumbPreview['error'];
            }
        }

        if (! $thumbUrl && ! $imageUrl) {
            $snapshot = is_array($ticket->image_render_snapshot_json ?? null)
                ? $ticket->image_render_snapshot_json
                : [];
            $renderStatus = (string) ($snapshot['render_status'] ?? '');

            if ($renderStatus !== '') {
                $status = $renderStatus;
            }

            $error = $error ?: (($snapshot['render_error'] ?? null) === null ? null : (string) $snapshot['render_error']);
        }

        return [
            'image_url' => $imageUrl,
            'image_thumb_url' => $thumbUrl,
            'preview_image_url' => $previewUrl,
            'image_status' => $status,
            'image_error' => $error,
        ];
    }

    private function ticketDetailResource(object $ticket): array
    {
        return $this->ticketResource($ticket) + [
            'tenant_id' => (string) $ticket->tenant_id,
            'order' => $this->orderResource(Order::where('id', $ticket->order_id)->first()),
            'reward_status' => [
                'ticket_id' => (string) $ticket->id,
                'status' => 'pending_result',
                'claimable' => false,
            ],
            'history' => [],
        ];
    }

    private function localStockResource(object $stock, ?array $pricing = null): array
    {
        if ($pricing === null) {
            $price = $this->salePrices->effectivePrice((string) $stock->tenant_id, (string) $stock->game_id, 1);
            $pricing = [
                'amount' => (int) $price['amount'],
                'currency' => (string) $price['currency'],
                'summary' => $this->salePrices->summary($price),
            ];
        }

        return [
            'id' => (string) $stock->id,
            'game_id' => (string) $stock->game_id,
            'full_number' => (string) $stock->full_number,
            'front3' => $stock->front3,
            'back3' => $stock->back3,
            'back2' => $stock->back2,
            'status' => (string) $stock->status,
            'price' => $this->money((int) $pricing['amount'], (string) $pricing['currency']),
            'price_rule_summary' => $pricing['summary'] ?? null,
            'image_thumb_url' => PublicUrl::normalizeAssetUrl($stock->image_thumb_url ?? null),
            'image_url' => PublicUrl::normalizeAssetUrl($stock->image_url ?? null),
        ];
    }

    private function customerProfile(object $customer): array
    {
        return [
            'id' => (string) $customer->id,
            'tenant_id' => (string) $customer->tenant_id,
            'customer_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'member_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'name' => $customer->name,
            'phone' => $customer->phone,
            'email' => $customer->email ?? null,
            'status' => $customer->status ?? null,
            'avatar_url' => $customer->avatar_url ?? null,
        ];
    }

    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    private function moneyAmount(mixed $value, int $default): int
    {
        if (is_array($value) && isset($value['amount'])) {
            return (int) $value['amount'];
        }

        if (is_numeric($value)) {
            return (int) $value;
        }

        return $default;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function optionalAdminNote(array $payload): ?string
    {
        $reason = $payload['reason'] ?? null;

        if (! is_string($reason)) {
            return null;
        }

        $reason = trim($reason);

        return $reason === '' ? null : $reason;
    }

    private function queueTopupUpdatedBroadcast(string $tenantId, string $topupId): void
    {
        DB::afterCommit(function () use ($tenantId, $topupId): void {
            $topup = TopupRequest::query()
                ->forTenant($tenantId)
                ->where('id', $topupId)
                ->first();

            if ($topup === null) {
                return;
            }

            TopupUpdated::dispatch([
                'event_type' => 'topup.updated',
                'tenant_id' => $tenantId,
                'topup_id' => $topupId,
                'topup' => $this->adminTopupSummaryResource($topup),
                'updated_at' => now()->toISOString(),
            ]);

            CustomerTopupUpdated::dispatch([
                'event_type' => 'topup.updated',
                'tenant_id' => $tenantId,
                'customer_id' => (string) $topup->customer_id,
                'topup_id' => $topupId,
                'topup' => $this->topupResource($topup),
                'updated_at' => now()->toISOString(),
            ]);
        });
    }

    private function topupPresentationStatus(object $topup): string
    {
        return match ((string) $topup->status) {
            'pending' => $topup->channel === 'bank_transfer' ? 'pending_review' : 'pending_payment',
            'processing' => 'pending_payment',
            'succeeded' => 'approved',
            'failed', 'reversed' => 'rejected',
            'cancelled' => 'cancelled',
            'expired' => 'expired',
            default => 'pending_payment',
        };
    }

    /**
     * @return array<int, string>
     */
    private function storedTopupStatusesForPresentation(string $presentation): array
    {
        return match ($presentation) {
            'pending_payment' => ['pending', 'processing'],
            'pending_review' => ['pending'],
            'approved' => ['succeeded'],
            'rejected' => ['failed', 'reversed'],
            'cancelled' => ['cancelled'],
            'expired' => ['expired'],
            default => [$presentation],
        };
    }

    private function auditAdmin(AdminSessionContext $actor, Request $request, string $action, string $targetType, string $targetId, array $payload, string $tenantId): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            tenantId: $tenantId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, (int) $limit));
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJsonObject(mixed $json): array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function hashJsonValue(mixed $json): string
    {
        return hash('sha256', is_array($json) ? json_encode($json, JSON_THROW_ON_ERROR) : (string) $json);
    }
}
