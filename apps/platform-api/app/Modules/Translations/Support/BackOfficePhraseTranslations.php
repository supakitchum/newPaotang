<?php

namespace App\Modules\Translations\Support;

class BackOfficePhraseTranslations
{
    public static function translate(string $source, string $locale): ?string
    {
        $text = self::normalize($source);
        if ($text === '' || self::isTechnicalNoise($text)) {
            return null;
        }

        if ($locale === 'en-US') {
            return self::thaiToEnglish()[$text] ?? null;
        }

        if ($locale !== 'th-TH' || ! self::hasLatin($text)) {
            return null;
        }

        $exact = self::englishToThai();
        if (isset($exact[$text])) {
            return $exact[$text];
        }

        foreach (self::patternTranslations() as [$pattern, $builder]) {
            if (preg_match($pattern, $text, $matches) === 1) {
                return $builder($matches);
            }
        }

        return self::label($text);
    }

    private static function normalize(string $value): string
    {
        return trim((string) preg_replace('/\s+/u', ' ', html_entity_decode($value, ENT_QUOTES | ENT_HTML5, 'UTF-8')));
    }

    private static function hasLatin(string $value): bool
    {
        return preg_match('/[A-Za-z]/u', $value) === 1;
    }

    private static function isTechnicalNoise(string $value): bool
    {
        return $value === ''
            || preg_match('/<[^>]+>/', $value) === 1
            || preg_match('/\b(?:Nuxt|DevTools|Discord|GitHub|Twitter|documentation icon|examples icon|modules icon)\b/i', $value) === 1
            || preg_match('/\b(?:error\.message|t\(|spawn|spawnSync|ENOENT|localhost|foo\.com|hello world)\b/i', $value) === 1
            || preg_match('/^[^\s@]+@[^\s@]+\.[^\s@]+$/', $value) === 1
            || preg_match('/^https?:\/\//i', $value) === 1
            || preg_match('/^[a-z0-9_.\/:-]+\.(?:test|com|org|dev)(?:\/.*)?$/i', $value) === 1
            || preg_match('/\\\\n|\\n/', $value) === 1;
    }

    /**
     * @return array<int, array{0: string, 1: callable(array<int, string>): string|null}>
     */
    private static function patternTranslations(): array
    {
        return [
            ['/^(?:Create|New) (.+)$/', fn (array $m): ?string => 'สร้าง'.self::label($m[1])],
            ['/^Update (.+)$/', fn (array $m): ?string => 'อัปเดต'.self::label($m[1])],
            ['/^Edit (.+)$/', fn (array $m): ?string => 'แก้ไข'.self::label($m[1])],
            ['/^Delete (.+)$/', fn (array $m): ?string => 'ลบ'.self::label($m[1])],
            ['/^Save (.+)$/', fn (array $m): ?string => 'บันทึก'.self::label($m[1])],
            ['/^Set (.+)$/', fn (array $m): ?string => 'ตั้งค่า'.self::label($m[1])],
            ['/^Import (.+)$/', fn (array $m): ?string => 'นำเข้า'.self::label($m[1])],
            ['/^Export (.+)$/', fn (array $m): ?string => 'ส่งออก'.self::label($m[1])],
            ['/^Apply (.+)$/', fn (array $m): ?string => 'ใช้'.self::label($m[1])],
            ['/^Select (.+)$/', fn (array $m): ?string => 'เลือก'.self::label($m[1])],
            ['/^No (.+)$/', fn (array $m): ?string => 'ไม่มี'.self::label($m[1])],
            ['/^(.+) detail$/i', fn (array $m): ?string => 'รายละเอียด'.self::label($m[1])],
            ['/^(.+) status$/i', fn (array $m): ?string => 'สถานะ'.self::label($m[1])],
            ['/^(.+) amount$/i', fn (array $m): ?string => 'จำนวนเงิน'.self::label($m[1])],
            ['/^(.+) count$/i', fn (array $m): ?string => 'จำนวน'.self::label($m[1])],
            ['/^(.+) ID$/', fn (array $m): ?string => 'ID '.self::label($m[1])],
            ['/^(.+) URL$/', fn (array $m): ?string => 'URL '.self::label($m[1])],
            ['/^(.+) JSON$/', fn (array $m): ?string => 'JSON '.self::label($m[1])],
            ['/^(.+) \\(THB\\)$/', fn (array $m): ?string => self::label($m[1]).' (บาท)'],
            ['/^(.+) from$/i', fn (array $m): ?string => self::label($m[1]).'ตั้งแต่'],
            ['/^(.+) to$/i', fn (array $m): ?string => self::label($m[1]).'ถึง'],
            ['/^Optional (.+)$/', fn (array $m): ?string => self::label($m[1]).' (ไม่บังคับ)'],
            ['/^Leave blank to (.+)$/', fn (array $m): ?string => 'เว้นว่างเพื่อ'.self::actionLabel($m[1])],
            ['/^Leave blank for (.+)$/', fn (array $m): ?string => 'เว้นว่างสำหรับ'.self::label($m[1])],
            ['/^Back to (.+)$/', fn (array $m): ?string => 'กลับไป'.self::label($m[1])],
            ['/^(.+) included$/i', fn (array $m): ?string => 'รวม'.self::label($m[1])],
            ['/^(.+) enabled$/i', fn (array $m): ?string => 'เปิดใช้'.self::label($m[1])],
            ['/^(.+) ready$/i', fn (array $m): ?string => self::label($m[1]).'พร้อมใช้งาน'],
            ['/^(.+) left$/i', fn (array $m): ?string => self::label($m[1]).'คงเหลือ'],
            ['/^(.+) remaining$/i', fn (array $m): ?string => self::label($m[1]).'คงเหลือ'],
            ['/^(.+) total$/i', fn (array $m): ?string => self::label($m[1]).'รวม'],
            ['/^All (.+)$/', fn (array $m): ?string => self::label($m[1]).'ทั้งหมด'],
            ['/^Current (.+)$/', fn (array $m): ?string => self::label($m[1]).'ปัจจุบัน'],
            ['/^Default (.+)$/', fn (array $m): ?string => self::label($m[1]).'เริ่มต้น'],
            ['/^Partner (.+)$/', fn (array $m): ?string => self::label('Partner').' '.self::label($m[1])],
            ['/^Tenant (.+)$/', fn (array $m): ?string => self::label('Tenant').' '.self::label($m[1])],
            ['/^Central (.+)$/', fn (array $m): ?string => self::label('Central').' '.self::label($m[1])],
        ];
    }

