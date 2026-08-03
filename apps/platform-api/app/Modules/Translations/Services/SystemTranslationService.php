<?php

namespace App\Modules\Translations\Services;

use App\Models\SystemLanguage;
use App\Models\SystemTranslationDeployRequest;
use App\Models\SystemTranslationDeployRequestItem;
use App\Models\SystemTranslationDraft;
use App\Models\SystemTranslationKey;
use App\Models\SystemTranslationPreviewSession;
use App\Models\SystemTranslationValue;
use App\Modules\Rbac\Events\AdminMenuBadgesUpdated;
use App\Modules\Translations\Support\BackOfficePhraseTranslations;
use App\Modules\Translations\Support\StaticTranslationCatalog;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SystemTranslationService
{
    private const SURFACES = ['customer', 'back-office', 'api'];

    /**
     * @return array{languages: array<int, array<string, mixed>>, synced: array<string, int>}
     */
    public function languages(): array
    {
        $this->ensureCatalogSeeded();

        return [
            'languages' => $this->languageRows(),
            'synced' => ['languages' => SystemLanguage::query()->count(), 'keys' => SystemTranslationKey::query()->count()],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function upsertLanguage(array $payload): array
    {
        $locale = self::normalizeLocale($payload['locale'] ?? null);
        if ($locale === null) {
            return ['error' => 'validation_failed', 'errors' => ['locale' => ['Locale is invalid.']]];
        }

        $now = now();
        $language = SystemLanguage::query()->updateOrCreate(
            ['locale' => $locale],
            [
                'id' => $this->stableId('lng', $locale),
                'name' => trim((string) ($payload['name'] ?? $locale)) ?: $locale,
                'native_name' => trim((string) ($payload['native_name'] ?? ($payload['name'] ?? $locale))) ?: $locale,
                'status' => in_array(($payload['status'] ?? 'active'), ['active', 'inactive'], true) ? (string) $payload['status'] : 'active',
                'is_default' => (bool) ($payload['is_default'] ?? false),
                'sort_order' => (int) ($payload['sort_order'] ?? 100),
                'updated_at' => $now,
            ],
        );

        if ((bool) $language->is_default) {
            SystemLanguage::query()
                ->where('id', '!=', $language->id)
                ->update(['is_default' => false, 'updated_at' => $now]);
        }

        Cache::forget('system_translation_languages');

        return ['resource' => ['language' => $this->serializeLanguage($language->fresh())]];
    }

    /**
     * @param array<string, mixed> $filters
     * @return array<string, mixed>
     */
    public function keys(array $filters): array
    {
        $this->ensureCatalogSeeded();

        $locale = self::normalizeLocale($filters['locale'] ?? null) ?? $this->defaultLocale();
        $surface = $this->normalizeSurface($filters['surface'] ?? null) ?? 'customer';
        $category = trim((string) ($filters['category'] ?? ''));
        $search = trim((string) ($filters['q'] ?? ''));
        $page = max(1, (int) ($filters['page'] ?? 1));
        $perPage = min(200, max(10, (int) ($filters['per_page'] ?? 25)));
        $language = $this->languageByLocale($locale);

        $query = SystemTranslationKey::query()
            ->with([
                'values' => fn ($relation) => $relation->where('language_id', $language->id),
                'drafts' => fn ($relation) => $relation->where('language_id', $language->id),
            ])
            ->where('surface', $surface)
            ->where('status', 'active');

        if ($category !== '') {
            $query->where('category', $category);
        }

        if ($search !== '') {
            $query->where(function ($inner) use ($search): void {
                $inner->where('translation_key', 'ilike', '%'.$search.'%')
                    ->orWhere('default_text', 'ilike', '%'.$search.'%')
                    ->orWhereHas('values', fn ($valueQuery) => $valueQuery->where('value', 'ilike', '%'.$search.'%'))
                    ->orWhereHas('drafts', fn ($draftQuery) => $draftQuery->where('value', 'ilike', '%'.$search.'%'));
            });
        }

        $total = (clone $query)->count();
        $lastPage = max(1, (int) ceil($total / $perPage));
        $page = min($page, $lastPage);
        $offset = ($page - 1) * $perPage;

        $rows = $query
            ->orderBy('category')
            ->orderBy('translation_key')
            ->offset($offset)
            ->limit($perPage)
            ->get()
            ->map(function (SystemTranslationKey $row): array {
                $published = $row->values->first();
                $draft = $row->drafts->first();

                return [
                    'id' => $row->id,
                    'key' => $row->translation_key,
                    'surface' => $row->surface,
                    'category' => $row->category,
                    'default_text' => $row->default_text,
                    'description' => $row->description,
                    'variables' => $this->decodeJson($row->variables_json),
                    'published_value' => $published?->value,
                    'published_at' => $published?->published_at?->toIso8601String(),
                    'draft_value' => $draft?->value,
                    'draft_status' => $draft?->status,
                    'draft_updated_at' => $draft?->updated_at?->toIso8601String(),
                    'validation_errors' => $this->validatePlaceholders((string) $row->default_text, (string) ($draft?->value ?? '')),
                ];
            })
            ->all();

        $categories = SystemTranslationKey::query()
            ->selectRaw('category, count(*) as total')
            ->where('surface', $surface)
            ->where('status', 'active')
            ->groupBy('category')
            ->orderBy('category')
            ->get()
            ->map(fn ($row): array => ['category' => $row->category, 'total' => (int) $row->total])
            ->all();

        return [
            'locale' => $locale,
            'surface' => $surface,
            'category' => $category ?: null,
            'categories' => $categories,
            'pagination' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => $lastPage,
                'from' => $total === 0 ? 0 : $offset + 1,
                'to' => min($total, $offset + count($rows)),
            ],
            'data' => $rows,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function saveDraft(string $keyId, array $payload, string $adminUserId): array
    {
        $this->ensureCatalogSeeded();

        $locale = self::normalizeLocale($payload['locale'] ?? null);
        $value = array_key_exists('value', $payload) ? (string) $payload['value'] : null;

        if ($locale === null || $value === null) {
            return ['error' => 'validation_failed', 'errors' => ['payload' => ['Locale and value are required.']]];
        }

        $language = $this->languageByLocale($locale);
        $key = SystemTranslationKey::query()->find($keyId);
        if (! $key instanceof SystemTranslationKey) {
            return ['error' => 'not_found'];
        }

        $draft = SystemTranslationDraft::query()->updateOrCreate(
            [
                'language_id' => $language->id,
                'translation_key_id' => $key->id,
            ],
            [
                'id' => $this->stableId('tdr', $language->id, $key->id),
                'value' => $value,
                'status' => 'draft',
                'updated_by_admin_id' => $adminUserId,
            ],
        );

        return [
            'resource' => [
                'draft' => [
                    'id' => $draft->id,
                    'key_id' => $key->id,
                    'value' => $draft->value,
                    'status' => $draft->status,
                    'validation_errors' => $this->validatePlaceholders((string) $key->default_text, (string) $draft->value),
                ],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createDeployRequest(array $payload, string $adminUserId): array
    {
        $this->ensureCatalogSeeded();

        $locale = self::normalizeLocale($payload['locale'] ?? null);
        $surface = $this->normalizeSurface($payload['surface'] ?? null);
        $category = trim((string) ($payload['category'] ?? ''));

        if ($locale === null || $surface === null || $category === '') {
            return ['error' => 'validation_failed', 'errors' => ['payload' => ['Locale, surface, and category are required.']]];
        }

        $language = $this->languageByLocale($locale);

        $draftRows = SystemTranslationKey::query()
            ->with([
                'values' => fn ($relation) => $relation->where('language_id', $language->id),
                'drafts' => fn ($relation) => $relation->where('language_id', $language->id),
            ])
            ->where('surface', $surface)
            ->where('category', $category)
            ->where('status', 'active')
            ->whereHas('drafts', fn ($relation) => $relation->where('language_id', $language->id))
            ->orderBy('translation_key')
            ->get()
            ->map(function (SystemTranslationKey $key): ?array {
                $draft = $key->drafts->first();
                $published = $key->values->first();
                if (! $draft instanceof SystemTranslationDraft) {
                    return null;
                }

                if ($published instanceof SystemTranslationValue && (string) $published->value === (string) $draft->value) {
                    return null;
                }

                return [
                    'key_id' => $key->id,
                    'translation_key' => $key->translation_key,
                    'default_text' => $key->default_text,
                    'variables_json' => $key->variables_json,
                    'current_value' => $published?->value,
                    'draft_value' => $draft->value,
                ];
            })
            ->filter()
            ->values();

        if ($draftRows->isEmpty()) {
            return ['error' => 'validation_failed', 'errors' => ['drafts' => ['No changed drafts found for this locale, surface, and category.']]];
        }

        $now = now();
        $request = null;

        DB::transaction(function () use ($draftRows, $language, $locale, $surface, $category, $adminUserId, $now, &$request): void {
            $request = SystemTranslationDeployRequest::query()->create([
                'id' => 'tdp_'.Str::ulid()->toBase32(),
                'language_id' => $language->id,
                'locale' => $locale,
                'surface' => $surface,
                'category' => $category,
                'status' => 'draft',
                'title' => sprintf('%s %s %s translations', $locale, $surface, $category),
                'summary_json' => ['changed_keys' => $draftRows->count()],
                'submitted_by_admin_id' => $adminUserId,
            ]);

            foreach ($draftRows as $row) {
                $validationErrors = $this->validatePlaceholders((string) $row['default_text'], (string) $row['draft_value']);

                SystemTranslationDeployRequestItem::query()->create([
                    'id' => 'tdi_'.Str::ulid()->toBase32(),
                    'deploy_request_id' => $request->id,
                    'translation_key_id' => $row['key_id'],
                    'current_value' => $row['current_value'],
                    'draft_value' => $row['draft_value'],
                    'variables_json' => $this->decodeJson($row['variables_json']),
                    'validation_errors_json' => $validationErrors,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        });

        return ['resource' => ['request' => $this->serializeRequest($request->fresh(['items.key']))]];
    }

    /**
     * @return array<string, mixed>
     */
    public function submitDeployRequest(string $requestId, string $adminUserId): array
    {
        $request = SystemTranslationDeployRequest::query()->with('items')->find($requestId);
        if (! $request instanceof SystemTranslationDeployRequest) {
            return ['error' => 'not_found'];
        }

        if (! in_array($request->status, ['draft', 'rejected'], true)) {
            return ['error' => 'validation_failed', 'errors' => ['status' => ['Only draft or rejected requests can be submitted.']]];
        }

        $errors = $request->items
            ->flatMap(fn (SystemTranslationDeployRequestItem $item) => $item->validation_errors_json ?: [])
            ->values()
            ->all();

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => ['variables' => $errors]];
        }

        $request->forceFill([
            'status' => 'submitted',
            'submitted_by_admin_id' => $adminUserId,
            'submitted_at' => now(),
            'reviewed_by_admin_id' => null,
            'reviewed_at' => null,
            'review_note' => null,
        ])->save();
        $this->queueCentralMenuBadgeBroadcast('translations');

        return ['resource' => ['request' => $this->serializeRequest($request->fresh(['items.key']))]];
    }

    /**
     * @return array<string, mixed>
     */
    public function cancelDeployRequest(string $requestId): array
    {
        $request = SystemTranslationDeployRequest::query()->find($requestId);
        if (! $request instanceof SystemTranslationDeployRequest) {
            return ['error' => 'not_found'];
        }

        if (! in_array($request->status, ['draft', 'rejected'], true)) {
            return ['error' => 'validation_failed', 'errors' => ['status' => ['Only draft or rejected requests can be cancelled.']]];
        }

        $request->forceFill(['status' => 'cancelled'])->save();

        return ['resource' => ['request' => $this->serializeRequest($request->fresh(['items.key']))]];
    }

    /**
     * @param array<string, mixed> $filters
     * @return array<string, mixed>
     */
    public function deployRequests(array $filters): array
    {
        $query = SystemTranslationDeployRequest::query()
            ->with(['items.key'])
            ->orderByDesc('created_at');

        if (($filters['status'] ?? null) !== null && trim((string) $filters['status']) !== '') {
            $query->where('status', trim((string) $filters['status']));
        }

        if (($filters['surface'] ?? null) !== null && $this->normalizeSurface($filters['surface']) !== null) {
            $query->where('surface', $this->normalizeSurface($filters['surface']));
        }

        return [
            'data' => $query->limit(100)->get()->map(fn (SystemTranslationDeployRequest $request): array => $this->serializeRequest($request))->all(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function previewSession(string $requestId, string $adminUserId): array
    {
        $request = SystemTranslationDeployRequest::query()->find($requestId);
        if (! $request instanceof SystemTranslationDeployRequest) {
            return ['error' => 'not_found'];
        }

        $token = Str::random(48);
        $session = SystemTranslationPreviewSession::query()->create([
            'id' => 'tps_'.Str::ulid()->toBase32(),
            'deploy_request_id' => $request->id,
            'token_hash' => hash('sha256', $token),
            'created_by_admin_id' => $adminUserId,
            'expires_at' => now()->addMinutes(30),
        ]);

        return [
            'resource' => [
                'preview' => [
                    'id' => $session->id,
                    'token' => $token,
                    'expires_at' => $session->expires_at?->toIso8601String(),
                    'locale' => $request->locale,
                    'surface' => $request->surface,
                    'category' => $request->category,
                ],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function approveDeployRequest(string $requestId, string $adminUserId): array
    {
        $request = SystemTranslationDeployRequest::query()->with('items')->find($requestId);
        if (! $request instanceof SystemTranslationDeployRequest) {
            return ['error' => 'not_found'];
        }

        if ($request->status !== 'submitted') {
            return ['error' => 'validation_failed', 'errors' => ['status' => ['Only submitted requests can be approved.']]];
        }

        $errors = $request->items
            ->flatMap(fn (SystemTranslationDeployRequestItem $item) => $item->validation_errors_json ?: [])
            ->values()
            ->all();

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => ['variables' => $errors]];
        }

        DB::transaction(function () use ($request, $adminUserId): void {
            foreach ($request->items as $item) {
                SystemTranslationValue::query()->updateOrCreate(
                    [
                        'language_id' => $request->language_id,
                        'translation_key_id' => $item->translation_key_id,
                    ],
                    [
                        'id' => $this->stableId('tvl', $request->language_id, $item->translation_key_id),
                        'value' => $item->draft_value,
                        'published_by_admin_id' => $adminUserId,
                        'published_at' => now(),
                    ],
                );

                SystemTranslationDraft::query()
                    ->where('language_id', $request->language_id)
                    ->where('translation_key_id', $item->translation_key_id)
                    ->update(['status' => 'deployed', 'updated_at' => now()]);
            }

            $request->forceFill([
                'status' => 'deployed',
                'reviewed_by_admin_id' => $adminUserId,
                'reviewed_at' => now(),
                'deployed_at' => now(),
                'review_note' => null,
            ])->save();

            $this->queueCentralMenuBadgeBroadcast('translations');
        });

        $this->forgetBundle($request->locale, $request->surface);

        return ['resource' => ['request' => $this->serializeRequest($request->fresh(['items.key']))]];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function rejectDeployRequest(string $requestId, string $adminUserId, array $payload): array
    {
        $request = SystemTranslationDeployRequest::query()->find($requestId);
        if (! $request instanceof SystemTranslationDeployRequest) {
            return ['error' => 'not_found'];
        }

        $reason = trim((string) ($payload['reason'] ?? ''));
        if ($reason === '') {
            return ['error' => 'validation_failed', 'errors' => ['reason' => ['Reject reason is required.']]];
        }

        if ($request->status !== 'submitted') {
            return ['error' => 'validation_failed', 'errors' => ['status' => ['Only submitted requests can be rejected.']]];
        }

        $request->forceFill([
            'status' => 'rejected',
            'reviewed_by_admin_id' => $adminUserId,
            'reviewed_at' => now(),
            'review_note' => $reason,
        ])->save();
        $this->queueCentralMenuBadgeBroadcast('translations');

        return ['resource' => ['request' => $this->serializeRequest($request->fresh(['items.key']))]];
    }

    /**
     * @return array<string, mixed>
     */
    public function runtimeBundle(?string $locale, ?string $surface, ?string $previewToken = null): array
    {
        $this->ensureCatalogSeeded();

        $normalizedLocale = self::normalizeLocale($locale) ?? $this->defaultLocale();
        $normalizedSurface = $this->normalizeSurface($surface) ?? 'customer';
        $language = $this->languageByLocale($normalizedLocale);
        $cacheKey = $this->bundleCacheKey($language->locale, $normalizedSurface);

        $messages = Cache::remember($cacheKey, now()->addMinutes(10), function () use ($language, $normalizedSurface): array {
            return SystemTranslationValue::query()
                ->with('key')
                ->where('language_id', $language->id)
                ->whereNotNull('value')
                ->whereHas('key', fn ($keyQuery) => $keyQuery
                    ->where('surface', $normalizedSurface)
                    ->where('status', 'active'))
                ->get()
                ->mapWithKeys(fn (SystemTranslationValue $value): array => [
                    (string) $value->key?->translation_key => (string) $value->value,
                ])
                ->filter(fn ($value, $key): bool => trim((string) $key) !== '')
                ->all();
        });

        $preview = null;
        if ($previewToken !== null && trim($previewToken) !== '') {
            $preview = $this->previewOverlay($previewToken, $language->locale, $normalizedSurface);
            if ($preview !== null) {
                $messages = array_merge($messages, $preview['messages']);
            }
        }

        $phrases = $this->phraseMap($messages, $normalizedSurface);

        return [
            'locale' => $language->locale,
            'surface' => $normalizedSurface,
            'messages' => $messages,
            'phrases' => $phrases,
            'available_locales' => $this->availableLanguageRowsForSurface($normalizedSurface),
            'preview' => $preview ? [
                'request_id' => $preview['request_id'],
                'category' => $preview['category'],
                'expires_at' => $preview['expires_at'],
            ] : null,
        ];
    }

    public static function runtimeMessage(string $key, string $fallback): string
    {
        $locale = app()->getLocale();
        $service = app(self::class);
        $bundle = $service->runtimeBundle($locale, 'api');
        $message = $bundle['messages'][$key] ?? null;

        return is_string($message) && trim($message) !== '' ? $message : $fallback;
    }

    public function syncCatalog(): void
    {
        $now = now();
        Cache::forget('system_translation_languages');
        Cache::forget('system_translation_languages_active');
        Cache::forget('system_translation_catalog_seeded');

        $languages = [
            ['locale' => 'th-TH', 'name' => 'Thai', 'native_name' => 'ไทย', 'is_default' => true, 'sort_order' => 10],
            ['locale' => 'en-US', 'name' => 'English', 'native_name' => 'English', 'is_default' => false, 'sort_order' => 20],
        ];

        foreach ($languages as $language) {
            SystemLanguage::query()->updateOrCreate(
                ['locale' => $language['locale']],
                [
                    'id' => $this->stableId('lng', $language['locale']),
                    'name' => $language['name'],
                    'native_name' => $language['native_name'],
                    'status' => 'active',
                    'is_default' => $language['is_default'],
                    'sort_order' => $language['sort_order'],
                    'updated_at' => $now,
                ],
            );
        }

        $entries = StaticTranslationCatalog::entries();
        $activeBackOfficePhraseKeys = [];

        foreach ([...$entries, ...$this->staticLocaleKeyEntries($entries)] as $entry) {
            $variables = $this->placeholderNames($entry['default_text']);
            if ($entry['surface'] === 'back-office' && $entry['category'] === 'phrases') {
                $activeBackOfficePhraseKeys[] = $entry['key'];
            }

            $key = SystemTranslationKey::query()
                ->where('surface', $entry['surface'])
                ->where('translation_key', $entry['key'])
                ->first();

            if (! $key instanceof SystemTranslationKey) {
                SystemTranslationKey::query()->create([
                    'id' => $this->stableId('tky', $entry['surface'], $entry['key']),
                    'surface' => $entry['surface'],
                    'translation_key' => $entry['key'],
                    'category' => $entry['category'],
                    'default_text' => $entry['default_text'],
                    'description' => $entry['description'] ?? null,
                    'variables_json' => $variables,
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                continue;
            }

            $key->forceFill([
                'category' => $entry['category'],
                'default_text' => $entry['default_text'],
                'description' => $entry['description'] ?? null,
                'variables_json' => $variables,
                'status' => 'active',
                'updated_at' => $now,
            ])->save();
        }

        if ($activeBackOfficePhraseKeys !== []) {
            SystemTranslationKey::query()
                ->where('surface', 'back-office')
                ->where('category', 'phrases')
                ->whereNotIn('translation_key', array_values(array_unique($activeBackOfficePhraseKeys)))
                ->update(['status' => 'inactive', 'updated_at' => $now]);
        }

        $this->syncStaticPublishedValues($now);
        $this->syncBackOfficePhraseDefaults($now);

        Cache::put('system_translation_catalog_seeded', $this->catalogHasPublishedValues(), now()->addMinutes(10));
    }

    /**
     * @param array<int, array{surface: string, category: string, key: string, default_text: string, description?: string}> $existingEntries
     * @return array<int, array{surface: string, category: string, key: string, default_text: string}>
     */
    private function staticLocaleKeyEntries(array $existingEntries): array
    {
        $existing = [];
        foreach ($existingEntries as $entry) {
            $existing[$entry['surface'].'|'.$entry['key']] = true;
        }

        $localized = [];
        foreach (StaticTranslationCatalog::localizedValues() as $row) {
            $surface = (string) ($row['surface'] ?? '');
            $key = (string) ($row['key'] ?? '');
            if ($surface === '' || $key === '' || isset($existing[$surface.'|'.$key])) {
                continue;
            }

            $localized[$surface][$key][(string) $row['locale']] = (string) $row['value'];
        }

        $rows = [];
        foreach ($localized as $surface => $keys) {
            foreach ($keys as $key => $valuesByLocale) {
                $category = Str::before($key, '.');
                $rows[] = [
                    'surface' => $surface,
                    'category' => $category !== '' ? $category : 'general',
                    'key' => $key,
                    'default_text' => $valuesByLocale['en-US']
                        ?? $valuesByLocale['th-TH']
                        ?? (string) reset($valuesByLocale),
                ];
            }
        }

        return $rows;
    }

    private function syncStaticPublishedValues(Carbon $now): void
    {
        $touched = [];
        foreach (StaticTranslationCatalog::localizedValues() as $row) {
            $locale = self::normalizeLocale($row['locale'] ?? null);
            if ($locale === null) {
                continue;
            }

            $language = $this->languageByLocale($locale);
            $key = SystemTranslationKey::query()
                ->where('surface', $row['surface'])
                ->where('translation_key', $row['key'])
                ->first();
            if (! $key instanceof SystemTranslationKey) {
                continue;
            }

            $value = SystemTranslationValue::query()
                ->where('language_id', $language->id)
                ->where('translation_key_id', $key->id)
                ->first();

            if ($value instanceof SystemTranslationValue && $value->published_by_admin_id !== null && trim((string) $value->value) !== '') {
                continue;
            }

            if (! $value instanceof SystemTranslationValue) {
                $value = new SystemTranslationValue([
                    'id' => $this->stableId('tvl', $language->id, $key->id),
                    'language_id' => $language->id,
                    'translation_key_id' => $key->id,
                    'created_at' => $now,
                ]);
            }

            $value->forceFill([
                'value' => $row['value'],
                'published_by_admin_id' => null,
                'published_at' => $value->published_at ?? $now,
                'updated_at' => $now,
            ])->save();

            $touched[$language->locale][$key->surface] = true;
        }

        foreach ($touched as $locale => $surfaces) {
            foreach (array_keys($surfaces) as $surface) {
                $this->forgetBundle($locale, (string) $surface);
            }
        }
    }

    private function syncBackOfficePhraseDefaults(Carbon $now): void
    {
        $touched = [];
        $phrases = SystemTranslationKey::query()
            ->where('surface', 'back-office')
            ->where('category', 'phrases')
            ->where('status', 'active')
            ->get(['id', 'surface', 'default_text']);

        foreach (['th-TH', 'en-US'] as $locale) {
            $language = $this->languageByLocale($locale);

            foreach ($phrases as $key) {
                $translated = BackOfficePhraseTranslations::translate((string) $key->default_text, $locale);
                if (
                    $translated === null
                    && $locale === 'th-TH'
                    && preg_match('/[ก-๙]/u', (string) $key->default_text) === 1
                    && preg_match('/[A-Za-z]/u', (string) $key->default_text) !== 1
                ) {
                    $translated = (string) $key->default_text;
                }

                if ($translated === null || trim($translated) === '') {
                    continue;
                }

                $value = SystemTranslationValue::query()
                    ->where('language_id', $language->id)
                    ->where('translation_key_id', $key->id)
                    ->first();

                if ($value instanceof SystemTranslationValue && $value->published_by_admin_id !== null && trim((string) $value->value) !== '') {
                    continue;
                }

                if (! $value instanceof SystemTranslationValue) {
                    $value = new SystemTranslationValue([
                        'id' => $this->stableId('tvl', $language->id, $key->id),
                        'language_id' => $language->id,
                        'translation_key_id' => $key->id,
                        'created_at' => $now,
                    ]);
                }

                $value->forceFill([
                    'value' => $translated,
                    'published_by_admin_id' => null,
                    'published_at' => $value->published_at ?? $now,
                    'updated_at' => $now,
                ])->save();

                $touched[$language->locale]['back-office'] = true;
            }
        }

        foreach ($touched as $locale => $surfaces) {
            foreach (array_keys($surfaces) as $surface) {
                $this->forgetBundle($locale, (string) $surface);
            }
        }
    }

    public static function normalizeLocale(mixed $value): ?string
    {
        $raw = trim((string) ($value ?? ''));
        if ($raw === '') {
            return null;
        }

        $normalized = str_replace('_', '-', strtolower($raw));

        if ($normalized === 'th' || $normalized === 'th-th') {
            return 'th-TH';
        }

        if ($normalized === 'en' || $normalized === 'en-us' || $normalized === 'en-gb') {
            return 'en-US';
        }

        if (preg_match('/^[a-z]{2}(?:-[a-z]{2})?$/', $normalized) !== 1) {
            return null;
        }

        [$language, $region] = array_pad(explode('-', $normalized, 2), 2, null);

        return $region ? $language.'-'.strtoupper($region) : $language;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function languageRows(bool $activeOnly = false): array
    {
        return Cache::remember('system_translation_languages'.($activeOnly ? '_active' : ''), now()->addMinutes(10), function () use ($activeOnly): array {
            $query = SystemLanguage::query()->orderBy('sort_order')->orderBy('locale');
            if ($activeOnly) {
                $query->where('status', 'active');
            }

            return $query->get()->map(fn (SystemLanguage $language): array => $this->serializeLanguage($language))->all();
        });
    }

    /**
     * Only advertise languages that have published content for this runtime surface.
     * Translation Center can keep languages used by other surfaces without exposing
     * unfinished choices to customer and back-office clients.
     *
     * @return array<int, array<string, mixed>>
     */
    private function availableLanguageRowsForSurface(string $surface): array
    {
        return SystemLanguage::query()
            ->where('status', 'active')
            ->whereHas('values', fn ($valueQuery) => $valueQuery
                ->whereNotNull('value')
                ->where('value', '!=', '')
                ->whereHas('key', fn ($keyQuery) => $keyQuery
                    ->where('surface', $surface)
                    ->where('status', 'active')))
            ->orderBy('sort_order')
            ->orderBy('locale')
            ->get()
            ->map(fn (SystemLanguage $language): array => $this->serializeLanguage($language))
            ->all();
    }

    private function languageByLocale(string $locale): SystemLanguage
    {
        $language = SystemLanguage::query()->where('locale', $locale)->first();
        if ($language instanceof SystemLanguage) {
            return $language;
        }

        $result = $this->upsertLanguage([
            'locale' => $locale,
            'name' => $locale,
            'native_name' => $locale,
            'status' => 'active',
            'sort_order' => 100,
        ]);

        return SystemLanguage::query()->where('locale', $locale)->firstOrFail();
    }

    private function ensureCatalogSeeded(): void
    {
        $seeded = Cache::remember('system_translation_catalog_seeded', now()->addMinutes(10), fn (): bool => $this->catalogHasPublishedValues());

        if (! $seeded) {
            $this->syncCatalog();
        }
    }

    private function catalogHasPublishedValues(): bool
    {
        return SystemLanguage::query()->exists()
            && SystemTranslationKey::query()->exists()
            && SystemTranslationValue::query()->exists();
    }

    private function defaultLocale(): string
    {
        return SystemLanguage::query()->where('is_default', true)->value('locale') ?: 'th-TH';
    }

    private function normalizeSurface(mixed $value): ?string
    {
        $surface = trim((string) ($value ?? ''));

        return in_array($surface, self::SURFACES, true) ? $surface : null;
    }

    /**
     * @return array<int, string>
     */
    private function validatePlaceholders(string $defaultText, string $value): array
    {
        $required = $this->placeholderNames($defaultText);
        if ($required === []) {
            return [];
        }

        $found = $this->placeholderNames($value);
        $missing = array_values(array_diff($required, $found));

        return array_map(fn (string $name): string => 'Missing placeholder {'.$name.'}.', $missing);
    }

    /**
     * @return array<int, string>
     */
    private function placeholderNames(string $text): array
    {
        preg_match_all('/\{([a-zA-Z0-9_]+)\}/', $text, $matches);

        return array_values(array_unique($matches[1] ?? []));
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeLanguage(?SystemLanguage $language): array
    {
        return [
            'id' => $language?->id,
            'locale' => $language?->locale,
            'name' => $language?->name,
            'native_name' => $language?->native_name,
            'status' => $language?->status,
            'is_default' => (bool) $language?->is_default,
            'sort_order' => (int) $language?->sort_order,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function serializeRequest(?SystemTranslationDeployRequest $request): array
    {
        if (! $request instanceof SystemTranslationDeployRequest) {
            return [];
        }

        $items = $request->relationLoaded('items')
            ? $request->items->map(fn (SystemTranslationDeployRequestItem $item): array => [
                'id' => $item->id,
                'key_id' => $item->translation_key_id,
                'key' => $item->key?->translation_key,
                'default_text' => $item->key?->default_text,
                'current_value' => $item->current_value,
                'draft_value' => $item->draft_value,
                'variables' => $item->variables_json ?: [],
                'validation_errors' => $item->validation_errors_json ?: [],
            ])->all()
            : [];

        return [
            'id' => $request->id,
            'locale' => $request->locale,
            'surface' => $request->surface,
            'category' => $request->category,
            'status' => $request->status,
            'title' => $request->title,
            'summary' => $request->summary_json ?: [],
            'submitted_by_admin_id' => $request->submitted_by_admin_id,
            'submitted_at' => $request->submitted_at?->toIso8601String(),
            'reviewed_by_admin_id' => $request->reviewed_by_admin_id,
            'reviewed_at' => $request->reviewed_at?->toIso8601String(),
            'review_note' => $request->review_note,
            'deployed_at' => $request->deployed_at?->toIso8601String(),
            'created_at' => $request->created_at?->toIso8601String(),
            'items' => $items,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function previewOverlay(string $previewToken, string $locale, string $surface): ?array
    {
        $session = SystemTranslationPreviewSession::query()
            ->with(['request.items.key'])
            ->where('token_hash', hash('sha256', trim($previewToken)))
            ->where('expires_at', '>', now())
            ->first();

        if (! $session instanceof SystemTranslationPreviewSession || ! $session->request instanceof SystemTranslationDeployRequest) {
            return null;
        }

        $request = $session->request;
        if ($request->locale !== $locale || $request->surface !== $surface) {
            return null;
        }

        $messages = [];
        foreach ($request->items as $item) {
            if ($item->key instanceof SystemTranslationKey) {
                $messages[$item->key->translation_key] = (string) $item->draft_value;
            }
        }

        return [
            'request_id' => $request->id,
            'category' => $request->category,
            'expires_at' => $session->expires_at?->toIso8601String(),
            'messages' => $messages,
        ];
    }

    /**
     * @param array<string, string> $messages
     * @return array<string, string>
     */
    private function phraseMap(array $messages, string $surface): array
    {
        if ($surface !== 'back-office') {
            return [];
        }

        return SystemTranslationKey::query()
            ->where('surface', $surface)
            ->where('category', 'phrases')
            ->where('status', 'active')
            ->orderBy('translation_key')
            ->get(['translation_key', 'default_text'])
            ->mapWithKeys(function (SystemTranslationKey $key) use ($messages): array {
                $defaultText = trim((string) $key->default_text);
                $translated = trim((string) ($messages[$key->translation_key] ?? ''));

                if ($defaultText === '' || $translated === '' || $translated === $defaultText) {
                    return [];
                }

                return [$defaultText => $translated];
            })
            ->all();
    }

    /**
     * @return array<int|string, mixed>
     */
    private function decodeJson(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if (! is_string($value) || trim($value) === '') {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function stableId(string $prefix, string ...$parts): string
    {
        return $prefix.'_'.substr(sha1(implode(':', $parts)), 0, 20);
    }

    private function bundleCacheKey(string $locale, string $surface): string
    {
        return 'system_translation_bundle:'.$locale.':'.$surface;
    }

    private function forgetBundle(string $locale, string $surface): void
    {
        Cache::forget($this->bundleCacheKey($locale, $surface));
    }

    private function queueCentralMenuBadgeBroadcast(string $source): void
    {
        if (DB::transactionLevel() > 0) {
            DB::afterCommit(fn (): mixed => AdminMenuBadgesUpdated::dispatch('central', null, $source));

            return;
        }

        AdminMenuBadgesUpdated::dispatch('central', null, $source);
    }
}
