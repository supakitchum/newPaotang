<?php

namespace App\Modules\Translations\Support;

class StaticTranslationCatalog
{
    /** @var array<int, string>|null */
    private static ?array $backOfficeSourcePhrases = null;

    /**
     * @return array<int, array{surface: string, category: string, key: string, default_text: string, description?: string}>
     */
    public static function entries(): array
    {
        return [
            ...self::backOfficeEntries(),
            ...self::customerEntries(),
            ...self::apiEntries(),
        ];
    }

    /**
     * @return array<int, array{surface: string, locale: string, key: string, value: string}>
     */
    public static function localizedValues(): array
    {
        return [
            ...self::localizedRows('back-office', self::backOfficeLocaleRoot()),
            ...self::localizedRows('customer', self::customerLocaleRoot()),
            ...self::apiLocalizedValues(),
        ];
    }

    /**
     * @return array<int, array{surface: string, locale: string, key: string, value: string}>
     */
    private static function apiLocalizedValues(): array
    {
        $values = [
            'th-TH' => [
                'api.errors.authentication_required' => 'เซสชันการใช้งานสิ้นสุดแล้ว กรุณาเข้าสู่ระบบอีกครั้ง',
                'api.errors.customer_account_not_found' => 'ไม่พบบัญชีที่ใช้เบอร์โทรศัพท์นี้ กรุณาตรวจสอบเบอร์หรือสมัครใช้งาน',
                'api.errors.invalid_login_credentials' => 'เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง กรุณาลองใหม่',
                'api.errors.customer_account_inactive' => 'บัญชีนี้ยังไม่พร้อมใช้งาน กรุณาติดต่อศูนย์ช่วยเหลือ',
                'api.errors.login_otp_challenge_invalid' => 'คำขอยืนยัน OTP หมดอายุ กรุณาขอรหัส OTP ใหม่',
                'api.errors.login_otp_phone_missing' => 'บัญชีนี้ยังไม่มีเบอร์โทรศัพท์สำหรับรับ OTP กรุณาเข้าสู่ระบบด้วยรหัสผ่าน',
                'api.errors.otp_invalid' => 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ กรุณาตรวจสอบแล้วลองใหม่',
                'api.errors.otp_attempts_exceeded' => 'กรอกรหัส OTP ไม่ถูกต้องหลายครั้ง กรุณาขอรหัสใหม่',
                'api.errors.otp_cooldown' => 'กรุณารอสักครู่ก่อนขอรหัส OTP ใหม่',
                'api.errors.otp_rate_limited' => 'ขอรหัส OTP บ่อยเกินไป กรุณาลองใหม่ภายหลัง',
                'api.errors.sms_otp_provider_not_configured' => 'ระบบ OTP ยังไม่พร้อมใช้งาน กรุณาเข้าสู่ระบบด้วยรหัสผ่าน',
                'api.errors.sms_send_failed' => 'ไม่สามารถส่งรหัส OTP ได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง',
                'api.errors.sms_verify_failed' => 'ไม่สามารถตรวจสอบรหัส OTP ได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง',
            ],
            'en-US' => [
                'api.errors.authentication_required' => 'Your session has ended. Please sign in again.',
                'api.errors.customer_account_not_found' => 'No account was found for this phone number. Check the number or create an account.',
                'api.errors.invalid_login_credentials' => 'The phone number or password is incorrect. Please try again.',
                'api.errors.customer_account_inactive' => 'This account is not available for sign-in. Please contact support.',
                'api.errors.login_otp_challenge_invalid' => 'The OTP request has expired. Please request a new code.',
                'api.errors.login_otp_phone_missing' => 'This account has no phone number for OTP. Please sign in with a password.',
                'api.errors.otp_invalid' => 'The OTP is incorrect or has expired. Please check it and try again.',
                'api.errors.otp_attempts_exceeded' => 'The OTP was entered incorrectly too many times. Please request a new code.',
                'api.errors.otp_cooldown' => 'Please wait a moment before requesting another OTP.',
                'api.errors.otp_rate_limited' => 'Too many OTP requests. Please try again later.',
                'api.errors.sms_otp_provider_not_configured' => 'OTP sign-in is not available. Please sign in with a password.',
                'api.errors.sms_send_failed' => 'The OTP could not be sent right now. Please try again.',
                'api.errors.sms_verify_failed' => 'The OTP could not be verified right now. Please try again.',
            ],
        ];

        $rows = [];
        foreach ($values as $locale => $messages) {
            foreach ($messages as $key => $value) {
                $rows[] = [
                    'surface' => 'api',
                    'locale' => $locale,
                    'key' => $key,
                    'value' => $value,
                ];
            }
        }

        return $rows;
    }

