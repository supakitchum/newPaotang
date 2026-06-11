<?php

namespace App\Modules\StorageConnections\Services;

use App\Models\PlatformStorageConnection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class CentralStorageConnectionService
{
    private const AWS_S3_ID = 'storage_aws_s3';
    private const PROVIDER = 'aws_s3';

    public function __construct(private readonly RuntimeStorageService $runtimeStorage)
    {
    }

    public function show(): array
    {
        return [
            'connection' => $this->serializeConnection($this->connection()),
            'routes' => $this->runtimeStorage->routes(),
            'requirements' => $this->requirements(),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function update(array $payload, string $adminUserId): array
    {
        $existing = $this->connection();
        $normalized = $this->normalizePayload($payload);
        $errors = $this->validatePayload($normalized, $existing);
        $routePayload = is_array($payload['routes'] ?? null) ? $payload['routes'] : [];
        $routeErrors = $this->runtimeStorage->validateRoutes($routePayload);

        if ($routeErrors !== []) {
            $errors = array_replace_recursive($errors, $routeErrors);
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (! $this->encryptionKeyConfigured()) {
            return [
                'error' => 'storage_encryption_not_configured',
                'message' => 'APP_KEY is required before saving storage credentials.',
            ];
        }

        try {
            $encrypted = $this->encryptedSecrets($normalized, $existing);
        } catch (\Throwable) {
            return [
                'error' => 'storage_encryption_failed',
                'message' => 'Storage credentials could not be encrypted. Please save again.',
            ];
        }

        $now = now();

        PlatformStorageConnection::query()->updateOrCreate(
            ['id' => self::AWS_S3_ID],
            [
                'provider' => self::PROVIDER,
                'status' => $normalized['status'],
                'bucket' => $normalized['bucket'],
                'region' => $normalized['region'],
                'endpoint' => $normalized['endpoint'],
                'url' => $normalized['url'],
                'root_prefix' => $normalized['root_prefix'],
                'visibility' => $normalized['visibility'],
                'use_path_style_endpoint' => $normalized['use_path_style_endpoint'],
                'access_key_id_encrypted' => $encrypted['access_key_id_encrypted'],
                'secret_access_key_encrypted' => $encrypted['secret_access_key_encrypted'],
                'session_token_encrypted' => $encrypted['session_token_encrypted'],
                'metadata_json' => [
                    'updated_by' => $adminUserId,
                    'updated_from' => 'central_bo',
                    'runtime_disk' => 'route_based',
                    'asset_disk_hint' => (string) config('lottery_images.disk', 'lottery_images'),
                ],
                'updated_at' => $now,
            ],
        );

        if ($routePayload !== []) {
            $this->runtimeStorage->updateRoutes($routePayload);
        }

        return ['resource' => $this->show()];
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function updateRoutes(array $payload): array
    {
        $routePayload = is_array($payload['routes'] ?? null) ? $payload['routes'] : [];
        $result = $this->runtimeStorage->updateRoutes($routePayload);

        if (($result['errors'] ?? []) !== []) {
            return ['error' => 'validation_failed', 'errors' => $result['errors']];
        }

        return ['resource' => $this->show()];
    }

    public function disconnect(): array
    {
        PlatformStorageConnection::query()->whereKey(self::AWS_S3_ID)->delete();

        return ['resource' => $this->show()];
    }

    public function testConnection(): array
    {
        $connection = $this->connection();

        if (! $connection instanceof PlatformStorageConnection) {
            return [
                'error' => 'storage_connection_missing',
                'message' => 'Save AWS S3 settings before testing the connection.',
            ];
        }

        $config = $this->diskConfig($connection);
        $missing = [];

        foreach (['key', 'secret', 'region', 'bucket'] as $field) {
            if (trim((string) ($config[$field] ?? '')) === '') {
                $missing[] = $field;
            }
        }

        if ($missing !== []) {
            $this->markTest($connection, 'failed', 'Missing required S3 fields: '.implode(', ', $missing));

            return [
                'error' => 'storage_connection_incomplete',
                'message' => 'The AWS S3 connection is missing required fields.',
                'details' => ['missing' => $missing],
            ];
        }

        if (! class_exists('League\\Flysystem\\AwsS3V3\\AwsS3V3Adapter')) {
            $message = 'S3 adapter is not installed. Install league/flysystem-aws-s3-v3 before testing AWS S3 storage.';
            $this->markTest($connection, 'failed', $message);

            return [
                'error' => 's3_adapter_missing',
                'message' => $message,
            ];
        }

        $probeKey = $this->probeKey((string) ($connection->root_prefix ?? ''));
        $body = 'newPaotang storage probe '.Carbon::now('UTC')->toIso8601String();

        try {
            $disk = Storage::build($config);
            $disk->put($probeKey, $body);
            $readBack = $disk->get($probeKey);
            $disk->delete($probeKey);

            if ($readBack !== $body) {
                throw new \RuntimeException('S3 probe read-back mismatch.');
            }
        } catch (\Throwable $exception) {
            $message = 'AWS S3 probe failed: '.$exception->getMessage();
            $this->markTest($connection, 'failed', $message);

            return [
                'error' => 'storage_test_failed',
                'message' => $message,
            ];
        }

        $this->markTest($connection, 'passed', 'AWS S3 write/read/delete probe passed.', true);

        return ['resource' => $this->show()];
    }

    private function connection(): ?PlatformStorageConnection
    {
        return PlatformStorageConnection::query()->whereKey(self::AWS_S3_ID)->first();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizePayload(array $payload): array
    {
        $status = (string) ($payload['status'] ?? 'inactive');
        $visibility = (string) ($payload['visibility'] ?? 'private');

        return [
            'status' => in_array($status, ['active', 'inactive'], true)
                ? $status
                : 'inactive',
            'bucket' => $this->cleanString($payload['bucket'] ?? ''),
            'region' => $this->cleanString($payload['region'] ?? 'ap-southeast-1') ?: 'ap-southeast-1',
            'endpoint' => $this->nullableUrl($payload['endpoint'] ?? null),
            'url' => $this->nullableUrl($payload['url'] ?? null),
            'root_prefix' => trim($this->cleanString($payload['root_prefix'] ?? ''), '/'),
            'visibility' => in_array($visibility, ['private', 'public'], true)
                ? $visibility
                : 'private',
            'use_path_style_endpoint' => filter_var($payload['use_path_style_endpoint'] ?? false, FILTER_VALIDATE_BOOL),
            'access_key_id' => $this->cleanString($payload['access_key_id'] ?? ''),
            'secret_access_key' => $this->cleanString($payload['secret_access_key'] ?? ''),
            'session_token' => $this->cleanString($payload['session_token'] ?? ''),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validatePayload(array $payload, ?PlatformStorageConnection $existing): array
    {
        $errors = [];

        if ($payload['bucket'] === '') {
            $errors['bucket'][] = 'Bucket is required.';
        } elseif (! preg_match('/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/', (string) $payload['bucket'])) {
            $errors['bucket'][] = 'Bucket must be a valid S3 bucket name.';
        }

        if ($payload['region'] === '') {
            $errors['region'][] = 'Region is required.';
        }

        foreach (['endpoint', 'url'] as $urlField) {
            $value = (string) ($payload[$urlField] ?? '');
            if ($value !== '' && ! filter_var($value, FILTER_VALIDATE_URL)) {
                $errors[$urlField][] = 'Enter a valid URL.';
            }
        }

        if ((string) $payload['root_prefix'] !== '' && ! preg_match('/^[A-Za-z0-9._\\/-]+$/', (string) $payload['root_prefix'])) {
            $errors['root_prefix'][] = 'Prefix can contain letters, numbers, slash, dash, underscore, and dot only.';
        }

        if ((string) $payload['access_key_id'] === '' && ! $existing instanceof PlatformStorageConnection) {
            $errors['access_key_id'][] = 'Access key ID is required.';
        }

        if ((string) $payload['secret_access_key'] === '' && ! $existing instanceof PlatformStorageConnection) {
            $errors['secret_access_key'][] = 'Secret access key is required.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, string|null>
     */
    private function encryptedSecrets(array $payload, ?PlatformStorageConnection $existing): array
    {
        return [
            'access_key_id_encrypted' => (string) $payload['access_key_id'] !== ''
                ? Crypt::encryptString((string) $payload['access_key_id'])
                : $existing?->access_key_id_encrypted,
            'secret_access_key_encrypted' => (string) $payload['secret_access_key'] !== ''
                ? Crypt::encryptString((string) $payload['secret_access_key'])
                : $existing?->secret_access_key_encrypted,
            'session_token_encrypted' => (string) $payload['session_token'] !== ''
                ? Crypt::encryptString((string) $payload['session_token'])
                : $existing?->session_token_encrypted,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function diskConfig(PlatformStorageConnection $connection): array
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
            'throw' => true,
        ];

        $token = $this->decryptNullable($connection->session_token_encrypted);
        if ($token !== '') {
            $config['token'] = $token;
        }

        return $config;
    }

    private function serializeConnection(?PlatformStorageConnection $connection): array
    {
        if (! $connection instanceof PlatformStorageConnection) {
            return [
                'configured' => false,
                'provider' => self::PROVIDER,
                'status' => 'inactive',
                'bucket' => '',
                'region' => 'ap-southeast-1',
                'endpoint' => '',
                'url' => '',
                'root_prefix' => 'lotteries',
                'visibility' => 'private',
                'use_path_style_endpoint' => false,
                'access_key_id_masked' => '',
                'secret_access_key_configured' => false,
                'session_token_configured' => false,
                'last_test_status' => null,
                'last_test_message' => null,
                'last_tested_at' => null,
                'verified_at' => null,
                'updated_at' => null,
            ];
        }

        $accessKey = $this->decryptNullable($connection->access_key_id_encrypted);

        return [
            'configured' => true,
            'provider' => (string) $connection->provider,
            'status' => (string) $connection->status,
            'bucket' => (string) ($connection->bucket ?? ''),
            'region' => (string) ($connection->region ?? ''),
            'endpoint' => (string) ($connection->endpoint ?? ''),
            'url' => (string) ($connection->url ?? ''),
            'root_prefix' => (string) ($connection->root_prefix ?? ''),
            'visibility' => (string) ($connection->visibility ?? 'private'),
            'use_path_style_endpoint' => (bool) $connection->use_path_style_endpoint,
            'access_key_id_masked' => $this->mask($accessKey),
            'secret_access_key_configured' => $connection->secret_access_key_encrypted !== null,
            'session_token_configured' => $connection->session_token_encrypted !== null,
            'last_test_status' => $connection->last_test_status,
            'last_test_message' => $connection->last_test_message,
            'last_tested_at' => $connection->last_tested_at?->toIso8601String(),
            'verified_at' => $connection->verified_at?->toIso8601String(),
            'updated_at' => $connection->updated_at?->toIso8601String(),
        ];
    }

    private function requirements(): array
    {
        return [
            'adapter_installed' => class_exists('League\\Flysystem\\AwsS3V3\\AwsS3V3Adapter'),
            'required_package' => 'league/flysystem-aws-s3-v3',
            'runtime_disk' => 'route_based',
            'asset_disk_hint' => (string) config('lottery_images.disk', 'lottery_images'),
            'notes' => [
                'Credentials are encrypted and never returned by API.',
                'Test connection writes, reads, and deletes one probe object.',
                'Choose AWS S3 per upload category below when the runtime should use this bucket.',
            ],
        ];
    }

    private function markTest(PlatformStorageConnection $connection, string $status, string $message, bool $verified = false): void
    {
        $connection->fill([
            'last_test_status' => $status,
            'last_test_message' => Str::limit($message, 1000, ''),
            'last_tested_at' => now(),
            'verified_at' => $verified ? now() : $connection->verified_at,
            'status' => $verified ? 'active' : $connection->status,
            'updated_at' => now(),
        ])->save();
    }

    private function encryptionKeyConfigured(): bool
    {
        return trim((string) config('app.key')) !== '';
    }

    private function cleanString(mixed $value): string
    {
        return trim((string) $value);
    }

    private function nullableUrl(mixed $value): string
    {
        return rtrim($this->cleanString($value), '/');
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

    private function mask(string $value): string
    {
        if ($value === '') {
            return '';
        }

        if (strlen($value) <= 8) {
            return str_repeat('*', strlen($value));
        }

        return substr($value, 0, 4).str_repeat('*', max(4, strlen($value) - 8)).substr($value, -4);
    }

    private function probeKey(string $prefix): string
    {
        $base = trim($prefix, '/');
        $key = 'newpaotang-storage-probe/'.Str::uuid().'.txt';

        return $base === '' ? $key : $base.'/'.$key;
    }
}