    private static function label(string $source): string
    {
        $text = self::normalize($source);
        $terms = self::terms();

        if (isset($terms[$text])) {
            return $terms[$text];
        }

        $titleCase = mb_convert_case($text, MB_CASE_TITLE, 'UTF-8');
        if (isset($terms[$titleCase])) {
            return $terms[$titleCase];
        }

        $text = str_replace([' And ', ' and ', ' & '], ' / ', $text);
        if (str_contains($text, ' / ')) {
            $parts = array_map(fn (string $part): string => self::label($part), explode(' / ', $text));

            return implode(' / ', array_filter($parts));
        }

        $text = preg_replace('/\\s+\\(บาท\\)$/u', ' (บาท)', $text) ?? $text;
        $words = preg_split('/\s+/', $text) ?: [];
        $translated = [];
        foreach ($words as $word) {
            $clean = trim($word, " \t\n\r\0\x0B:,.()[]");
            if ($clean === '') {
                continue;
            }

            $translated[] = $terms[$clean]
                ?? $terms[ucfirst(strtolower($clean))]
                ?? $terms[strtoupper($clean)]
                ?? $clean;
        }

        return trim(implode(' ', $translated));
    }

    private static function actionLabel(string $source): string
    {
        $text = self::normalize($source);
        $actions = [
            'keep current credential' => 'เก็บข้อมูลเข้าสู่ระบบเดิมไว้',
            'keep existing secret' => 'เก็บ secret เดิมไว้',
            'keep generated/default handling' => 'ใช้ค่าที่ระบบสร้างหรือค่าเริ่มต้นเดิม',
            'use Central default' => 'ใช้ค่าเริ่มต้นจาก Central',
        ];

        return $actions[strtolower($text)] ?? self::label($text);
    }