    /**
     * @return array<int, array{surface: string, category: string, key: string, default_text: string, description?: string}>
     */
    private static function backOfficeEntries(): array
    {
        return self::rows('back-office', [
            'common' => [
                'common.language' => 'Language',
                'common.thai' => 'ไทย',
                'common.english' => 'English',
                'common.search' => 'Search',
                'common.logout' => 'Logout',
                'common.scope' => 'Scope',
                'common.central' => 'Central',
                'common.tenant' => 'Tenant',
                'common.admin' => 'Admin',
                'common.save' => 'Save',
                'common.cancel' => 'Cancel',
                'common.edit' => 'Edit',
                'common.preview' => 'Preview',
                'common.approve' => 'Approve',
                'common.reject' => 'Reject',
                'common.submit' => 'Submit',
                'common.refresh' => 'Refresh',
                'common.loading' => 'Loading...',
                'common.action' => 'Action',
                'common.key' => 'Key',
                'common.allCategories' => 'All categories',
                'common.customer' => 'Customer',
                'common.backOffice' => 'Back Office',
                'common.api' => 'API',
                'common.usernameEmail' => 'Username / Email',
                'common.password' => 'Password',
                'common.signIn' => 'Sign in',
            ],
            'login' => [
                'login.heroTitle' => 'Siamblend Back Office',
                'login.heroSubtitle' => 'Central and tenant operations, rendered through backend RBAC menus and Meno dashboard patterns.',
                'login.partnerHeroSubtitle' => 'Secure tenant operations for this partner domain.',
                'login.title' => 'Admin sign in',
                'login.partnerTitleSuffix' => 'sign in',
                'login.subtitle' => 'Use an approved central or tenant admin account.',
                'login.partnerSubtitle' => 'Use an approved tenant admin account.',
                'login.tenantOnly' => 'Tenant admin access for',
                'login.brandingWarning' => 'Unable to load partner branding. You can still sign in.',
                'login.sourceOfTruth' => 'Backend authorization remains the source of truth after login.',
                'login.partnerRequiresTenant' => 'This partner Back Office requires a tenant admin account for this domain.',
                'login.sessionExpired' => 'Session expired. Please sign in again.',
            ],
            'menus' => [
                'menus.sidebar.adminMenu' => 'Admin Menu',
                'menus.sidebar.centralMenu' => 'Central Menu',
                'menus.sidebar.tenantMenu' => 'Tenant Menu',
                'menus.sidebar.loading' => 'Loading menu...',
                'menus.categories.dashboard' => 'Dashboard',
                'menus.categories.lotteryOperations' => 'Lottery Operations',
                'menus.categories.partnerOperations' => 'Partner Operations',
                'menus.categories.financeAndReports' => 'Finance And Reports',
                'menus.categories.administration' => 'Administration',
                'menus.categories.storeOperations' => 'Store Operations',
                'menus.categories.growth' => 'Growth',
                'menus.categories.operationsControl' => 'Operations Control',
                'menus.items.central.dashboard' => 'Dashboard',
                'menus.items.central.dashboard_sales' => 'Sales',
                'menus.items.central.dashboard_partner' => 'Partner',
                'menus.items.central.dashboard_wallet' => 'Wallet',
                'menus.items.central.dashboard_payout' => 'Payout',
                'menus.items.central.dashboard_monitor' => 'Monitor',
                'menus.items.central.games' => 'Games',
                'menus.items.central.rewards' => 'Rewards',
                'menus.items.central.winners' => 'Winners',
                'menus.items.central.sale_price_rules' => 'Sale Price Rules',
                'menus.items.central.reward_payout_rules' => 'Reward Payout Rules',
                'menus.items.central.stock_generation' => 'Stock Manager',
                'menus.items.central.partners' => 'Partner/Tenant',
                'menus.items.central.maintenance' => 'Central Maintenance',
                'menus.items.central.reports' => 'Reports',
                'menus.items.central.settlement' => 'Settlement',
                'menus.items.central.admin_users' => 'Admin Users',
                'menus.items.central.roles_permissions' => 'Roles And Permissions',
                'menus.items.central.menu_management' => 'Menu Management',
                'menus.items.central.telegram_notifications' => 'Telegram Notifications',
                'menus.items.central.storage_connections' => 'Storage Connections',
                'menus.items.central.translations' => 'Translation Center',
                'menus.items.central.system_settings' => 'System Settings',
                'menus.items.tenant.dashboard' => 'Dashboard',
                'menus.items.tenant.local_stock' => 'Tenant Stock',
                'menus.items.tenant.orders' => 'Orders',
                'menus.items.tenant.customers' => 'Customers',
                'menus.items.tenant.wallets' => 'Wallets',
                'menus.items.tenant.topups' => 'Topups',
                'menus.items.tenant.tickets' => 'Tickets',
                'menus.items.tenant.exchange_reward' => 'Exchange Reward',
                'menus.items.tenant.announcements' => 'Announcements',
                'menus.items.tenant.customer_notifications' => 'Public Relations',
                'menus.items.tenant.line_notifications' => 'LINE Notifications',
                'menus.items.tenant.activities' => 'Activities',
                'menus.items.tenant.activity_claims' => 'Activity Claims',
                'menus.items.tenant.reports' => 'Reports',
                'menus.items.tenant.admin_users' => 'Admin Users',
                'menus.items.tenant.roles_permissions' => 'Roles And Permissions',
                'menus.items.tenant.menu_management' => 'Menu Management',
                'menus.items.tenant.settings' => 'Settings',
            ],
            'translations' => [
                'translations.title' => 'Translation Center',
                'translations.subtitle' => 'Edit system translations and submit deploy requests for Platform Owner approval.',
                'translations.language' => 'Language',
                'translations.surface' => 'Surface',
                'translations.category' => 'Category',
                'translations.search' => 'Search translation keys',
                'translations.defaultText' => 'Default text',
                'translations.publishedValue' => 'Published value',
                'translations.draftValue' => 'Draft value',
                'translations.variables' => 'Variables',
                'translations.saveDraft' => 'Save draft',
                'translations.createRequest' => 'Create Deploy Request',
                'translations.deployRequests' => 'Deploy Requests',
                'translations.ownerQueue' => 'Platform Owner Queue',
                'translations.translationGrid' => 'Translation grid',
                'translations.loadingTranslations' => 'Loading translations...',
                'translations.searchKeys' => 'Search',
                'translations.allCategories' => 'All categories',
                'translations.submittedOnly' => 'Submitted requests only. Platform Owner can preview and publish.',
                'translations.noSubmittedRequests' => 'No submitted requests.',
                'translations.moreKeys' => 'more keys',
                'translations.submitRequest' => 'Submit',
                'translations.cancelRequest' => 'Cancel',
                'translations.chooseCategory' => 'Choose one category before creating a deploy request.',
                'translations.loadFailed' => 'Unable to load translations.',
                'translations.loadKeysFailed' => 'Unable to load translation keys.',
                'translations.saveDraftFailed' => 'Unable to save draft.',
                'translations.draftSaved' => 'Draft saved.',
                'translations.createRequestFailed' => 'Unable to create deploy request.',
                'translations.requestCreated' => 'Deploy request created.',
                'translations.requestSubmitted' => 'Deploy request submitted.',
                'translations.requestCancelled' => 'Deploy request cancelled.',
                'translations.requestDeployed' => 'Translations deployed.',
                'translations.requestRejected' => 'Deploy request rejected.',
                'translations.requestUpdateFailed' => 'Request update failed.',
                'translations.previewTokenMissing' => 'Preview token was not returned.',
                'translations.previewCreateFailed' => 'Unable to create preview session.',
                'translations.rejectFailed' => 'Unable to reject deploy request.',
                'translations.rejectPlaceholder' => 'Explain what the translator should revise.',
                'translations.missingPlaceholder' => 'Missing placeholder',
                'translations.previewRequest' => 'Preview request',
                'translations.approveRequest' => 'Approve request',
                'translations.rejectRequest' => 'Reject request',
                'translations.rejectReason' => 'Reject reason',
                'translations.noKeys' => 'No translation keys found.',
                'translations.noRequests' => 'No deploy requests yet.',
                'translations.rowsPerPage' => 'Rows per page',
                'translations.ofRows' => 'of',
                'translations.page' => 'Page',
                'translations.previousPage' => 'Previous',
                'translations.nextPage' => 'Next',
            ],
            'storageConnections' => [
                'storageConnections.title' => 'Storage Connections',
                'storageConnections.eyebrow' => 'Platform Object Storage',
                'storageConnections.heroTitle' => 'AWS S3 Connection',
                'storageConnections.heroDescription' => 'Manage the central storage connection used for platform assets and lottery image storage.',
                'storageConnections.testStatusPrefix' => 'Test',
                'storageConnections.connectionSettings' => 'Connection settings',
                'storageConnections.secretsHelp' => 'Secrets are encrypted and never returned after save.',
                'storageConnections.testConnection' => 'Test connection',
                'storageConnections.disconnect' => 'Disconnect',
                'storageConnections.status' => 'Status',
                'storageConnections.active' => 'Active',
                'storageConnections.inactive' => 'Inactive',
                'storageConnections.passed' => 'Passed',
                'storageConnections.failed' => 'Failed',
                'storageConnections.bucket' => 'Bucket',
                'storageConnections.region' => 'Region',
                'storageConnections.accessKeyId' => 'Access key ID',
                'storageConnections.current' => 'Current',
                'storageConnections.secretAccessKey' => 'Secret access key',
                'storageConnections.keepCurrentPlaceholder' => 'Configured - leave blank to keep current',
                'storageConnections.required' => 'Required',
                'storageConnections.optional' => 'Optional',
                'storageConnections.endpoint' => 'Endpoint',
                'storageConnections.publicUrl' => 'Public URL / CDN URL',
                'storageConnections.rootPrefix' => 'Root prefix',
                'storageConnections.visibility' => 'Visibility',
                'storageConnections.private' => 'Private',
                'storageConnections.public' => 'Public',
                'storageConnections.sessionToken' => 'Session token',
                'storageConnections.usePathStyleEndpoint' => 'Use path-style endpoint',
                'storageConnections.saveConnection' => 'Save connection',
                'storageConnections.runtimeReadiness' => 'Runtime readiness',
                'storageConnections.s3Adapter' => 'S3 adapter',
                'storageConnections.installed' => 'Installed',
                'storageConnections.missing' => 'Missing',
                'storageConnections.runtimeDisk' => 'Runtime disk',
                'storageConnections.assetDiskHint' => 'Asset disk hint',
                'storageConnections.lastTested' => 'Last tested',
                'storageConnections.installPackageBeforeProbe' => 'Install before running a real S3 probe:',
                'storageConnections.lastTestMessage' => 'Last test message',
                'storageConnections.noteEncrypted' => 'Credentials are encrypted and never returned by API.',
                'storageConnections.noteProbe' => 'Test connection writes, reads, and deletes one probe object.',
                'storageConnections.noteRuntimeDisk' => 'Choose AWS S3 per upload category when runtime uploads should use this bucket.',
                'storageConnections.probePassedMessage' => 'AWS S3 write/read/delete probe passed.',
                'storageConnections.uploadRouting' => 'Upload routing',
                'storageConnections.uploadRoutingHelp' => 'Choose local disk or AWS S3 per image category. Prefix is optional and is applied before the normal tenant/partner folder.',
                'storageConnections.categories' => 'categories',
                'storageConnections.driver' => 'Driver',
                'storageConnections.localStorage' => 'Local',
                'storageConnections.awsS3' => 'AWS S3',
                'storageConnections.categoryPrefix' => 'Category prefix',
                'storageConnections.partnerFolderNote' => 'Tenant and partner scoped uploads remain separated by tenant/partner folders, so each partner can be managed independently.',
                'storageConnections.saveUploadRouting' => 'Save upload routing',
                'storageConnections.routes.lottery_images.label' => 'Lottery images',
                'storageConnections.routes.lottery_images.description' => 'Generated lottery ticket images and stock preview assets.',
                'storageConnections.routes.payment_slips.label' => 'Payment slips',
                'storageConnections.routes.payment_slips.description' => 'Customer top-up slip full and thumbnail images.',
                'storageConnections.routes.announcement_images.label' => 'Announcement images',
                'storageConnections.routes.announcement_images.description' => 'Partner news and modal announcement images.',
                'storageConnections.routes.activity_images.label' => 'Activity images',
                'storageConnections.routes.activity_images.description' => 'Partner activity full and thumbnail images.',
                'storageConnections.routes.partner_assets.label' => 'Partner assets',
                'storageConnections.routes.partner_assets.description' => 'Tenant logos, branding assets, and partner-owned attachments.',
                'storageConnections.routes.central_assets.label' => 'Central assets',
                'storageConnections.routes.central_assets.description' => 'Platform owner uploads and central-only assets.',
                'storageConnections.saved' => 'AWS S3 connection saved.',
                'storageConnections.routesSaved' => 'Upload routing saved.',
                'storageConnections.testPassed' => 'AWS S3 connection test passed.',
                'storageConnections.disconnected' => 'AWS S3 connection disconnected.',
                'storageConnections.disconnectConfirm' => 'Disconnect AWS S3 storage connection? Saved credentials will be removed.',
            ],
            'errors' => [
                'errors.authenticationRequired' => 'Authentication is required.',
                'errors.permissionDenied' => 'You do not have permission to perform this action.',
                'errors.conflict' => 'The requested operation conflicts with current data.',
                'errors.validation' => 'The request payload is invalid.',
                'errors.failed' => 'The request failed.',
            ],
            'phrases' => self::backOfficePhraseRows(),
        ]);
    }

