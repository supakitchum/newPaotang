<?php

return [
    'errors' => [
        'authentication_required' => 'Authentication token is missing, invalid, expired, or revoked.',
        'permission_denied' => 'You do not have permission to perform this action.',
        'pin_setup_required' => 'A 6-digit customer PIN must be set before continuing.',
        'pin_required' => 'Customer PIN verification is required before continuing.',
        'pin_locked' => 'Customer PIN verification is temporarily locked. Please try again later.',
        'customer_suspended' => 'This customer account is suspended.',
        'pin_invalid' => 'The customer PIN is incorrect.',
        'resource_not_found' => 'The requested resource was not found.',
        'resource_conflict' => 'The resource conflicts with existing state.',
        'idempotency_conflict' => 'The idempotency key was already used with a different payload.',
        'reservation_unavailable' => 'The requested stock is no longer available.',
        'reservation_expired' => 'The reservation has expired.',
        'wallet_insufficient_balance' => 'The wallet balance is insufficient.',
        'maintenance_active' => 'Tenant maintenance is active.',
        'validation_failed' => 'The request payload is invalid.',
        'tenant_not_found' => 'Tenant domain was not found.',
        'domain_not_active' => 'Tenant domain is not active.',
        'tenant_inactive' => 'Tenant is not active.',
        'news_not_found' => 'News was not found.',
        'admin_session_replaced' => 'Another device signed in to this admin account. Please sign in again.',
        'admin_password_change_required' => 'You must change your password before using the Back Office.',
    ],
];
