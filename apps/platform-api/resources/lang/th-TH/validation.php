<?php

return [
    'required' => 'กรุณากรอก :attribute',
    'string' => ':attribute ต้องเป็นข้อความ',
    'integer' => ':attribute ต้องเป็นตัวเลขจำนวนเต็ม',
    'boolean' => ':attribute ต้องเป็นจริงหรือเท็จ',
    'email' => ':attribute ต้องเป็นอีเมลที่ถูกต้อง',
    'date' => ':attribute ต้องเป็นวันเวลาที่ถูกต้อง',
    'after' => ':attribute ต้องอยู่หลัง :date',
    'in' => ':attribute ต้องเป็นค่าใดค่าหนึ่งต่อไปนี้: :values',
    'attributes' => [
        'phone' => 'เบอร์โทรศัพท์',
        'password' => 'รหัสผ่าน',
        'password_confirmation' => 'ยืนยันรหัสผ่าน',
        'first_name' => 'ชื่อ',
        'last_name' => 'นามสกุล',
        'pin' => 'รหัส PIN',
        'preferred_locale' => 'ภาษา',
    ],
];
