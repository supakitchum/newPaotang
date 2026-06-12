<?php

namespace Tests\Feature;

use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CentralStorageConnectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_platform_owner_can_save_aws_s3_connection_without_leaking_secrets(): void
    {
        $this->seed(DatabaseSeeder::class);
        $login = $this->loginCentral('superadmin');

        $response = $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/storage-connections/aws-s3', [
                'status' => 'active',
                'bucket' => 'newpaotang-assets',
                'region' => 'ap-southeast-1',
                'endpoint' => 'https://s3.ap-southeast-1.amazonaws.com',
                'url' => 'https://cdn.example.test',
                'root_prefix' => 'lotteries',
                'visibility' => 'private',
                'use_path_style_endpoint' => false,
                'access_key_id' => 'AKIA1234567890TEST',
                'secret_access_key' => 'super-secret-access-key',
                'routes' => [
                    [
                        'route_key' => 'payment_slips',
                        'driver' => 'aws_s3',
                        'root_prefix' => 'slips',
                    ],
                    [
                        'route_key' => 'lottery_images',
                        'driver' => 'local',
                        'root_prefix' => '',
                    ],
                ],
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('connection.configured', true)
            ->assertJsonPath('connection.status', 'active')
            ->assertJsonPath('connection.bucket', 'newpaotang-assets')
            ->assertJsonFragment([
                'route_key' => 'payment_slips',
                'driver' => 'aws_s3',
                'root_prefix' => 'slips',
            ])
            ->assertJsonMissing(['secret_access_key' => 'super-secret-access-key'])
            ->json();

        $this->assertSame('AKIA**********TEST', $response['connection']['access_key_id_masked']);
        $this->assertTrue($response['connection']['secret_access_key_configured']);

        $row = DB::table('platform_storage_connections')->where('id', 'storage_aws_s3')->first();

        $this->assertNotNull($row);
        $this->assertNotSame('AKIA1234567890TEST', $row->access_key_id_encrypted);
        $this->assertNotSame('super-secret-access-key', $row->secret_access_key_encrypted);
        $this->assertSame('AKIA1234567890TEST', Crypt::decryptString($row->access_key_id_encrypted));
        $this->assertSame('super-secret-access-key', Crypt::decryptString($row->secret_access_key_encrypted));
        $this->assertDatabaseHas('platform_storage_routes', [
            'route_key' => 'payment_slips',
            'driver' => 'aws_s3',
            'root_prefix' => 'slips',
        ]);
    }

    public function test_non_platform_owner_cannot_view_or_manage_storage_connections(): void
    {
        $this->seed(DatabaseSeeder::class);
        $translator = $this->loginCentral('translator');

        $this->withToken($translator['access_token'])
            ->getJson('/api/v1/admin/central/storage-connections/aws-s3', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_platform_owner_can_save_upload_routes_separately_from_connection_settings(): void
    {
        $this->seed(DatabaseSeeder::class);
        $login = $this->loginCentral('superadmin');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/storage-connections/aws-s3', [
                'status' => 'active',
                'bucket' => 'newpaotang-assets',
                'region' => 'ap-southeast-1',
                'access_key_id' => 'AKIA1234567890TEST',
                'secret_access_key' => 'super-secret-access-key',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk();

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/storage-connections/upload-routes', [
                'routes' => [
                    [
                        'route_key' => 'payment_slips',
                        'driver' => 'aws_s3',
                        'root_prefix' => 'tenant-slips',
                    ],
                    [
                        'route_key' => 'activity_images',
                        'driver' => 'local',
                        'root_prefix' => 'activity-local',
                    ],
                ],
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('connection.bucket', 'newpaotang-assets')
            ->assertJsonFragment([
                'route_key' => 'payment_slips',
                'driver' => 'aws_s3',
                'root_prefix' => 'tenant-slips',
            ]);

        $this->assertDatabaseHas('platform_storage_routes', [
            'route_key' => 'payment_slips',
            'driver' => 'aws_s3',
            'root_prefix' => 'tenant-slips',
        ]);
    }

    public function test_s3_connection_test_reports_missing_adapter_without_breaking_saved_config(): void
    {
        if (class_exists('League\\Flysystem\\AwsS3V3\\AwsS3V3Adapter')) {
            $this->markTestSkipped('S3 adapter is installed in this environment.');
        }

        $this->seed(DatabaseSeeder::class);
        $login = $this->loginCentral('superadmin');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/storage-connections/aws-s3', [
                'status' => 'active',
                'bucket' => 'newpaotang-assets',
                'region' => 'ap-southeast-1',
                'access_key_id' => 'AKIA1234567890TEST',
                'secret_access_key' => 'super-secret-access-key',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/storage-connections/aws-s3/test', [], ['X-Admin-Scope' => 'central'])
            ->assertStatus(503)
            ->assertJsonPath('error.code', 's3_adapter_missing');

        $this->assertDatabaseHas('platform_storage_connections', [
            'id' => 'storage_aws_s3',
            'last_test_status' => 'failed',
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function loginCentral(string $username): array
    {
        return $this->postJson('/api/v1/auth/admin/login', [
            'email' => $username,
            'password' => '1234',
            'scope' => 'central',
        ])
            ->assertOk()
            ->json();
    }
}