    /**
     * @return array<string, string>
     */
    private static function englishToThai(): array
    {
        return [
            'Active %' => '% ที่ใช้งานอยู่',
            'Active partner percent' => 'เปอร์เซ็นต์พาร์ทเนอร์ที่ใช้งานอยู่',
            'Add a domain when this tenant needs an operator-managed host.' => 'เพิ่มโดเมนเมื่อร้านค้านี้ต้องใช้ host ที่ผู้ดูแลระบบจัดการ',
            'Approved, rejected, cancelled, and paid reward exchanges will appear here.' => 'รายการขึ้นเงินรางวัลที่อนุมัติ ปฏิเสธ ยกเลิก และจ่ายแล้วจะแสดงที่นี่',
            'Are you sure?' => 'ยืนยันการทำรายการ?',
            'Base values for Generate Stock and Stock Pattern Coverage forms.' => 'ค่าเริ่มต้นสำหรับฟอร์มสร้างสต็อกและตรวจ coverage pattern',
            'Blank removes override' => 'เว้นว่างเพื่อลบค่า override',
            'Central and partner limits for back/front number patterns.' => 'ขีดจำกัดของ Central และพาร์ทเนอร์สำหรับเลขหน้า/เลขท้าย',
            'Central and tenant operations, rendered through backend RBAC menus and Meno dashboard patterns.' => 'จัดการระบบส่วนกลางและร้านค้าโดยอิงสิทธิ์จาก backend RBAC และรูปแบบแดชบอร์ด Meno',
            'Central maintenance only affects this Partner Back Office. Central admin remains available.' => 'การปิดปรับปรุงจาก Central กระทบเฉพาะ Back Office ของพาร์ทเนอร์นี้ ส่วน Central admin ยังใช้งานได้',
            'Confirmation will resubmit the current menu tree for this scope.' => 'การยืนยันจะส่งโครงสร้างเมนูปัจจุบันของ scope นี้อีกครั้ง',
            'Copy the URL to the clipboard' => 'คัดลอก URL ไปยังคลิปบอร์ด',
            'Coverage reloads from HTTP when realtime is unavailable.' => 'Coverage จะโหลดผ่าน HTTP เมื่อ realtime ไม่พร้อมใช้งาน',
            'Coverage websocket is connected.' => 'Coverage websocket เชื่อมต่อแล้ว',
            'Coverage websocket is connecting.' => 'Coverage websocket กำลังเชื่อมต่อ',
            'Coverage websocket needs attention.' => 'Coverage websocket ต้องตรวจสอบ',
            'Customer reward exchange requests will appear here after customers choose wallet or bank payout.' => 'คำขอขึ้นเงินรางวัลจะแสดงที่นี่หลังลูกค้าเลือกจ่ายเข้ากระเป๋าหรือบัญชีธนาคาร',
            'Detail JSON is invalid or could not be saved.' => 'Detail JSON ไม่ถูกต้องหรือไม่สามารถบันทึกได้',
            'Dynamic values are escaped automatically. Static tags can use Telegram HTML such as &lt;b&gt;.' => 'ระบบ escape ค่า dynamic ให้อัตโนมัติ ส่วน tag คงที่สามารถใช้ Telegram HTML เช่น &lt;b&gt; ได้',
            'Edit system translations and submit deploy requests for Platform Owner approval.' => 'แก้ไขคำแปลของระบบและส่งคำขอ deploy ให้ Platform Owner ตรวจอนุมัติ',
            'Images not reported by batch API' => 'รูปที่ batch API ยังไม่รายงาน',
            'Images not started' => 'รูปที่ยังไม่เริ่มดำเนินการ',
            'Images waiting for stock' => 'รูปที่รอสต็อก',
            'Invalid input' => 'ข้อมูลไม่ถูกต้อง',
            'Leave blank for backend-generated secret' => 'เว้นว่างเพื่อให้ backend สร้าง secret',
            'Leave blank for tenant-wide quota' => 'เว้นว่างเพื่อใช้โควต้าระดับร้านค้า',
            'Leave blank to keep current credential' => 'เว้นว่างเพื่อใช้ข้อมูลเข้าสู่ระบบเดิม',
            'Leave blank to keep existing secret' => 'เว้นว่างเพื่อเก็บ secret เดิมไว้',
            'Leave blank to keep generated/default handling' => 'เว้นว่างเพื่อใช้ค่าที่ระบบสร้างหรือค่าเริ่มต้นเดิม',
            'Leave blank to use Central default' => 'เว้นว่างเพื่อใช้ค่าเริ่มต้นจาก Central',
            'Loading options...' => 'กำลังโหลดตัวเลือก...',
            'Must not exceed central' => 'ต้องไม่เกินค่าของ Central',
            'Name to use in the banner' => 'ชื่อที่ใช้บนแบนเนอร์',
            'No coverage rows matched the selected game, scope, or pattern search.' => 'ไม่พบแถว coverage ที่ตรงกับเกม scope หรือ pattern ที่เลือก',
            'No data was returned for this report section.' => 'ส่วนรายงานนี้ไม่มีข้อมูล',
            'No ledger entries were returned for this wallet.' => 'ไม่พบรายการ ledger ของกระเป๋านี้',
            'No stock coverage rows matched this game.' => 'ไม่พบแถว stock coverage ของเกมนี้',
            'No summary values were returned for this report.' => 'รายงานนี้ไม่มีค่าสรุป',
            'No topup requests are waiting for review.' => 'ไม่มีรายการเติมเงินที่รอตรวจสอบ',
            'Only menu items returned by the backend are searchable.' => 'ค้นหาได้เฉพาะเมนูที่ backend ส่งกลับมาเท่านั้น',
            'Optional internal note for audit context' => 'บันทึกภายในสำหรับ audit context (ไม่บังคับ)',
            'Optional password for safe local fixture members' => 'รหัสผ่านสำหรับบัญชีทดสอบ local (ไม่บังคับ)',
            'Optional; backend derives one from the name' => 'ไม่บังคับ; backend จะสร้างจากชื่อให้',
            'Partner Back Office is under maintenance' => 'Back Office ของพาร์ทเนอร์อยู่ระหว่างปิดปรับปรุง',
            'Partner pattern availability for the selected tenant game.' => 'ความพร้อมของ pattern พาร์ทเนอร์สำหรับเกมร้านค้าที่เลือก',
            'Permission denied by backend scope. Menu visibility is not authorization.' => 'ถูกปฏิเสธสิทธิ์โดย backend scope การเห็นเมนูไม่ใช่สิทธิ์อนุญาต',
            'Permission denied by platform-api.' => 'ถูกปฏิเสธสิทธิ์โดย platform-api',
            'Queued, processing, completed, and failed stock generation batches for the selected game.' => 'batch สร้างสต็อกของเกมที่เลือก ทั้งรอคิว กำลังทำ เสร็จแล้ว และล้มเหลว',
            'Realtime is not configured.' => 'ยังไม่ได้ตั้งค่า realtime',
            'Review the scope and changed menu items before saving this full menu tree.' => 'ตรวจสอบ scope และเมนูที่เปลี่ยนก่อนบันทึก menu tree ทั้งชุด',
            'Reviewed, cancelled, and expired topups will appear here.' => 'รายการเติมเงินที่ตรวจแล้ว ยกเลิก และหมดอายุจะแสดงที่นี่',
            'Reward exchange requests waiting for approval will appear here.' => 'คำขอขึ้นเงินรางวัลที่รออนุมัติจะแสดงที่นี่',
            'Secure tenant operations for this partner domain.' => 'จัดการงานร้านค้าอย่างปลอดภัยสำหรับโดเมนพาร์ทเนอร์นี้',
            'Select a current game to load stock generation batch progress.' => 'เลือกเกมปัจจุบันเพื่อโหลดความคืบหน้า batch สร้างสต็อก',
            'Select a game to load pattern coverage.' => 'เลือกเกมเพื่อโหลด pattern coverage',
            'Select a game to load stock coverage.' => 'เลือกเกมเพื่อโหลด stock coverage',
            'Select a game to load stock generation summary widgets.' => 'เลือกเกมเพื่อโหลด widget สรุปการสร้างสต็อก',
            'Select a game to subscribe to coverage updates.' => 'เลือกเกมเพื่อติดตามอัปเดต coverage',
            'Select a game to subscribe to stock coverage updates.' => 'เลือกเกมเพื่อติดตามอัปเดต stock coverage',
            'Settings JSON is invalid or could not be saved.' => 'Settings JSON ไม่ถูกต้องหรือไม่สามารถบันทึกได้',
            'Shown to operators/customers where supported' => 'แสดงให้ผู้ดูแลหรือลูกค้าในจุดที่รองรับ',
            'Stock coverage websocket is connected.' => 'Stock coverage websocket เชื่อมต่อแล้ว',
            'Stock coverage websocket is connecting.' => 'Stock coverage websocket กำลังเชื่อมต่อ',
            'Stored redacted by backend' => 'backend เก็บแบบปิดบังข้อมูลสำคัญ',
            'Submitted stock generation batches for this game will appear here.' => 'batch สร้างสต็อกที่ส่งสำหรับเกมนี้จะแสดงที่นี่',
            'The admin page was not found.' => 'ไม่พบหน้าผู้ดูแลระบบ',
            'The admin shell hit an unexpected state.' => 'Admin shell พบสถานะที่ไม่คาดคิด',
            'The request payload is invalid.' => 'ข้อมูลที่ส่งมาไม่ถูกต้อง',
            'There is nothing to show yet.' => 'ยังไม่มีข้อมูลให้แสดง',
            'This customer has no detail data to display yet.' => 'ลูกค้ารายนี้ยังไม่มีข้อมูลรายละเอียด',
            'This customer has no order history records.' => 'ลูกค้ารายนี้ยังไม่มีประวัติคำสั่งซื้อ',
            'This list is empty.' => 'รายการนี้ว่าง',
            'This order has no detail data to display yet.' => 'คำสั่งซื้อนี้ยังไม่มีข้อมูลรายละเอียด',
            'This partner has no data to display yet.' => 'พาร์ทเนอร์นี้ยังไม่มีข้อมูล',
            'This payout rule has no data to display yet.' => 'กฎการจ่ายรางวัลนี้ยังไม่มีข้อมูล',
            'This record has no data to display yet.' => 'รายการนี้ยังไม่มีข้อมูลรายละเอียด',
            'This reward result has no prize rows yet.' => 'ผลรางวัลนี้ยังไม่มีแถวรางวัล',
            'This stock record has no data to display yet.' => 'รายการสต็อกนี้ยังไม่มีข้อมูล',
            'This topup has no detail data to display yet.' => 'รายการเติมเงินนี้ยังไม่มีข้อมูลรายละเอียด',
            'This wallet has no detail data to display yet.' => 'กระเป๋านี้ยังไม่มีข้อมูลรายละเอียด',
            'Try changing filters or create a new record.' => 'ลองเปลี่ยนตัวกรองหรือสร้างรายการใหม่',
            'Use an approved central or tenant admin account.' => 'ใช้บัญชีผู้ดูแล Central หรือร้านค้าที่ได้รับอนุมัติ',
            'Use an approved tenant admin account.' => 'ใช้บัญชีผู้ดูแลร้านค้าที่ได้รับอนุมัติ',
            'You won\'t be able to revert this!' => 'คุณจะไม่สามารถย้อนกลับรายการนี้ได้',
        ] + self::additionalEnglishToThai();
    }

