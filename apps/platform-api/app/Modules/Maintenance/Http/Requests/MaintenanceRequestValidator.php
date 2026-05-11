<?php

namespace App\Modules\Maintenance\Http\Requests;

use App\Models\AdminUserRole;
use App\Models\Customer;
use App\Models\SupportImpersonationSession;

class MaintenanceRequestValidator
{
    private const MAINTENANCE_STATUSES = ['inactive', 'scheduled', 'active', 'ended', 'cancelled'];
    private const MAINTENANCE_MODES = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled'];
    private const BYPASS_ACTOR_TYPES = ['customer', 'tenant_admin', 'support_session'];
    private const BYPASS_FILTER_STATUSES = ['active', 'revoked', 'expired'];

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function maintenanceUpdateErrors(array $payload): array
    {
        $errors = [];

        foreach (['status', 'mode', 'reason'] as $field) {
            if ($this->blank($payload[$field] ?? null)) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (! $this->blank($payload['status'] ?? null) && ! in_array((string) $payload['status'], self::MAINTENANCE_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (! $this->blank($payload['mode'] ?? null) && ! in_array((string) $payload['mode'], self::MAINTENANCE_MODES, true)) {
            $errors['mode'][] = 'The mode field is invalid.';
        }

        $this->maxString($errors, $payload, 'reason', 1000);
        $this->maxString($errors, $payload, 'message', 1000);
        $this->maxString($errors, $payload, 'ticket_id', 128);

        foreach (['scheduled_start_at', 'expected_end_at'] as $field) {
            if (! $this->blank($payload[$field] ?? null) && strtotime((string) $payload[$field]) === false) {
                $errors[$field][] = 'The '.$field.' field must be a valid date-time.';
            }
        }

        if (array_key_exists('retry_after_seconds', $payload)) {
            $retryAfter = filter_var($payload['retry_after_seconds'], FILTER_VALIDATE_INT);

            if ($payload['retry_after_seconds'] !== null && ($retryAfter === false || $retryAfter < 0 || $retryAfter > 86400)) {
                $errors['retry_after_seconds'][] = 'The retry_after_seconds field must be between 0 and 86400.';
            }
        }

        foreach (['allowed_routes', 'blocked_route_patterns'] as $field) {
            if (array_key_exists($field, $payload) && ! $this->stringList($payload[$field])) {
                $errors[$field][] = 'The '.$field.' field must be an array of strings.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, array<int, string>>
     */
    public function filterErrors(array $query, bool $allowStatus = false): array
    {
        $errors = [];

        if ($allowStatus && ! $this->blank($query['status'] ?? null) && ! in_array((string) $query['status'], self::MAINTENANCE_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('limit', $query)) {
            $limit = filter_var($query['limit'], FILTER_VALIDATE_INT);

            if ($limit === false || $limit < 1 || $limit > 100) {
                $errors['limit'][] = 'The limit field must be between 1 and 100.';
            }
        }

        foreach (['cursor', 'status'] as $field) {
            $this->maxString($errors, $query, $field, 128);
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, array<int, string>>
     */
    public function maintenanceBypassFilterErrors(array $query): array
    {
        $errors = [];

        if (! $this->blank($query['status'] ?? null) && ! in_array((string) $query['status'], self::BYPASS_FILTER_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('limit', $query)) {
            $limit = filter_var($query['limit'], FILTER_VALIDATE_INT);

            if ($limit === false || $limit < 1 || $limit > 100) {
                $errors['limit'][] = 'The limit field must be between 1 and 100.';
            }
        }

        foreach (['cursor', 'status'] as $field) {
            $this->maxString($errors, $query, $field, 128);
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function maintenanceBypassCreateErrors(string $tenantId, array $payload): array
    {
        $errors = [];

        foreach (['actor_type', 'actor_id', 'reason', 'ticket_id'] as $field) {
            if ($this->blank($payload[$field] ?? null)) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (! $this->blank($payload['actor_type'] ?? null) && ! in_array((string) $payload['actor_type'], self::BYPASS_ACTOR_TYPES, true)) {
            $errors['actor_type'][] = 'The actor_type field is invalid.';
        }

        $this->maxString($errors, $payload, 'actor_id', 128);
        $this->maxString($errors, $payload, 'reason', 1000);
        $this->maxString($errors, $payload, 'ticket_id', 128);
        $this->maxString($errors, $payload, 'support_impersonation_session_id', 30);

        if (! $this->blank($payload['expires_at'] ?? null) && strtotime((string) $payload['expires_at']) === false) {
            $errors['expires_at'][] = 'The expires_at field must be a valid date-time.';
        }

        if (($payload['actor_type'] ?? null) === 'customer' && ! Customer::where('tenant_id', $tenantId)->where('id', (string) $payload['actor_id'])->exists()) {
            $errors['actor_id'][] = 'The actor_id field must reference a tenant customer.';
        }

        if (($payload['actor_type'] ?? null) === 'tenant_admin' && ! $this->tenantAdminExists($tenantId, (string) ($payload['actor_id'] ?? ''))) {
            $errors['actor_id'][] = 'The actor_id field must reference a tenant admin.';
        }

        if (($payload['actor_type'] ?? null) === 'support_session' && ! SupportImpersonationSession::where('tenant_id', $tenantId)->where('id', (string) $payload['actor_id'])->exists()) {
            $errors['actor_id'][] = 'The actor_id field must reference a tenant support session.';
        }

        return $errors;
    }

    /**
     * @param array<string, array<int, string>> $errors
     * @param array<string, mixed> $payload
     */
    private function maxString(array &$errors, array $payload, string $field, int $max): void
    {
        if (! array_key_exists($field, $payload) || $payload[$field] === null) {
            return;
        }

        if (! is_string($payload[$field]) || strlen($payload[$field]) > $max) {
            $errors[$field][] = 'The '.$field.' field must be a string of '.$max.' characters or fewer.';
        }
    }

    private function blank(mixed $value): bool
    {
        return $value === null || (is_string($value) && trim($value) === '');
    }

    private function stringList(mixed $value): bool
    {
        return is_array($value) && collect($value)->every(fn (mixed $item): bool => is_string($item));
    }

    private function tenantAdminExists(string $tenantId, string $adminUserId): bool
    {
        if ($adminUserId === '') {
            return false;
        }

        return AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->where('admin_scopes.scope_type', 'tenant')
            ->where('admin_scopes.tenant_id', $tenantId)
            ->exists();
    }
}
