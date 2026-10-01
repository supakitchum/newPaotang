<?php

namespace App\Modules\SupportAccess\Http\Requests;

use App\Models\AdminUserRole;
use App\Models\Customer;

class SupportAccessRequestValidator
{
    private const SUPPORT_TARGET_TYPES = ['customer', 'tenant_admin'];
    private const SUPPORT_SCOPES = ['customer_read', 'customer_limited_write', 'tenant_admin_read', 'tenant_admin_limited_write', 'elevated_action'];
    private const SUPPORT_STATUSES = ['draft', 'pending_approval', 'approved', 'denied', 'expired', 'revoked', 'completed'];

    /**
     * @param array<string, mixed> $query
     * @return array<string, array<int, string>>
     */
    public function filterErrors(array $query, bool $allowStatus = true): array
    {
        $errors = [];

        if ($allowStatus && ! $this->blank($query['status'] ?? null) && ! in_array((string) $query['status'], self::SUPPORT_STATUSES, true)) {
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
    public function supportCreateErrors(string $tenantId, array $payload): array
    {
        $errors = [];

        foreach (['target_user_id', 'target_user_type', 'scope', 'reason', 'ticket_id'] as $field) {
            if ($this->blank($payload[$field] ?? null)) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (! $this->blank($payload['target_user_type'] ?? null) && ! in_array((string) $payload['target_user_type'], self::SUPPORT_TARGET_TYPES, true)) {
            $errors['target_user_type'][] = 'The target_user_type field is invalid.';
        }

        if (! $this->blank($payload['scope'] ?? null) && ! in_array((string) $payload['scope'], self::SUPPORT_SCOPES, true)) {
            $errors['scope'][] = 'The scope field is invalid.';
        }

        $this->maxString($errors, $payload, 'target_user_id', 30);
        $this->maxString($errors, $payload, 'reason', 1000);
        $this->maxString($errors, $payload, 'ticket_id', 128);

        if (($payload['target_user_type'] ?? null) === 'customer' && ! Customer::where('tenant_id', $tenantId)->where('id', (string) $payload['target_user_id'])->exists()) {
            $errors['target_user_id'][] = 'The target_user_id field must reference a tenant customer.';
        }

        if (($payload['target_user_type'] ?? null) === 'tenant_admin' && ! $this->tenantAdminExists($tenantId, (string) ($payload['target_user_id'] ?? ''))) {
            $errors['target_user_id'][] = 'The target_user_id field must reference a tenant admin.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function reasonErrors(array $payload): array
    {
        $errors = [];

        if ($this->blank($payload['reason'] ?? null)) {
            $errors['reason'][] = 'The reason field is required.';
        }

        $this->maxString($errors, $payload, 'reason', 1000);

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function elevatedActionErrors(array $payload): array
    {
        $errors = $this->reasonErrors($payload);

        if ($this->blank($payload['action'] ?? null)) {
            $errors['action'][] = 'The action field is required.';
        }

        $this->maxString($errors, $payload, 'action', 128);

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