    /**
     * @return array<string, string>
     */
    private static function additionalEnglishToThai(): array
    {
        return [
            'API clients' => 'API clients',
            'Accent color' => 'สีเน้น',
            'Account number' => 'เลขบัญชี',
            'Add set' => 'เพิ่มชุด',
            'Allowed routes' => 'Route ที่อนุญาต',
            'Assigned capacity' => 'จำนวนที่จัดสรร',
            'Back 2' => 'เลขท้าย 2 ตัว',
            'Back 3' => 'เลขท้าย 3 ตัว',
            'Background color' => 'สีพื้นหลัง',
            'Central Queue' => 'คิว Central',
            'Central ceiling' => 'เพดาน Central',
            'Central price' => 'ราคา Central',
            'Central rows' => 'แถว Central',
            'Changed context' => 'บริบทที่เปลี่ยน',
            'Changed items' => 'รายการที่เปลี่ยน',
            'Check again' => 'ตรวจสอบอีกครั้ง',
            'Close sidebar' => 'ปิด sidebar',
            'Cloudflare proxy verified' => 'ยืนยัน Cloudflare proxy แล้ว',
            'Coverage rows' => 'แถว coverage',
            'Credit card' => 'บัตรเครดิต',
            'Deployment mode' => 'โหมด deploy',
            'Ends at' => 'เวลาสิ้นสุด',
            'Estimated supply' => 'จำนวน supply โดยประมาณ',
            'Fallback HTTP' => 'HTTP สำรอง',
            'Full WebP' => 'ไฟล์ WebP ขนาดเต็ม',
            'Full numbers' => 'เลขเต็ม',
            'Generated capacity' => 'จำนวนที่สร้างแล้ว',
            'Generation progress' => 'ความคืบหน้าการสร้าง',
            'Lifecycle transition' => 'การเปลี่ยนสถานะ lifecycle',
            'Lifetime spend' => 'ยอดใช้จ่ายสะสม',
            'Load defaults' => 'โหลดค่าเริ่มต้น',
            'Local rows' => 'แถว local',
            'Missing Sets' => 'ชุดที่ขาด',
            'Ordered Date' => 'วันที่สั่งซื้อ',
            'Payload hash' => 'Hash ของ payload',
            'Rate BPS' => 'อัตรา BPS',
            'Realtime idle' => 'Realtime ไม่ได้ใช้งาน',
            'Recall all' => 'เรียกคืนทั้งหมด',
            'Release gate note' => 'บันทึก release gate',
            'Remove set' => 'ลบชุด',
            'Required Queues' => 'คิวที่จำเป็น',
            'Retry after seconds' => 'ลองใหม่หลังจากกี่วินาที',
            'Reviewed at' => 'เวลาตรวจสอบ',
            'Reviewed by' => 'ตรวจสอบโดย',
            'Right Sidebar' => 'Sidebar ขวา',
            'Robots default' => 'ค่า robots เริ่มต้น',
            'SEO keywords' => 'คีย์เวิร์ด SEO',
            'Secondary color' => 'สีรอง',
            'Send invitation' => 'ส่งคำเชิญ',
            'Snapshot fields' => 'ฟิลด์ snapshot',
            'Support phone' => 'เบอร์โทร Support',
            'Telegram chat' => 'Telegram chat',
            'Text color' => 'สีข้อความ',
            'Threshold seconds' => 'เกณฑ์วินาที',
            'Thumb WebP' => 'ไฟล์ WebP thumbnail',
            'Toggle sidebar' => 'เปิด/ปิด sidebar',
            'Virtual copy' => 'สำเนา virtual',
            'Virtual copy ownership' => 'เจ้าของสำเนา virtual',
            'Virtual only' => 'เฉพาะ virtual',
            'WebP Runtime' => 'WebP runtime',
            'Window seconds' => 'ช่วงวินาที',
        ];
    }

