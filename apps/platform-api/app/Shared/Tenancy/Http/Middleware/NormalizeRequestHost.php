<?php

namespace App\Shared\Tenancy\Http\Middleware;

use App\Shared\Tenancy\TenantHostNormalizer;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class NormalizeRequestHost
{
    public function handle(Request $request, Closure $next): Response
    {
        $host = (string) ($request->headers->get('host') ?: $request->server->get('HTTP_HOST', ''));
        $normalized = $this->normalizeWithPort($host);

        if ($normalized !== '') {
            $request->server->set('HTTP_HOST', $normalized);
            $request->headers->set('host', $normalized);
            $request->server->set('SERVER_NAME', preg_replace('/:\d+$/', '', $normalized) ?: $normalized);
        }

        return $next($request);
    }

    private function normalizeWithPort(string $host): string
    {
        $value = trim($host);

        if ($value === '' || str_starts_with($value, '[')) {
            return $value;
        }

        $port = '';

        if (preg_match('/:\d+$/', $value, $matches) === 1) {
            $port = $matches[0];
            $value = substr($value, 0, -strlen($port));
        }

        $normalized = TenantHostNormalizer::normalize($value);

        return $normalized === '' ? '' : $normalized.$port;
    }
}
