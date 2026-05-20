<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

return new class extends Migration
{
    private const SLOT_COLUMNS = [
        'logo_qr' => ['asset_id' => 'logo_qr_asset_id', 'path' => 'logo_qr_storage_path', 'file' => 'logo_qr.webp'],
        'right_sidebar' => ['asset_id' => 'right_sidebar_asset_id', 'path' => 'right_sidebar_storage_path', 'file' => 'rightsidebar.webp'],
        'logo_bottom' => ['asset_id' => 'logo_bottom_asset_id', 'path' => 'logo_bottom_storage_path', 'file' => 'logo_bottom.webp'],
    ];

    public function up(): void
    {
        Schema::table('tickets', function (Blueprint $table): void {
            if (! Schema::hasColumn('tickets', 'image_render_snapshot_json')) {
                $table->json('image_render_snapshot_json')->nullable()->after('image_thumb_url');
            }
        });

        $this->canonicalizeBrandingAssets();
    }

    public function down(): void
    {
        Schema::table('tickets', function (Blueprint $table): void {
            if (Schema::hasColumn('tickets', 'image_render_snapshot_json')) {
                $table->dropColumn('image_render_snapshot_json');
            }
        });
    }

    private function canonicalizeBrandingAssets(): void
    {
        if (! Schema::hasTable('partner_lottery_branding_asset_sets') || ! Schema::hasTable('platform_assets')) {
            return;
        }

        $disk = Storage::disk((string) config('lottery_images.disk', 'lottery_images'));
        $sets = DB::table('partner_lottery_branding_asset_sets')->orderBy('id')->get();

        foreach ($sets as $set) {
            $version = trim((string) ($set->version ?? 'v1')) !== '' ? (string) $set->version : 'v1';

            foreach (self::SLOT_COLUMNS as $slot => $columns) {
                $assetId = (string) ($set->{$columns['asset_id']} ?? '');

                if ($assetId === '') {
                    continue;
                }

                $canonicalKey = 'partners/'.$set->partner_id.'/lottery-branding/'.$version.'/'.$columns['file'];
                $oldPath = (string) ($set->{$columns['path']} ?? '');
                $asset = DB::table('platform_assets')->where('id', $assetId)->first();
                $oldKey = $asset?->storage_key ? (string) $asset->storage_key : $oldPath;

                if ($oldKey !== '' && $oldKey !== $canonicalKey && $disk->exists($oldKey) && ! $disk->exists($canonicalKey)) {
                    $disk->copy($oldKey, $canonicalKey);
                }

                $metadata = $asset?->metadata_json;
                $decoded = is_string($metadata) ? json_decode($metadata, true) : [];
                $decoded = is_array($decoded) ? $decoded : [];
                $decoded['branding_slot'] = $slot;
                $decoded['partner_id'] = (string) $set->partner_id;
                $decoded['version'] = $version;
                $decoded['canonicalized_at_migration'] = true;
                if ($oldKey !== '' && $oldKey !== $canonicalKey) {
                    $decoded['previous_storage_key'] = $oldKey;
                }

                DB::table('platform_assets')->where('id', $assetId)->update([
                    'purpose' => 'partner_lottery_branding',
                    'file_name' => $columns['file'],
                    'content_type' => 'image/webp',
                    'storage_key' => $canonicalKey,
                    'public_url' => $this->publicUrl($canonicalKey),
                    'metadata_json' => json_encode($decoded, JSON_THROW_ON_ERROR),
                    'updated_at' => now(),
                ]);

                DB::table('partner_lottery_branding_asset_sets')->where('id', $set->id)->update([
                    $columns['path'] => $canonicalKey,
                    'updated_at' => now(),
                ]);
            }
        }
    }

    private function publicUrl(string $key): string
    {
        $baseUrl = rtrim((string) config('lottery_images.cdn_base_url', ''), '/');

        return $baseUrl !== '' ? $baseUrl.'/'.ltrim($key, '/') : Storage::disk((string) config('lottery_images.disk', 'lottery_images'))->url($key);
    }
};