    /**
     * @return array<string, string>
     */
    private static function terms(): array
    {
        return [
            'API' => 'API',
            'ID' => 'ID',
            'JSON' => 'JSON',
            'URL' => 'URL',
            'WebP' => 'WebP',
            'QR' => 'QR',
            'SEO' => 'SEO',
            'SSL' => 'SSL',
            'TLS' => 'TLS',
            'CDN' => 'CDN',
            'BPS' => 'BPS',
            'THB' => 'บาท',
            'Active' => 'ใช้งานอยู่',
            'Inactive' => 'ไม่ใช้งาน',
            'Pending' => 'รอดำเนินการ',
            'Approved' => 'อนุมัติแล้ว',
            'Rejected' => 'ปฏิเสธแล้ว',
            'Cancelled' => 'ยกเลิกแล้ว',
            'Completed' => 'สำเร็จแล้ว',
            'Failed' => 'ล้มเหลว',
            'Queued' => 'รอคิว',
            'Sent' => 'ส่งแล้ว',
            'Retryable' => 'ลองใหม่ได้',
            'Retryable failed' => 'ล้มเหลวแต่ลองใหม่ได้',
            'Admin' => 'ผู้ดูแลระบบ',
            'Admin User' => 'ผู้ดูแลระบบ',
            'Admin Users' => 'ผู้ดูแลระบบ',
            'Admin user' => 'ผู้ดูแลระบบ',
            'Admin note' => 'บันทึกผู้ดูแล',
            'Activity' => 'กิจกรรม',
            'Activity Claims' => 'คำขอรับเงินกิจกรรม',
            'Affiliate' => 'Affiliate',
            'Affiliate Account' => 'บัญชี Affiliate',
            'Affiliate Accounts' => 'บัญชี Affiliate',
            'Affiliate Links' => 'ลิงก์ Affiliate',
            'Affiliate Programs' => 'โปรแกรม Affiliate',
            'Affiliate feature' => 'ฟีเจอร์ Affiliate',
            'Agent' => 'ตัวแทน',
            'Agent Quotas' => 'โควตาตัวแทน',
            'Alert Policies' => 'นโยบายแจ้งเตือน',
            'Alert event' => 'เหตุการณ์แจ้งเตือน',
            'Alert policy' => 'นโยบายแจ้งเตือน',
            'Amount' => 'จำนวนเงิน',
            'Announcement' => 'ประกาศ',
            'Allocation' => 'การจัดสรร',
            'Allocations' => 'การจัดสรร',
            'Animation' => 'แอนิเมชัน',
            'Asset' => 'Asset',
            'Audit Logs' => 'ประวัติตรวจสอบ',
            'Back Office' => 'Back Office',
            'Balance' => 'ยอดคงเหลือ',
            'Bank' => 'ธนาคาร',
            'Bank account' => 'บัญชีธนาคาร',
            'Bank account name' => 'ชื่อบัญชีธนาคาร',
            'Bank account number' => 'เลขบัญชีธนาคาร',
            'Bank name' => 'ชื่อธนาคาร',
            'Bank transfer' => 'โอนเข้าบัญชีธนาคาร',
            'Billing Plans' => 'แพ็กเกจเรียกเก็บเงิน',
            'Bot Connection' => 'การเชื่อมต่อ Bot',
            'Buyer' => 'ผู้ซื้อ',
            'Cancel reason' => 'เหตุผลที่ยกเลิก',
            'Canonical' => 'Canonical',
            'Central' => 'Central',
            'Central Maintenance' => 'ปิดปรับปรุงจาก Central',
            'Central Queue' => 'คิว Central',
            'Central Stock' => 'คลังสลากกลาง',
            'Channel' => 'ช่องทาง',
            'Change status' => 'เปลี่ยนสถานะ',
            'Chat Discovery' => 'ค้นหา Chat',
            'Claim reference' => 'เลขอ้างอิงคำขอ',
            'Claim status' => 'สถานะคำขอ',
            'Commission' => 'ค่าคอมมิชชัน',
            'Commission Rules' => 'กฎค่าคอมมิชชัน',
            'Commission Transactions' => 'รายการค่าคอมมิชชัน',
            'Confirm' => 'ยืนยัน',
            'Confirm menu save' => 'ยืนยันการบันทึกเมนู',
            'Confirm result' => 'ยืนยันผล',
            'Confirm save' => 'ยืนยันการบันทึก',
            'Coverage' => 'Coverage',
            'Currency' => 'สกุลเงิน',
            'Current draw' => 'งวดปัจจุบัน',
            'Customer' => 'ลูกค้า',
            'Customer ID' => 'ID ลูกค้า',
            'Customer No.' => 'เลขลูกค้า',
            'Customer detail' => 'รายละเอียดลูกค้า',
            'Customer name' => 'ชื่อลูกค้า',
            'Dashboard' => 'แดชบอร์ด',
            'Description' => 'คำอธิบาย',
            'Detail' => 'รายละเอียด',
            'Default currency' => 'สกุลเงินเริ่มต้น',
            'Default payout' => 'การจ่ายรางวัลเริ่มต้น',
            'Default set distribution' => 'การกระจายจำนวนชุดเริ่มต้น',
            'Delivery Logs' => 'ประวัติการส่ง',
            'Domain' => 'โดเมน',
            'Domain Type' => 'ประเภทโดเมน',
            'Draw' => 'งวด',
            'Email' => 'อีเมล',
            'Event' => 'เหตุการณ์',
            'Exchange Reward' => 'อนุมัติขึ้นเงินรางวัล',
            'Exchange Reward History' => 'ประวัติขึ้นเงินรางวัล',
            'Exchange request' => 'คำขอขึ้นเงิน',
            'Favicon' => 'Favicon',
            'File' => 'ไฟล์',
            'First prize' => 'รางวัลที่ 1',
            'Font family' => 'ฟอนต์',
            'Front 3' => 'เลขหน้า 3 ตัว',
            'Game' => 'เกม',
            'Game / Version' => 'เกม / เวอร์ชัน',
            'Game / draw' => 'เกม / งวด',
            'Game name' => 'ชื่อเกม',
            'Generate stock' => 'สร้างสต็อก',
            'Generated code' => 'รหัสที่สร้าง',
            'Generated supply' => 'จำนวนที่สร้าง',
            'Group by' => 'จัดกลุ่มตาม',
            'Host' => 'Host',
            'Image' => 'รูปภาพ',
            'Images' => 'รูปภาพ',
            'Initial status' => 'สถานะเริ่มต้น',
            'Jobs Can Run' => 'Job ที่รันได้',
            'LINE Notifications' => 'แจ้งเตือน LINE',
            'Last 2 digits' => 'เลขท้าย 2 ตัว',
            'Last 7 days' => '7 วันที่ผ่านมา',
            'Last action' => 'การดำเนินการล่าสุด',
            'Last login' => 'เข้าสู่ระบบล่าสุด',
            'Last online' => 'ออนไลน์ล่าสุด',
            'Last seen' => 'พบล่าสุด',
            'Limit' => 'ขีดจำกัด',
            'Limits' => 'ขีดจำกัด',
            'Link' => 'ลิงก์',
            'Live completion' => 'ความคืบหน้าแบบ realtime',
            'Logo' => 'โลโก้',
            'Lottery' => 'สลาก',
            'Lottery Image Operations' => 'จัดการรูปสลาก',
            'Lottery Images' => 'รูปสลาก',
            'Lottery number' => 'เลขสลาก',
            'Maintenance' => 'ปิดปรับปรุง',
            'Maintenance active' => 'เปิดปิดปรับปรุง',
            'Maintenance message' => 'ข้อความปิดปรับปรุง',
            'Maintenance mode' => 'โหมดปิดปรับปรุง',
            'Matched prizes' => 'รางวัลที่ตรง',
            'Menu Tree' => 'โครงสร้างเมนู',
            'Menu items' => 'รายการเมนู',
            'Member' => 'สมาชิก',
            'Metadata' => 'Metadata',
            'Minimum' => 'ขั้นต่ำ',
            'Monthly fee' => 'ค่าบริการรายเดือน',
            'Name' => 'ชื่อ',
            'Net amount' => 'ยอดสุทธิ',
            'New request' => 'คำขอใหม่',
            'NewPaotang Back Office' => 'NewPaotang Back Office',
            'Notify customer' => 'แจ้งลูกค้า',
            'Notify member' => 'แจ้งสมาชิก',
            'Number search' => 'ค้นหาเลข',
            'Order' => 'คำสั่งซื้อ',
            'Order Histories' => 'ประวัติคำสั่งซื้อ',
            'Order ID' => 'ID คำสั่งซื้อ',
            'Order detail' => 'รายละเอียดคำสั่งซื้อ',
            'Order status' => 'สถานะคำสั่งซื้อ',
            'Owner' => 'เจ้าของ',
            'Override' => 'Override',
            'Page' => 'หน้า',
            'Password' => 'รหัสผ่าน',
            'Paid at' => 'เวลาชำระเงิน',
            'Partner' => 'พาร์ทเนอร์',
            'Partner Lottery Branding' => 'แบรนด์สลากพาร์ทเนอร์',
            'Partner Queue' => 'คิวพาร์ทเนอร์',
            'Partner/Tenant' => 'พาร์ทเนอร์/ร้านค้า',
            'Partner/Tenant detail' => 'รายละเอียดพาร์ทเนอร์/ร้านค้า',
            'Payload' => 'Payload',
            'Pattern search' => 'ค้นหา pattern',
            'Percent' => 'เปอร์เซ็นต์',
            'Payment' => 'การชำระเงิน',
            'Payment Channels' => 'ช่องทางชำระเงิน',
            'Payment Method' => 'วิธีชำระเงิน',
            'Payment Settings' => 'ตั้งค่าการชำระเงิน',
            'Payout' => 'การจ่ายเงิน',
            'Payouts' => 'การจ่ายเงิน',
            'Payout method' => 'วิธีรับเงิน',
            'Pending Assets' => 'Asset ที่รอดำเนินการ',
            'Pending Exchange Requests' => 'คำขอขึ้นเงินที่รอดำเนินการ',
            'Pending Topups' => 'รายการเติมเงินที่รอดำเนินการ',
            'Permission' => 'สิทธิ์',
            'Permissions' => 'สิทธิ์',
            'Plan' => 'แพ็กเกจ',
            'Plan Code' => 'รหัสแพ็กเกจ',
            'Plan Name' => 'ชื่อแพ็กเกจ',
            'Platform' => 'แพลตฟอร์ม',
            'Policy' => 'นโยบาย',
            'Posted at' => 'เวลาบันทึก',
            'Preview URL' => 'URL ดูตัวอย่าง',
            'Previous draw' => 'งวดก่อนหน้า',
            'Primary' => 'หลัก',
            'Prize' => 'รางวัล',
            'Prize amount' => 'เงินรางวัล',
            'Prize count' => 'จำนวนรางวัล',
            'Prize number' => 'เลขรางวัล',
            'Production Ready' => 'พร้อมใช้งานจริง',
            'Provider' => 'ผู้ให้บริการ',
            'Program' => 'โปรแกรม',
            'Programs' => 'โปรแกรม',
            'Public label' => 'ชื่อที่แสดงต่อสาธารณะ',
            'Public shop name' => 'ชื่อร้านที่แสดง',
            'Quota' => 'โควต้า',
            'Quotas' => 'โควต้า',
            'Realtime' => 'Realtime',
            'Receiver customer no' => 'เลขลูกค้าผู้รับ',
            'Redirect' => 'Redirect',
            'Redirects' => 'Redirect',
            'Referral URL' => 'URL แนะนำ',
            'Refund method' => 'วิธีคืนเงิน',
            'Registered customers' => 'ลูกค้าที่ลงทะเบียน',
            'Remaining stock' => 'สต็อกคงเหลือ',
            'Report' => 'รายงาน',
            'Report rows' => 'แถวรายงาน',
            'Report summary' => 'สรุปรายงาน',
            'Reward' => 'รางวัล',
            'Reward Payout Rules' => 'กฎการจ่ายรางวัล',
            'Reward claims' => 'คำขอขึ้นเงินรางวัล',
            'Reward exchange requests' => 'คำขอขึ้นเงินรางวัล',
            'Reward payout' => 'การจ่ายรางวัล',
            'Reward result' => 'ผลรางวัล',
            'Rule' => 'กฎ',
            'Rules' => 'กฎ',
            'Role' => 'บทบาท',
            'Role ID' => 'ID บทบาท',
            'Role IDs' => 'ID บทบาท',
            'Role code' => 'รหัสบทบาท',
            'Role name' => 'ชื่อบทบาท',
            'Roles And Permissions' => 'บทบาทและสิทธิ์',
            'SEO Pages' => 'หน้า SEO',
            'Sale' => 'การขาย',
            'Sale Price' => 'ราคาขาย',
            'Sale Price Rules' => 'กฎราคาขาย',
            'Sale close' => 'เวลาปิดขาย',
            'Sale price' => 'ราคาขาย',
            'Sale price rule' => 'กฎราคาขาย',
            'Sale start' => 'เวลาเปิดขาย',
            'Sale window' => 'ช่วงเวลาขาย',
            'Sales amount' => 'ยอดขาย',
            'Scope' => 'Scope',
            'Secret' => 'Secret',
            'Secrets' => 'Secret',
            'Search backend menu' => 'ค้นหาเมนูหลังบ้าน',
            'Search menu' => 'ค้นหาเมนู',
            'Secrets Redacted' => 'ปิดบังข้อมูลลับ',
            'Select all visible rows' => 'เลือกแถวที่เห็นทั้งหมด',
            'Settings' => 'ตั้งค่า',
            'Site and owner' => 'เว็บไซต์และเจ้าของ',
            'Site name' => 'ชื่อเว็บไซต์',
            'Sitemap enabled' => 'เปิดใช้ sitemap',
            'Sort order' => 'ลำดับการแสดงผล',
            'Source Image' => 'รูปต้นฉบับ',
            'Source' => 'แหล่งที่มา',
            'Starts at' => 'เวลาเริ่มต้น',
            'Status' => 'สถานะ',
            'Status code' => 'รหัสสถานะ',
            'Status totals' => 'ยอดรวมตามสถานะ',
            'Stock' => 'สต็อก',
            'Stock Manager' => 'จัดการคลังสลาก',
            'Stock Pattern Coverage' => 'Stock Pattern Coverage',
            'Stock Settings' => 'ตั้งค่าสต็อก',
            'Stock coverage' => 'Stock coverage',
            'Stock mode' => 'โหมดสต็อก',
            'Store' => 'ร้านค้า',
            'Store ID' => 'ID ร้านค้า',
            'Storefront host' => 'Host หน้าร้าน',
            'Submitted at' => 'เวลาส่งคำขอ',
            'Support Access' => 'สิทธิ์ Support Access',
            'Sync Logs' => 'ประวัติ Sync',
            'System role' => 'บทบาทระบบ',
            'Target' => 'เป้าหมาย',
            'Telegram Notifications' => 'แจ้งเตือน Telegram',
            'Telegram chat' => 'Telegram chat',
            'Temporary password' => 'รหัสผ่านชั่วคราว',
            'Tenant' => 'ร้านค้า',
            'Tenant Dashboard' => 'แดชบอร์ดร้านค้า',
            'Tenant Domains' => 'โดเมนร้านค้า',
            'Tenant Maintenance' => 'ปิดปรับปรุงร้านค้า',
            'Tenant Member' => 'สมาชิกร้านค้า',
            'Tenant Routes' => 'Route ร้านค้า',
            'Tenant Info' => 'ข้อมูลร้านค้า',
            'Tenant Stock' => 'คลังสลากร้านค้า',
            'Tenant Wallet' => 'กระเป๋าร้านค้า',
            'Terms and conditions' => 'ข้อตกลงและเงื่อนไข',
            'Terms of use' => 'ข้อตกลงการใช้งาน',
            'Theme And Branding' => 'ธีมและแบรนด์',
            'This draw' => 'งวดนี้',
            'This month' => 'เดือนนี้',
            'This year' => 'ปีนี้',
            'Ticket' => 'สลาก',
            'Ticket buyer' => 'ผู้ซื้อสลาก',
            'Ticket number' => 'เลขสลาก',
            'Ticket status' => 'สถานะสลาก',
            'Title' => 'ชื่อเรื่อง',
            'Topup' => 'เติมเงิน',
            'Topups' => 'รายการเติมเงิน',
            'Topup History' => 'ประวัติเติมเงิน',
            'Topup ID' => 'ID เติมเงิน',
            'Topup detail' => 'รายละเอียดเติมเงิน',
            'Total Amount' => 'ยอดรวม',
            'Total amount' => 'ยอดรวม',
            'Total prize' => 'เงินรางวัลรวม',
            'Total tickets' => 'จำนวนสลากรวม',
            'Transfer at' => 'เวลาโอน',
            'Translation Center' => 'ศูนย์แปลภาษา',
            'Usage meter' => 'ตัววัดการใช้งาน',
            'Wallet' => 'กระเป๋าเงิน',
            'Wallet Ledger' => 'บัญชีกระเป๋าเงิน',
            'Wallet balance' => 'ยอดกระเป๋าเงิน',
            'Wallet credited' => 'โอนเข้ากระเป๋าแล้ว',
            'Wallet detail' => 'รายละเอียดกระเป๋าเงิน',
            'Wallet name' => 'ชื่อกระเป๋าเงิน',
            'Wallet requests' => 'คำขอกระเป๋าเงิน',
            'Webhook log' => 'ประวัติ Webhook',
            'Winning numbers' => 'เลขรางวัล',
            'Winning rows' => 'แถวผู้ถูกรางวัล',
            'Winning status' => 'สถานะถูกรางวัล',
            'Winning tickets' => 'สลากถูกรางวัล',
            'YouTube live URL' => 'URL YouTube live',
            'YouTube live override URL' => 'URL override YouTube live',
        ];
    }