    /**
     * @return array<string, string>
     */
    private static function backOfficePhraseRows(): array
    {
        $rows = [];

        foreach (self::extractBackOfficeSourcePhrases() as $phrase) {
            $rows['phrases.'.substr(sha1($phrase), 0, 16)] = $phrase;
        }

        return $rows;
    }

    /**
     * @return array<int, string>
     */
    private static function extractBackOfficeSourcePhrases(): array
    {
        if (self::$backOfficeSourcePhrases !== null) {
            return self::$backOfficeSourcePhrases;
        }

        $root = self::backOfficeSourceRoot();
        if ($root === null) {
            self::$backOfficeSourcePhrases = [];

            return [];
        }

        $phrases = [];
        $directory = new \RecursiveDirectoryIterator($root, \FilesystemIterator::SKIP_DOTS);
        $filter = new \RecursiveCallbackFilterIterator($directory, function (\SplFileInfo $current): bool {
            if (! $current->isDir()) {
                return true;
            }

            return ! in_array($current->getFilename(), [
                '.git',
                '.nuxt',
                '.output',
                'dist',
                'node_modules',
                'public',
            ], true);
        });
        $iterator = new \RecursiveIteratorIterator($filter);

        foreach ($iterator as $file) {
            if (! $file instanceof \SplFileInfo || ! $file->isFile() || ! in_array($file->getExtension(), ['vue', 'ts'], true)) {
                continue;
            }

            $contents = (string) file_get_contents($file->getPathname());
            $template = self::templateBlock($contents);
            foreach ([
                ...self::extractTemplatePhrases($template),
                ...self::extractSourceLabelPhrases($contents),
            ] as $phrase) {
                $phrases[$phrase] = true;
            }
        }

        $result = array_keys($phrases);
        sort($result);
        self::$backOfficeSourcePhrases = $result;

        return $result;
    }

