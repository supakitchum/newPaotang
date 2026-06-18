<?php

namespace App\Modules\StorageConnections\Services;

use App\Models\PlatformStorageConnection;
use App\Models\PlatformStorageRoute;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class RuntimeStorageService
{
    public const DRIVER_LOCAL = 'local';
    public const DRIVER_AWS_S3 = 'aws_s3';

    public const ROUTE_LOTTERY_IMAGES = 'lottery_images';
    public const ROUTE_BACKGROUND_ASSETS = 'background_assets';
    public const ROUTE_PAYMENT_SLIPS = 'payment_slips';
    public const ROUTE_ANNOUNCEMENT_IMAGES = 'announcement_images';
    public const ROUTE_ACTIVITY_IMAGES = 'activity_images';
    public const ROUTE_PARTNER_ASSETS = 'partner_assets';
    public const ROUTE_CENTRAL_ASSETS = 'central_assets';

    private const AWS_S3_ID = 'storage_aws_s3';

    /** @var array<string, Filesystem> */
    private array $diskCache = [];

    /**
     * @return array<string, array<string, mixed>>
     */
    public static function routeDefinitions(): array
    {
        return [
            self::ROUTE_LOTTERY_IMAGES => [
                'label' => 'Lottery images',
                'description' => 'Generated lottery ticket images and stock preview assets.',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 10,
                'path_hint' => 'lotteries/{game}/{batch}/partners/{partner}',
            ],
            self::ROUTE_BACKGROUND_ASSETS => [
                'label' => 'Background asset sets',
                'description' => 'Source, full, and thumbnail background images imported for lottery image composition.',
                'root_prefix' => '',
                'tenant_scoped' => false,
                'sort_order' => 20,
                'path_hint' => 'lottery-image-assets/games/{game}/backgrounds/{version}/{set_type}',
            ],
            self::ROUTE_PAYMENT_SLIPS => [
                'label' => 'Payment slips',
                'description' => 'Customer top-up slip full and thumbnail images.',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 30,
                'path_hint' => 'tenants/{tenant}/topup-slips',
            ],
            self::ROUTE_ANNOUNCEMENT_IMAGES => [
                'label' => 'Announcement images',
                'description' => 'Partner news and announcement modal images.',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 40,
                'path_hint' => 'tenants/{tenant}/announcements',
            ],
            self::ROUTE_ACTIVITY_IMAGES => [
                'label' => 'Activity images',
                'description' => 'Partner activity full and thumbnail images.',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 50,
                'path_hint' => 'tenants/{tenant}/activities',
            ],
            self::ROUTE_PARTNER_ASSETS => [
                'label' => 'Partner assets',
                'description' => 'Tenant logos, branding assets, and partner-owned attachments.',
                'root_prefix' => '',
                'tenant_scoped' => true,
                'sort_order' => 60,
                'path_hint' => 'tenants/{tenant}/assets or partners/{partner}',
            ],
            self::ROUTE_CENTRAL_ASSETS => [
                'label' => 'Central assets',
                'description' => 'Platform owner uploads and central-only assets.',
                'root_prefix' => '',
                'tenant_scoped' => false,
                'sort_order' => 70,
                'path_hint' => 'central/assets',
            ],
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function routes(): array
    {
        $this->ensureDefaultRoutes();

        $rows = $this->routeRows();

        return array_map(fn (array $row): array => $this->serializeRoute($row), $rows);
    }

    /**
     * @param array<int, array<string, mixed>> $payload
     * @return array<string, array<int, string>>
     */
    public function validateRoutes(array $payload): array
    {
        $errors = [];
        $definitions = self::routeDefinitions();

        foreach ($payload as $index => $row) {
            $routeKey = trim((string) ($row['route_key'] ?? ''));
            $driver = trim((string) ($row['driver'] ?? self::DRIVER_LOCAL));
            $prefix = trim((string) ($row['root_prefix'] ?? ''), '/');

            if (! isset($definitions[$routeKey])) {
                $errors["routes.$index.route_key"][] = 'Unknown upload category.';
                continue;
            }

            if (! in_array($driver, [self::DRIVER_LOCAL, self::DRIVER_AWS_S3], true)) {
                $errors["routes.$index.driver"][] = 'Storage driver must be local or AWS S3.';
            }

            if ($prefix !== '' && ! preg_match('/^[A-Za-z0-9._\\/-]+$/', $prefix)) {
                $errors["routes.$index.root_prefix"][] = 'Prefix can contain letters, numbers, slash, dash, underscore, and dot only.';
            }
        }

        return $errors;
    }

    /**
     * @param array<int, array<string, mixed>> $payload
     * @return array{routes: array<int, array<string, mixed>>, errors: array<string, array<int, string>>}
     */
    public function updateRoutes(array $payload): array
    {
        $this->ensureDefaultRoutes();
        $errors = $this->validateRoutes($payload);
        $definitions = self::routeDefinitions();

        if ($errors !== []) {
            return ['routes' => $this->routes(), 'errors' => $errors];
        }

        foreach ($payload as $row) {
            $routeKey = trim((string) ($row['route_key'] ?? ''));

            if (! isset($definitions[$routeKey])) {
                continue;
            }

            PlatformStorageRoute::query()->updateOrCreate(
                ['route_key' => $routeKey],
                [
                    'label' => (string) $definitions[$routeKey]['label'],
                    'description' => (string) $definitions[$routeKey]['description'],
                    'driver' => trim((string) ($row['driver'] ?? self::DRIVER_LOCAL)) === self::DRIVER_AWS_S3
                        ? self::DRIVER_AWS_S3
                        : self::DRIVER_LOCAL,
                    'root_prefix' => trim((string) ($row['root_prefix'] ?? ''), '/'),
                    'tenant_scoped' => (bool) $definitions[$routeKey]['tenant_scoped'],
                    'sort_order' => (int) $definitions[$routeKey]['sort_order'],
                    'metadata_json' => [
                        'path_hint' => (string) $definitions[$routeKey]['path_hint'],
                        'updated_from' => 'central_bo',
                    ],
                    'updated_at' => now(),
                ],
            );
        }

        $this->diskCache = [];

        return ['routes' => $this->routes(), 'errors' => []];
    }

    /**
     * @param array<string, mixed> $options
     */
    public function put(string $routeKey, string $key, string $contents, array $options = []): string
    {
        $storageKey = $this->objectKey($routeKey, $key);
        $this->disk($routeKey)->put($storageKey, $contents, $options);

        return $storageKey;
    }

    /**
     * @param array<string, mixed> $options
     */
    public function putUsingDriver(string $routeKey, string $key, string $contents, array $options = [], ?string $driver = null): string
    {
        if ($driver === null || $driver === '') {
            return $this->put($routeKey, $key, $contents, $options);
        }

        $storageKey = $this->objectKeyForDriver($routeKey, $key, $driver);
        $this->diskForDriver($routeKey, $driver)->put($storageKey, $contents, $options);

        return $storageKey;
    }

    /**
     * @param resource $stream
     * @param array<string, mixed> $options
     */
    public function putStreamUsingDriver(string $routeKey, string $key, mixed $stream, array $options = [], ?string $driver = null): string
    {
        $storageKey = $driver === null || $driver === ''
            ? $this->objectKey($routeKey, $key)
            : $this->objectKeyForDriver($routeKey, $key, $driver);
        $disk = $driver === null || $driver === ''
            ? $this->disk($routeKey)
            : $this->diskForDriver($routeKey, $driver);

        $disk->put($storageKey, $stream, $options);

        return $storageKey;
    }

    public function get(string $routeKey, string $key): ?string
    {
        try {
            return (string) $this->disk($routeKey)->get($key);
        } catch (\Throwable) {
            return $this->localFallbackGet($key);
        }
    }

    public function getUsingDriver(string $routeKey, string $key, ?string $driver = null): ?string
    {
        if ($driver === null || $driver === '') {
            return $this->get($routeKey, $key);
        }

        try {
            return (string) $this->diskForDriver($routeKey, $driver)->get($key);
        } catch (\Throwable) {
            return $driver === self::DRIVER_LOCAL ? null : $this->localFallbackGet($key);
        }
    }

    /**
     * @return resource|null
     */
    public function readStreamUsingDriver(string $routeKey, string $key, ?string $driver = null): mixed
    {
        try {
            $stream = $driver === null || $driver === ''
                ? $this->disk($routeKey)->readStream($key)
                : $this->diskForDriver($routeKey, $driver)->readStream($key);

            return is_resource($stream) ? $stream : null;
        } catch (\Throwable) {
            if ($driver === self::DRIVER_LOCAL) {
                return null;
            }

            try {
                $stream = $this->localDisk()->readStream($key);

                return is_resource($stream) ? $stream : null;
            } catch (\Throwable) {
                return null;
            }
        }
    }

    public function exists(string $routeKey, string $key): bool
    {
        try {
            if ($this->disk($routeKey)->exists($key)) {
                return true;
            }
        } catch (\Throwable) {
        }

        return $this->localDisk()->exists($key);
    }

    public function existsUsingDriver(string $routeKey, string $key, ?string $driver = null): bool
    {
        if ($driver === null || $driver === '') {
            return $this->exists($routeKey, $key);
        }

        try {
            return $this->diskForDriver($routeKey, $driver)->exists($key);
        } catch (\Throwable) {
            return $driver !== self::DRIVER_LOCAL && $this->localDisk()->exists($key);
        }
    }

    public function mimeType(string $routeKey, string $key): ?string
    {
        try {
            return $this->disk($routeKey)->mimeType($key) ?: null;
        } catch (\Throwable) {
            try {
                return $this->localDisk()->mimeType($key) ?: null;
            } catch (\Throwable) {
                return null;
            }
        }
    }

    public function mimeTypeUsingDriver(string $routeKey, string $key, ?string $driver = null): ?string
    {
        if ($driver === null || $driver === '') {
            return $this->mimeType($routeKey, $key);
        }

        try {
            return $this->diskForDriver($routeKey, $driver)->mimeType($key) ?: null;
        } catch (\Throwable) {
            try {
                return $driver === self::DRIVER_LOCAL ? null : ($this->localDisk()->mimeType($key) ?: null);
            } catch (\Throwable) {
                return null;
            }
        }
    }

    /**
     * @param array<int, string>|string $keys
     */
    public function delete(string $routeKey, array|string $keys): void
    {
        $paths = is_array($keys) ? $keys : [$keys];
        $paths = array_values(array_filter(array_map(fn (mixed $key): string => trim((string) $key), $paths)));

        if ($paths === []) {
            return;
        }

        try {
            $this->disk($routeKey)->delete($paths);
        } catch (\Throwable) {
        }

        if ($this->routeDriver($routeKey) !== self::DRIVER_LOCAL) {
            try {
                $this->localDisk()->delete($paths);
            } catch (\Throwable) {
            }
        }
    }

    /**
     * @param array<int, string>|string $keys
     */
    public function deleteUsingDriver(string $routeKey, array|string $keys, ?string $driver = null): void
    {
        if ($driver === null || $driver === '') {
            $this->delete($routeKey, $keys);

            return;
        }

        $paths = is_array($keys) ? $keys : [$keys];
        $paths = array_values(array_filter(array_map(fn (mixed $key): string => trim((string) $key), $paths)));

        if ($paths === []) {
            return;
        }

        try {
            $this->diskForDriver($routeKey, $driver)->delete($paths);
        } catch (\Throwable) {
        }

        if ($driver !== self::DRIVER_LOCAL) {
            try {
                $this->localDisk()->delete($paths);
            } catch (\Throwable) {
            }
        }
    }

    public function publicUrl(string $routeKey, string $key): string
    {
        $connection = $this->routeDriver($routeKey) === self::DRIVER_AWS_S3 ? $this->activeS3Connection() : null;

        if ($connection instanceof PlatformStorageConnection) {
            if ((string) ($connection->visibility ?? 'private') === 'public') {
                try {
                    return $this->absoluteUrl((string) $this->disk($routeKey)->url($key));
                } catch (\Throwable) {
                }
            }
        }

        return $this->localAssetUrl($key);
    }

    public function publicUrlUsingDriver(string $routeKey, string $key, ?string $driver = null): string
    {
        if ($driver === null || $driver === '') {
            return $this->publicUrl($routeKey, $key);
        }

        $connection = $driver === self::DRIVER_AWS_S3 ? $this->activeS3Connection() : null;

        if ($connection instanceof PlatformStorageConnection && (string) ($connection->visibility ?? 'private') === 'public') {
            try {
                return $this->absoluteUrl((string) $this->diskForDriver($routeKey, $driver)->url($key));
            } catch (\Throwable) {
            }
        }

        return $this->localAssetUrl($key, $driver);
    }

    public function storageDriverAvailable(string $driver): bool
    {
        if ($driver === self::DRIVER_LOCAL) {
            return true;
        }

        return $driver === self::DRIVER_AWS_S3 && $this->activeS3Connection() instanceof PlatformStorageConnection;
    }

    public function driverForRoute(string $routeKey): string
    {
        return $this->routeDriver($routeKey);
    }

    public function routeForPlatformAsset(string $purpose, string $scopeType): string
    {
        return match ($purpose) {
            'ticket_image' => self::ROUTE_LOTTERY_IMAGES,
            'partner_lottery_branding' => self::ROUTE_PARTNER_ASSETS,
            'tenant_announcement_image' => self::ROUTE_ANNOUNCEMENT_IMAGES,
            'tenant_activity_image' => self::ROUTE_ACTIVITY_IMAGES,
            default => $scopeType === 'central' ? self::ROUTE_CENTRAL_ASSETS : self::ROUTE_PARTNER_ASSETS,
        };
    }

    public function routeForStorageKey(string $key): string
    {
        $key = ltrim($key, '/');

        if (str_contains($key, '/topup-slips/') || str_starts_with($key, 'payment-slips/')) {
            return self::ROUTE_PAYMENT_SLIPS;
        }

        if (str_contains($key, '/announcements/') || str_starts_with($key, 'announcements/')) {
            return self::ROUTE_ANNOUNCEMENT_IMAGES;
        }

        if (str_contains($key, '/activities/') || str_starts_with($key, 'activities/')) {
            return self::ROUTE_ACTIVITY_IMAGES;
        }

        if (str_contains($key, '/lottery-image-assets/') || str_starts_with($key, 'lottery-image-assets/')) {
            return self::ROUTE_BACKGROUND_ASSETS;
        }

        if (str_starts_with($key, 'lotteries/')) {
            return self::ROUTE_LOTTERY_IMAGES;
        }

        if (str_starts_with($key, 'central/')) {
            return self::ROUTE_CENTRAL_ASSETS;
        }

        return self::ROUTE_PARTNER_ASSETS;
    }

    /**
     * @return array<string, mixed>
     */
    public function readiness(string $routeKey): array
    {
        $row = $this->routeRow($routeKey);
        $routeDriver = $this->routeDriver($routeKey);
        $connection = $routeDriver === self::DRIVER_AWS_S3 ? $this->activeS3Connection() : null;
        $legacyDisk = (string) config('lottery_images.disk', 'lottery_images');
        $legacyDiskConfig = config('filesystems.disks.'.$legacyDisk, []);
        $legacyDriver = is_array($legacyDiskConfig) ? (string) ($legacyDiskConfig['driver'] ?? '') : '';
        $connectionUrl = $connection instanceof PlatformStorageConnection ? trim((string) ($connection->url ?? '')) : '';

        return [
            'route_key' => $routeKey,
            'route_driver' => $routeDriver,
            'disk' => $routeDriver === self::DRIVER_AWS_S3
                ? 'storage_connections:'.$routeKey
                : $legacyDisk,
            'disk_driver' => $routeDriver === self::DRIVER_AWS_S3 ? 's3' : ($legacyDriver !== '' ? $legacyDriver : self::DRIVER_LOCAL),
            'configured' => $routeDriver === self::DRIVER_AWS_S3
                ? $connection instanceof PlatformStorageConnection
                : is_array($legacyDiskConfig) && $legacyDiskConfig !== [],
            'connection_active' => $connection instanceof PlatformStorageConnection,
            'connection_status' => $connection instanceof PlatformStorageConnection ? (string) $connection->status : null,
            'bucket_present' => $connection instanceof PlatformStorageConnection
                ? trim((string) ($connection->bucket ?? '')) !== ''
                : (is_array($legacyDiskConfig) && trim((string) ($legacyDiskConfig['bucket'] ?? '')) !== ''),
            'region_present' => $connection instanceof PlatformStorageConnection
                ? trim((string) ($connection->region ?? '')) !== ''
                : (is_array($legacyDiskConfig) && trim((string) ($legacyDiskConfig['region'] ?? '')) !== ''),
            'endpoint_present' => $connection instanceof PlatformStorageConnection
                ? trim((string) ($connection->endpoint ?? '')) !== ''
                : (is_array($legacyDiskConfig) && trim((string) ($legacyDiskConfig['endpoint'] ?? '')) !== ''),
            'cdn_base_url_present' => trim((string) config('lottery_images.cdn_base_url', '')) !== ''
                || trim((string) config('lottery_images.local_public_base_url', '')) !== ''
                || $connectionUrl !== '',
            'root_prefix_present' => trim((string) ($row['root_prefix'] ?? '')) !== ''
                || ($connection instanceof PlatformStorageConnection && trim((string) ($connection->root_prefix ?? '')) !== ''),
            'secrets_redacted' => true,
        ];
    }

    /**
     * @return array<int, string>
     */
    public function publicAllowedPrefixes(): array
    {
        $prefixes = [
            'lotteries/',
            'lottery-image-assets/',
            'partners/',
            'central/assets/',
            'tenants/',
        ];
        $connectionPrefix = '';

        if (($connection = $this->activeS3Connection()) instanceof PlatformStorageConnection) {
            $connectionPrefix = trim((string) ($connection->root_prefix ?? ''), '/');

            if ($connectionPrefix !== '') {
                $prefixes[] = $connectionPrefix.'/';
            }
        }

        foreach ($this->routeRows() as $row) {
            $prefix = trim((string) ($row['root_prefix'] ?? ''), '/');
            if ($prefix !== '') {
                $prefixes[] = $prefix.'/';

                if ($connectionPrefix !== '') {
                    $prefixes[] = $connectionPrefix.'/'.$prefix.'/';
                }
            }
        }

        return array_values(array_unique($prefixes));
    }

    private function disk(string $routeKey): Filesystem
    {
        $cacheKey = $routeKey.':'.$this->routeDriver($routeKey);

        if (isset($this->diskCache[$cacheKey])) {
            return $this->diskCache[$cacheKey];
        }

        if ($this->routeDriver($routeKey) === self::DRIVER_AWS_S3 && ($connection = $this->activeS3Connection()) instanceof PlatformStorageConnection) {
            return $this->diskCache[$cacheKey] = Storage::build($this->s3DiskConfig($connection));
        }

        return $this->diskCache[$cacheKey] = $this->localDisk();
    }

    private function diskForDriver(string $routeKey, string $driver): Filesystem
    {
        $driver = $driver === self::DRIVER_AWS_S3 ? self::DRIVER_AWS_S3 : self::DRIVER_LOCAL;
        $cacheKey = $routeKey.':override:'.$driver;

        if (isset($this->diskCache[$cacheKey])) {
            return $this->diskCache[$cacheKey];
        }

        if ($driver === self::DRIVER_AWS_S3 && ($connection = $this->activeS3Connection()) instanceof PlatformStorageConnection) {
            return $this->diskCache[$cacheKey] = Storage::build($this->s3DiskConfig($connection));
        }

        return $this->diskCache[$cacheKey] = $this->localDisk();
    }

    private function localDisk(): Filesystem
    {
        return Storage::disk((string) config('lottery_images.disk', 'lottery_images'));
    }

    private function objectKey(string $routeKey, string $key): string
    {
        $key = ltrim($key, '/');

        if ($routeKey === self::ROUTE_LOTTERY_IMAGES) {
            return $key;
        }

        $prefix = $this->routePrefix($routeKey);

        if ($prefix === '' || str_starts_with($key, $prefix.'/')) {
            return $key;
        }

        return $prefix.'/'.$key;
    }

    private function objectKeyForDriver(string $routeKey, string $key, string $driver): string
    {
        $key = ltrim($key, '/');

        if ($routeKey === self::ROUTE_LOTTERY_IMAGES) {
            return $key;
        }

        $prefix = $this->routePrefixForDriver($routeKey, $driver);

        if ($prefix === '' || str_starts_with($key, $prefix.'/')) {
            return $key;
        }

        return $prefix.'/'.$key;
    }

    private function routePrefix(string $routeKey): string
    {
        $row = $this->routeRow($routeKey);
        $prefix = trim((string) ($row['root_prefix'] ?? ''), '/');

        if ($this->routeDriver($routeKey) === self::DRIVER_AWS_S3 && ($connection = $this->activeS3Connection()) instanceof PlatformStorageConnection) {
            $connectionPrefix = trim((string) ($connection->root_prefix ?? ''), '/');
            $prefix = trim($connectionPrefix.($prefix !== '' ? '/'.$prefix : ''), '/');
        }

        return $prefix;
    }

    private function routePrefixForDriver(string $routeKey, string $driver): string
    {
        $row = $this->routeRow($routeKey);
        $prefix = trim((string) ($row['root_prefix'] ?? ''), '/');

        if ($driver === self::DRIVER_AWS_S3 && ($connection = $this->activeS3Connection()) instanceof PlatformStorageConnection) {
            $connectionPrefix = trim((string) ($connection->root_prefix ?? ''), '/');
            $prefix = trim($connectionPrefix.($prefix !== '' ? '/'.$prefix : ''), '/');
        }

        return $prefix;
    }

    private function routeDriver(string $routeKey): string
    {
        $row = $this->routeRow($routeKey);

        return (string) ($row['driver'] ?? self::DRIVER_LOCAL) === self::DRIVER_AWS_S3
            ? self::DRIVER_AWS_S3
            : self::DRIVER_LOCAL;
    }

    /**
     * @return array<string, mixed>
     */
    private function routeRow(string $routeKey): array
    {
        foreach ($this->routeRows() as $row) {
            if (($row['route_key'] ?? null) === $routeKey) {
                return $row;
            }
        }

        $definitions = self::routeDefinitions();
        $definition = $definitions[$routeKey] ?? $definitions[self::ROUTE_PARTNER_ASSETS];

        return [
            'route_key' => $routeKey,
            'label' => (string) $definition['label'],
            'description' => (string) $definition['description'],
            'driver' => self::DRIVER_LOCAL,
            'root_prefix' => (string) $definition['root_prefix'],
            'tenant_scoped' => (bool) $definition['tenant_scoped'],
            'sort_order' => (int) $definition['sort_order'],
            'metadata_json' => ['path_hint' => (string) $definition['path_hint']],
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function routeRows(): array
    {
        if (! $this->routesTableAvailable()) {
            return $this->defaultRouteRows();
        }

        $this->ensureDefaultRoutes();

        return PlatformStorageRoute::query()
            ->orderBy('sort_order')
            ->get()
            ->map(fn (PlatformStorageRoute $route): array => [
                'route_key' => (string) $route->route_key,
                'label' => (string) $route->label,
                'description' => (string) ($route->description ?? ''),
                'driver' => (string) $route->driver,
                'root_prefix' => (string) ($route->root_prefix ?? ''),
                'tenant_scoped' => (bool) $route->tenant_scoped,
                'sort_order' => (int) $route->sort_order,
                'metadata_json' => is_array($route->metadata_json) ? $route->metadata_json : [],
            ])
            ->all();
    }

    private function ensureDefaultRoutes(): void
    {
        if (! $this->routesTableAvailable()) {
            return;
        }

        foreach (self::routeDefinitions() as $routeKey => $definition) {
            PlatformStorageRoute::query()->firstOrCreate(
                ['route_key' => $routeKey],
                [
                    'label' => (string) $definition['label'],
                    'description' => (string) $definition['description'],
                    'driver' => self::DRIVER_LOCAL,
                    'root_prefix' => (string) $definition['root_prefix'],
                    'tenant_scoped' => (bool) $definition['tenant_scoped'],
                    'sort_order' => (int) $definition['sort_order'],
                    'metadata_json' => ['path_hint' => (string) $definition['path_hint']],
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function defaultRouteRows(): array
    {
        return array_map(
            fn (string $routeKey, array $definition): array => [
                'route_key' => $routeKey,
                'label' => (string) $definition['label'],
                'description' => (string) $definition['description'],
                'driver' => self::DRIVER_LOCAL,
                'root_prefix' => (string) $definition['root_prefix'],
                'tenant_scoped' => (bool) $definition['tenant_scoped'],
                'sort_order' => (int) $definition['sort_order'],
                'metadata_json' => ['path_hint' => (string) $definition['path_hint']],
            ],
            array_keys(self::routeDefinitions()),
            array_values(self::routeDefinitions()),
        );
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function serializeRoute(array $row): array
    {
        $metadata = is_array($row['metadata_json'] ?? null) ? $row['metadata_json'] : [];

        return [
            'route_key' => (string) $row['route_key'],
            'label' => (string) $row['label'],
            'description' => (string) ($row['description'] ?? ''),
            'driver' => (string) ($row['driver'] ?? self::DRIVER_LOCAL),
            'root_prefix' => (string) ($row['root_prefix'] ?? ''),
            'tenant_scoped' => (bool) ($row['tenant_scoped'] ?? true),
            'sort_order' => (int) ($row['sort_order'] ?? 0),
            'path_hint' => (string) ($metadata['path_hint'] ?? ''),
        ];
    }

    private function activeS3Connection(): ?PlatformStorageConnection
    {
        if (! $this->connectionsTableAvailable()) {
            return null;
        }

        return PlatformStorageConnection::query()
            ->whereKey(self::AWS_S3_ID)
            ->where('status', 'active')
            ->first();
    }

    /**
     * @return array<string, mixed>
     */
    private function s3DiskConfig(PlatformStorageConnection $connection): array
    {
        $config = [
            'driver' => 's3',
            'key' => $this->decryptNullable($connection->access_key_id_encrypted),
            'secret' => $this->decryptNullable($connection->secret_access_key_encrypted),
            'region' => (string) ($connection->region ?? ''),
            'bucket' => (string) ($connection->bucket ?? ''),
            'url' => $connection->url ?: null,
            'endpoint' => $connection->endpoint ?: null,
            'use_path_style_endpoint' => (bool) $connection->use_path_style_endpoint,
            'visibility' => (string) ($connection->visibility ?? 'private'),
            'throw' => false,
        ];

        $token = $this->decryptNullable($connection->session_token_encrypted);
        if ($token !== '') {
            $config['token'] = $token;
        }

        return $config;
    }

    private function localFallbackGet(string $key): ?string
    {
        try {
            return (string) $this->localDisk()->get($key);
        } catch (\Throwable) {
            return null;
        }
    }

    private function localAssetUrl(string $key, ?string $storageDriver = null): string
    {
        $base = trim((string) config('lottery_images.local_public_base_url', ''));

        if ($base === '') {
            $base = trim((string) config('lottery_images.cdn_base_url', ''));
        }

        if ($base === '') {
            $base = rtrim((string) config('app.url', 'http://localhost:8000'), '/').'/api/v1/public/assets';
        }

        $url = rtrim($base, '/').'/'.ltrim($key, '/');

        if (in_array($storageDriver, [self::DRIVER_LOCAL, self::DRIVER_AWS_S3], true)) {
            $url .= (str_contains($url, '?') ? '&' : '?').'storage_driver='.$storageDriver;
        }

        return $this->absoluteUrl($url);
    }

    private function absoluteUrl(string $url): string
    {
        $url = trim($url);

        if ((string) config('app.env', app()->environment()) !== 'production' && str_starts_with(strtolower($url), 'https://')) {
            return 'http://'.substr($url, 8);
        }

        return $url;
    }

    private function decryptNullable(?string $value): string
    {
        if ($value === null || trim($value) === '') {
            return '';
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return '';
        }
    }

    private function routesTableAvailable(): bool
    {
        try {
            return Schema::hasTable('platform_storage_routes');
        } catch (\Throwable) {
            return false;
        }
    }

    private function connectionsTableAvailable(): bool
    {
        try {
            return Schema::hasTable('platform_storage_connections');
        } catch (\Throwable) {
            return false;
        }
    }
}