    /**
     * @return array<string, string>
     */
    private static function thaiToEnglish(): array
    {
        return [
            'ค้นหาเมนู' => 'Search menu',
            'ค้นหาเมนูหลังบ้าน' => 'Search back office menu',
            'ค้นหาได้เฉพาะเมนูที่ backend ส่งกลับมาเท่านั้น' => 'Only menu items returned by the backend are searchable.',
            'จัดการงานร้านค้าอย่างปลอดภัยสำหรับโดเมนพาร์ทเนอร์นี้' => 'Secure tenant operations for this partner domain.',
            'จัดการระบบส่วนกลางและร้านค้าโดยอิงสิทธิ์จาก backend RBAC และรูปแบบแดชบอร์ด Meno' => 'Central and tenant operations, rendered through backend RBAC menus and Meno dashboard patterns.',
            'ศูนย์แปลภาษา' => 'Translation Center',
            'ยอดขาย' => 'Sales',
            'สมาชิกใหม่' => 'New members',
            'หมายเลข' => 'Number',
            'สองตัว' => 'Two digits',
            'สามตัวหน้า' => 'Front three digits',
            'สามตัวหลัง' => 'Back three digits',
            'รางวัลที่ 1' => 'First prize',
            'รางวัลที่ 2' => 'Second prize',
            'รางวัลที่ 3' => 'Third prize',
            'รางวัลที่ 4' => 'Fourth prize',
            'รางวัลที่ 5' => 'Fifth prize',
            'รางวัลข้างเคียงรางวัลที่ 1' => 'Near first prize',
            'เลขท้าย 2 ตัว' => 'Last two digits',
            'เลขท้าย 3 ตัว' => 'Last three digits',
            'เลขหน้า 3 ตัว' => 'Front three digits',
            'เกิดข้อผิดพลาดในการ Verify ข้อมูล LINE กรุณาตรวจสอบข้อมูลแล้วกด Save ใหม่อีกครั้ง' => 'LINE verification failed. Check the information and save again.',
            'เกิดข้อผิดพลาดในการส่งข้อความทดสอบ LINE กรุณาตรวจสอบผู้รับและการเชื่อมต่อ LINE OA แล้วลองใหม่อีกครั้ง' => 'LINE test message failed. Check the recipient and LINE OA connection, then try again.',
            'เข้าสู่ระบบผู้ดูแล' => 'Admin sign in',
            'ใช้บัญชีผู้ดูแล Central หรือร้านค้าที่ได้รับอนุมัติ' => 'Use an approved central or tenant admin account.',
            'ใช้บัญชีผู้ดูแลร้านค้าที่ได้รับอนุมัติ' => 'Use an approved tenant admin account.',
            'ไม่พบเมนู' => 'No menu found',
        ];
    }
}
