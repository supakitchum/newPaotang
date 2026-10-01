<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();
        $payload = [
            'value_json' => json_encode($this->projectLayout(), JSON_THROW_ON_ERROR),
            'status' => 'active',
            'updated_at' => $now,
        ];

        $setting = DB::table('platform_system_settings')->where('key', 'lottery_image_layout');

        if ($setting->exists()) {
            $setting->update($payload);

            return;
        }

        DB::table('platform_system_settings')->insert([
            'id' => 'pss_'.substr(sha1('lottery_image_layout'), 0, 20),
            'key' => 'lottery_image_layout',
            ...$payload,
            'created_at' => $now,
        ]);
    }

    public function down(): void
    {
        // Keep the current layout on rollback; this migration only adopts the project baseline.
    }

    /**
     * @return array<string, array<string, int|string|null>>
     */
    private function projectLayout(): array
    {
        return [
            'beside' => ['x' => 1, 'y' => 1, 'width' => 43, 'height' => 274],
            'emoji_1' => ['x' => 192, 'y' => 111, 'width' => 30, 'height' => null],
            'emoji_2' => ['x' => 220, 'y' => 111, 'width' => 30, 'height' => null],
            'emoji_3' => ['x' => 192, 'y' => 139, 'width' => 30, 'height' => null],
            'emoji_4' => ['x' => 220, 'y' => 139, 'width' => 30, 'height' => null],
            'number_digits' => ['x' => 257, 'y' => 36, 'width' => 25, 'height' => 20, 'gap' => 30],
            'text_eng' => ['x' => 258, 'y' => 63, 'width' => 12, 'height' => 7, 'gap' => 30],
            'thai_text' => ['x' => 460, 'y' => 30, 'size' => 23, 'angle' => 90, 'align' => 'right', 'valign' => 'top'],
            'num_set_center_left' => ['x' => 296, 'y' => 80, 'width' => 50, 'height' => 46],
            'num_set_center_right' => ['x' => 326, 'y' => 80, 'width' => 50, 'height' => 46],
            'num_set_right_left' => ['x' => 393, 'y' => 135, 'width' => 22, 'height' => 22],
            'num_set_right_right' => ['x' => 411, 'y' => 135, 'width' => 22, 'height' => 22],
            'num_set_bottom_left' => ['x' => 93, 'y' => 163, 'width' => 25, 'height' => 25],
            'num_set_bottom_right' => ['x' => 110, 'y' => 163, 'width' => 25, 'height' => 25],
            'logo_num_set' => ['x' => 80, 'y' => 155, 'width' => 70, 'height' => null],
            'logo_bottom' => ['x' => 245, 'y' => 90, 'width' => 200, 'height' => null],
            'logo_qr' => ['x' => 195, 'y' => 65, 'width' => 55, 'height' => null],
            'right_sidebar' => ['x' => 440, 'y' => 0, 'width' => 70, 'height' => null, 'rotate' => 90],
        ];
    }
};
