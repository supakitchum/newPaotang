<?php

namespace App\Support;

final class ThaiBankCatalog
{
    /**
     * @return array<int, array{code: string, name: string, icon: string}>
     */
    public static function all(): array
    {
        return [
            ['code' => 'bbl', 'name' => 'ธนาคารกรุงเทพ', 'icon' => 'bi-bank'],
            ['code' => 'kbank', 'name' => 'ธนาคารกสิกรไทย', 'icon' => 'bi-bank'],
            ['code' => 'ktb', 'name' => 'ธนาคารกรุงไทย', 'icon' => 'bi-bank'],
            ['code' => 'ttb', 'name' => 'ธนาคารทหารไทยธนชาต', 'icon' => 'bi-bank'],
            ['code' => 'scb', 'name' => 'ธนาคารไทยพาณิชย์', 'icon' => 'bi-bank'],
            ['code' => 'bay', 'name' => 'ธนาคารกรุงศรีอยุธยา', 'icon' => 'bi-bank'],
            ['code' => 'gsb', 'name' => 'ธนาคารออมสิน', 'icon' => 'bi-bank'],
            ['code' => 'baac', 'name' => 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร', 'icon' => 'bi-bank'],
            ['code' => 'ghb', 'name' => 'ธนาคารอาคารสงเคราะห์', 'icon' => 'bi-bank'],
            ['code' => 'uob', 'name' => 'ธนาคารยูโอบี', 'icon' => 'bi-bank'],
            ['code' => 'cimb', 'name' => 'ธนาคารซีไอเอ็มบีไทย', 'icon' => 'bi-bank'],
            ['code' => 'kkp', 'name' => 'ธนาคารเกียรตินาคินภัทร', 'icon' => 'bi-bank'],
            ['code' => 'tisco', 'name' => 'ธนาคารทิสโก้', 'icon' => 'bi-bank'],
            ['code' => 'lhbank', 'name' => 'ธนาคารแลนด์ แอนด์ เฮ้าส์', 'icon' => 'bi-bank'],
            ['code' => 'thai_credit', 'name' => 'ธนาคารไทยเครดิต', 'icon' => 'bi-bank'],
            ['code' => 'icbc', 'name' => 'ธนาคารไอซีบีซี (ไทย)', 'icon' => 'bi-bank'],
        ];
    }

    /**
     * @return array{code: string, name: string, icon: string}|null
     */
    public static function findByCodeOrName(?string $value): ?array
    {
        $needle = trim((string) $value);

        if ($needle === '') {
            return null;
        }

        $normalized = strtolower($needle);

        foreach (self::all() as $bank) {
            if ($normalized === strtolower($bank['code']) || $normalized === strtolower($bank['name'])) {
                return $bank;
            }
        }

        return null;
    }
}