    private static function backOfficeSourceRoot(): ?string
    {
        $candidates = [
            env('BACK_OFFICE_SOURCE_PATH'),
            '/workspace/apps/back-office',
            dirname(base_path(), 2).'/back-office',
            dirname(base_path(), 3).'/apps/back-office',
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && $candidate !== '' && is_dir($candidate)) {
                return rtrim($candidate, '/');
            }
        }

        return null;
    }

    private static function backOfficeLocaleRoot(): ?string
    {
        return self::firstDirectory([
            env('BACK_OFFICE_LOCALE_PATH'),
            base_path('resources/translation-locales/back-office'),
            '/workspace/apps/back-office/locales',
            dirname(base_path(), 2).'/back-office/locales',
            dirname(base_path(), 3).'/apps/back-office/locales',
        ]);
    }

    private static function customerLocaleRoot(): ?string
    {
        return self::firstDirectory([
            env('CUSTOMER_LOCALE_PATH'),
            base_path('resources/translation-locales/customer'),
            '/workspace/apps/customer/locales',
            dirname(base_path(), 2).'/customer/locales',
            dirname(base_path(), 3).'/apps/customer/locales',
        ]);
    }

    /**
     * @param array<int, mixed> $candidates
     */
    private static function firstDirectory(array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (is_string($candidate) && $candidate !== '' && is_dir($candidate)) {
                return rtrim($candidate, '/');
            }
        }

        return null;
    }

    /**
     * @return array<int, array{surface: string, locale: string, key: string, value: string}>
     */
    private static function localizedRows(string $surface, ?string $root): array
    {
        if ($root === null) {
            return [];
        }

        $rows = [];
        foreach (glob($root.'/*.ts') ?: [] as $path) {
            $locale = basename($path, '.ts');
            $decoded = self::decodeLocaleFile((string) file_get_contents($path));
            foreach (self::flattenLocaleValues($decoded) as $key => $value) {
                $rows[] = [
                    'surface' => $surface,
                    'locale' => $locale,
                    'key' => $key,
                    'value' => $value,
                ];
            }
        }

        return $rows;
    }

    /**
     * @return array<string, mixed>
     */
    private static function decodeLocaleFile(string $contents): array
    {
        $source = trim((string) preg_replace('/^\s*export\s+default\s+/u', '', $contents));
        $source = preg_replace_callback('/\'((?:\\\\.|[^\'\\\\])*)\'/u', function (array $matches): string {
            return json_encode(stripcslashes($matches[1]), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }, $source) ?? $source;
        $source = preg_replace('/([,{]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:/u', '$1"$2":', $source) ?? $source;
        $source = preg_replace('/,\s*([}\]])/u', '$1', $source) ?? $source;

        $decoded = json_decode($source, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @param array<string, mixed> $source
     * @return array<string, string>
     */
    private static function flattenLocaleValues(array $source, string $prefix = ''): array
    {
        $rows = [];
        foreach ($source as $key => $value) {
            $path = $prefix === '' ? (string) $key : $prefix.'.'.$key;
            if (is_array($value)) {
                $rows = [...$rows, ...self::flattenLocaleValues($value, $path)];
                continue;
            }

            if (is_string($value) && trim($value) !== '') {
                $rows[$path] = $value;
            }
        }

        return $rows;
    }

    private static function templateBlock(string $contents): string
    {
        if (preg_match('/<template>([\s\S]*?)<\/template>/', $contents, $matches) !== 1) {
            return '';
        }

        return preg_replace('/<!--([\s\S]*?)-->/', ' ', (string) $matches[1]) ?? '';
    }

    /**
     * @return array<int, string>
     */
    private static function extractSourceLabelPhrases(string $contents): array
    {
        $phrases = [];
        $patterns = [
            '/(?:label|title|message|emptyTitle|emptyMessage|placeholder|description|name|header)\s*:\s*[\'"]([^\'"]+)[\'"]/u',
            '/\bitem\(\s*[\'"][^\'"]+[\'"]\s*,\s*[\'"]([^\'"]+)[\'"]/u',
            '/\b(?:column|field|action)\(\s*[\'"][^\'"]+[\'"]\s*,\s*[\'"]([^\'"]+)[\'"]/u',
        ];

        foreach ($patterns as $pattern) {
            if (preg_match_all($pattern, $contents, $matches) <= 0) {
                continue;
            }

            foreach ($matches[1] as $candidate) {
                $phrase = self::cleanPhrase((string) $candidate);
                if ($phrase !== null) {
                    $phrases[$phrase] = true;
                }
            }
        }

        return array_keys($phrases);
    }

    /**
     * @return array<int, string>
     */
    private static function extractTemplatePhrases(string $template): array
    {
        $phrases = [];

        if (preg_match_all('/>\s*([^<>{}\n][^<>{}]*)\s*</u', $template, $matches) > 0) {
            foreach ($matches[1] as $candidate) {
                $phrase = self::cleanPhrase((string) $candidate);
                if ($phrase !== null) {
                    $phrases[$phrase] = true;
                }
            }
        }

        if (preg_match_all('/(?:title|message|empty-title|empty-message|placeholder|aria-label|label|alt)="([^"]+)"/u', $template, $matches) > 0) {
            foreach ($matches[1] as $candidate) {
                $phrase = self::cleanPhrase((string) $candidate);
                if ($phrase !== null) {
                    $phrases[$phrase] = true;
                }
            }
        }

        return array_keys($phrases);
    }

    private static function cleanPhrase(string $candidate): ?string
    {
        $phrase = trim((string) preg_replace('/\s+/u', ' ', $candidate));

        if (
            $phrase === ''
            || mb_strlen($phrase) < 2
            || mb_strlen($phrase) > 160
            || preg_match('/^[-–—:;,.|\/()\[\]{}]+$/u', $phrase) === 1
            || preg_match('/^[\d\s:.,%+#-]+$/u', $phrase) === 1
            || preg_match('/[{}$<>`=]/u', $phrase) === 1
            || preg_match('/\\\\n|\\n/u', $phrase) === 1
            || preg_match('/\b(Nuxt|DevTools|Discord|GitHub|Twitter|documentation icon|examples icon|modules icon|spawn|spawnSync|ENOENT)\b/iu', $phrase) === 1
            || preg_match('/\b(error\.message|t\(|localhost|hello world|read more here)\b/iu', $phrase) === 1
            || preg_match('/^[^\s@]+@[^\s@]+\.[^\s@]+$/u', $phrase) === 1
            || preg_match('/\b(const|ref|computed|return|function|Array|Record|props|value|query|route|item|row|async|await|watch|import|export|define|type)\b/u', $phrase) === 1
            || preg_match('/^(ri-|bi-|btn|col-|row|card|http|https|\/|#|[a-z0-9_-]+\.(png|jpg|webp|svg)|[a-z0-9_.:-]+$)/iu', $phrase) === 1
            || preg_match('/[A-Za-zก-๙]/u', $phrase) !== 1
        ) {
            return null;
        }

        return $phrase;
    }

    /**
     * @return array<int, array{surface: string, category: string, key: string, default_text: string, description?: string}>
     */
    private static function customerEntries(): array
    {
        return self::rows('customer', [
            'common' => [
                'common.language' => 'ภาษา',
                'common.thai' => 'ไทย',
                'common.english' => 'English',
                'common.loading' => 'กำลังโหลด',
                'common.retry' => 'ลองใหม่',
                'common.close' => 'ปิด',
                'common.back' => 'กลับ',
                'common.search' => 'ค้นหา',
                'common.viewAll' => 'ดูทั้งหมด',
            ],
            'navigation' => [
                'nav.home' => 'หน้าหลัก',
                'nav.tickets' => 'สลากฯ ของฉัน',
                'nav.menu' => 'อื่นๆ',
            ],
            'profile' => [
                'profile.fallbackName' => 'ผู้ใช้งาน',
                'profile.memberCode' => 'รหัสสมาชิก : {code}',
                'profile.loadFailedTitle' => 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
                'profile.loadFailedMessage' => 'กรุณาลองใหม่อีกครั้ง',
                'profile.languageTitle' => 'ภาษาในการใช้งาน',
                'profile.languageSubtitle' => 'เลือกภาษาสำหรับหน้าเว็บและข้อความจากระบบ',
            ],
            'news' => [
                'news.title' => 'ข่าวสาร',
                'news.loading' => 'กำลังโหลดข่าวสาร',
                'news.emptyTitle' => 'ยังไม่มีข่าวสารในขณะนี้',
                'news.emptyDescription' => 'เมื่อมีประกาศใหม่จากร้านค้า คุณจะเห็นรายการได้ที่หน้านี้',
                'news.category' => 'ข่าวสาร',
                'news.fallbackTitle' => 'ข่าวประชาสัมพันธ์',
            ],
            'errors' => [
                'errors.generic' => 'กรุณาลองใหม่อีกครั้ง',
                'errors.maintenanceTitle' => 'ปิดปรับปรุงระบบ',
                'errors.maintenanceMessage' => 'ระบบอยู่ระหว่างปิดปรับปรุง กรุณากลับมาใหม่อีกครั้ง',
                'errors.sessionExpiredTitle' => 'เซสชันหมดอายุ',
                'errors.sessionExpiredMessage' => 'กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
            ],
        ]);
    }

    /**
     * @return array<int, array{surface: string, category: string, key: string, default_text: string, description?: string}>
     */
    private static function apiEntries(): array
    {
        return self::rows('api', [
            'errors' => [
                'api.errors.authentication_required' => 'Your session has ended. Please sign in again.',
                'api.errors.customer_account_not_found' => 'No account was found for this phone number. Check the number or create an account.',
                'api.errors.invalid_login_credentials' => 'The phone number or password is incorrect. Please try again.',
                'api.errors.customer_account_inactive' => 'This account is not available for sign-in. Please contact support.',
                'api.errors.login_otp_challenge_invalid' => 'The OTP request has expired. Please request a new code.',
                'api.errors.login_otp_phone_missing' => 'This account has no phone number for OTP. Please sign in with a password.',
                'api.errors.otp_invalid' => 'The OTP is incorrect or has expired. Please check it and try again.',
                'api.errors.otp_attempts_exceeded' => 'The OTP was entered incorrectly too many times. Please request a new code.',
                'api.errors.otp_cooldown' => 'Please wait a moment before requesting another OTP.',
                'api.errors.otp_rate_limited' => 'Too many OTP requests. Please try again later.',
                'api.errors.sms_otp_provider_not_configured' => 'OTP sign-in is not available. Please sign in with a password.',
                'api.errors.sms_send_failed' => 'The OTP could not be sent right now. Please try again.',
                'api.errors.sms_verify_failed' => 'The OTP could not be verified right now. Please try again.',
                'api.errors.customer_session_replaced' => 'This account signed in on a new device. The previous device was signed out.',
                'api.errors.permission_denied' => 'You do not have permission to perform this action.',
                'api.errors.resource_not_found' => 'The requested resource was not found.',
                'api.errors.resource_conflict' => 'The resource conflicts with existing state.',
                'api.errors.validation_failed' => 'The request payload is invalid.',
                'api.errors.reservation_unavailable' => 'The requested stock is no longer available.',
                'api.errors.reservation_expired' => 'The reservation has expired.',
                'api.errors.wallet_insufficient_balance' => 'The wallet balance is insufficient.',
                'api.errors.maintenance_active' => 'Tenant maintenance is active.',
                'api.errors.pin_required' => 'Customer PIN verification is required before continuing.',
                'api.errors.pin_setup_required' => 'A 6-digit customer PIN must be set before continuing.',
                'api.errors.pin_locked' => 'Customer PIN verification is temporarily locked. Please try again later.',
            ],
        ]);
    }

    /**
     * @param array<string, array<string, string>> $groups
     * @return array<int, array{surface: string, category: string, key: string, default_text: string}>
     */
    private static function rows(string $surface, array $groups): array
    {
        $rows = [];

        foreach ($groups as $category => $entries) {
            foreach ($entries as $key => $defaultText) {
                $rows[] = [
                    'surface' => $surface,
                    'category' => $category,
                    'key' => $key,
                    'default_text' => $defaultText,
                ];
            }
        }

        return $rows;
    }
}
