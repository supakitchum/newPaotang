<?php

namespace App\Http\Middleware;

use App\Auth\SupportActorContext;
use App\Auth\SupportJwtVerifier;
use App\Models\SupportActor;
use App\Models\SupportCategory;
use App\Models\SupportTenant;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateSupportActor
{
    public function __construct(private readonly SupportJwtVerifier $tokens)
    {
    }

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next, ?string $requiredType = null): Response
    {
        $token = trim((string) $request->bearerToken());
        if ($token === '') {
            return $this->error(401, 'support_authentication_required', 'Support authentication is required.');
        }

        try {
            $claims = $this->tokens->verify($token);
        } catch (\Throwable $exception) {
            return $this->error(401, 'invalid_support_token', $exception->getMessage());
        }

        if ($requiredType !== null && ($claims['actor_type'] ?? null) !== $requiredType) {
            return $this->error(403, 'support_permission_denied', 'This support endpoint is not available to this actor.');
        }

        $context = DB::transaction(function () use ($claims): SupportActorContext {
            $tenantId = trim((string) $claims['tenant_id']);
            $tenant = SupportTenant::query()->updateOrCreate(
                ['id' => $tenantId],
                [
                    'name' => trim((string) ($claims['tenant_name'] ?? '')) ?: $tenantId,
                    'locale' => trim((string) ($claims['locale'] ?? 'th-TH')) ?: 'th-TH',
                    'enabled' => (bool) ($claims['support_enabled'] ?? true),
                ],
            );

            DB::table('support_settings')->insertOrIgnore([
                'tenant_id' => $tenant->id,
                'enabled' => true,
                'default_agent_capacity' => max(1, (int) config('support.assignment.default_capacity', 3)),
                'max_attachments_per_message' => max(1, (int) config('support.attachments.max_files', 4)),
                'max_attachment_bytes' => max(1024, (int) config('support.attachments.max_bytes', 8388608)),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            SupportCategory::query()->firstOrCreate(
                [
                    'tenant_id' => $tenant->id,
                    'code' => 'other',
                ],
                [
                    'id' => 'scat_'.substr(hash('sha256', $tenant->id.':other'), 0, 20),
                    'name_json' => [
                        'th-TH' => 'อื่นๆ',
                        'en-US' => 'Other',
                    ],
                    'icon_key' => 'circle-help',
                    'is_fallback' => true,
                    'status' => 'active',
                    'sort_order' => 9999,
                ],
            );

            $actorType = (string) $claims['actor_type'];
            $externalId = trim((string) $claims['sub']);
            $actor = SupportActor::query()->firstOrCreate(
                [
                    'tenant_id' => $tenantId,
                    'actor_type' => $actorType,
                    'external_id' => $externalId,
                ],
                ['id' => 'sac_'.Str::ulid()->toBase32()],
            );
            $actor->fill([
                'display_name' => trim((string) ($claims['name'] ?? '')) ?: null,
                'member_code' => trim((string) ($claims['member_code'] ?? '')) ?: null,
                'status' => 'active',
                'permissions_json' => is_array($claims['permissions'] ?? null) ? $claims['permissions'] : [],
                'last_authenticated_at' => now(),
            ])->save();

            return new SupportActorContext($actor, $claims);
        });

        if (! (bool) SupportTenant::query()->whereKey($context->tenantId())->value('enabled')) {
            return $this->error(503, 'support_unavailable', 'Customer support is currently unavailable.');
        }
        if ($context->isCustomer() && ! (bool) DB::table('support_settings')
            ->where('tenant_id', $context->tenantId())
            ->value('enabled')) {
            return $this->error(503, 'support_unavailable', 'Customer support is currently unavailable.');
        }

        $request->attributes->set('support_actor', $context);

        return $next($request);
    }

    private function error(int $status, string $code, string $message): Response
    {
        return response()->json([
            'error' => ['code' => $code, 'message' => $message],
        ], $status);
    }
}
