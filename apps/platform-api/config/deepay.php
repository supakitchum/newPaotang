<?php

$trustedCallbackIps = array_values(array_filter(array_map(
    static fn (string $ip): string => trim($ip),
    explode(',', (string) env('DEEPAY_KBANK_CALLBACK_TRUSTED_IPS', '')),
)));

return [
    'callback_trusted_ips' => $trustedCallbackIps,
];
