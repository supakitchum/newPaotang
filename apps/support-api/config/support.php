<?php

return [
    'jwt' => [
        'issuer' => env('SUPPORT_JWT_ISSUER', 'newpaotang-platform-api'),
        'audience' => env('SUPPORT_JWT_AUDIENCE', 'newpaotang-support'),
        'public_key_path' => env('SUPPORT_JWT_PUBLIC_KEY_PATH'),
        'public_key' => env('SUPPORT_JWT_PUBLIC_KEY'),
        'clock_skew_seconds' => (int) env('SUPPORT_JWT_CLOCK_SKEW_SECONDS', 30),
    ],
    'attachments' => [
        'disk' => env('SUPPORT_ATTACHMENT_DISK', env('FILESYSTEM_DISK', 'local')),
        'max_files' => (int) env('SUPPORT_ATTACHMENT_MAX_FILES', 4),
        'max_bytes' => (int) env('SUPPORT_ATTACHMENT_MAX_BYTES', 8 * 1024 * 1024),
        'allowed_mime_types' => ['image/jpeg', 'image/png', 'image/webp'],
        'signed_url_minutes' => (int) env('SUPPORT_ATTACHMENT_URL_MINUTES', 10),
    ],
    'assignment' => [
        'heartbeat_seconds' => (int) env('SUPPORT_AGENT_HEARTBEAT_SECONDS', 90),
        'default_capacity' => (int) env('SUPPORT_AGENT_DEFAULT_CAPACITY', 3),
    ],
    'message_defaults' => [
        'ticket_created' => [
            'th-TH' => 'ยินดีต้อนรับสู่ศูนย์ช่วยเหลือ เราได้รับเรื่องของคุณแล้ว ขณะนี้คุณอยู่ในคิวลำดับที่ {queue_position} คุณสามารถส่งรายละเอียดเพิ่มเติมระหว่างรอเจ้าหน้าที่ได้',
            'en-US' => 'Welcome to the Help Center. We have received your request. You are currently number {queue_position} in the queue, and you can send more details while waiting for an agent.',
        ],
    ],
    'platform_notifications' => [
        'url' => env('PLATFORM_NOTIFICATION_INGRESS_URL'),
        'secret' => env('PLATFORM_SUPPORT_INGRESS_SECRET'),
        'timeout_seconds' => (int) env('PLATFORM_NOTIFICATION_TIMEOUT_SECONDS', 3),
        'circuit_breaker_seconds' => (int) env('PLATFORM_NOTIFICATION_CIRCUIT_BREAKER_SECONDS', 60),
    ],
    'notification_defaults' => [
        'support.message.created' => [
            'title' => [
                'th-TH' => 'ข้อความใหม่จากศูนย์ช่วยเหลือ',
                'en-US' => 'New message from the Help Center',
            ],
            'body' => [
                'th-TH' => '{message}',
                'en-US' => '{message}',
            ],
        ],
        'support.ticket.assigned' => [
            'title' => [
                'th-TH' => 'มีเจ้าหน้าที่รับเรื่องแล้ว',
                'en-US' => 'An agent has accepted your ticket',
            ],
            'body' => [
                'th-TH' => 'เจ้าหน้าที่กำลังตรวจสอบรายการ {ticket_no}',
                'en-US' => 'An agent is reviewing ticket {ticket_no}.',
            ],
        ],
        'support.ticket.waiting_customer' => [
            'title' => [
                'th-TH' => 'ศูนย์ช่วยเหลือรอคำตอบจากคุณ',
                'en-US' => 'The Help Center is waiting for your reply',
            ],
            'body' => [
                'th-TH' => 'กรุณากลับไปที่รายการ {ticket_no}',
                'en-US' => 'Please return to ticket {ticket_no}.',
            ],
        ],
        'support.ticket.closed' => [
            'title' => [
                'th-TH' => 'รายการช่วยเหลือปิดแล้ว',
                'en-US' => 'Your support ticket is closed',
            ],
            'body' => [
                'th-TH' => 'กรุณาให้คะแนนการบริการสำหรับ {ticket_no}',
                'en-US' => 'Please rate the service for ticket {ticket_no}.',
            ],
        ],
    ],
];
