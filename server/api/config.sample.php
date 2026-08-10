<?php
// server/api/config.sample.php
//
// انسخ هذا الملف باسم config.php وعدّل القيم. ملف config.php الحقيقي لا
// يُرفع للمستودع أبداً (مذكور في .gitignore) لأنه يشير إلى مفتاح حساب
// الخدمة.

return [
    // معرّف مشروع Firebase.
    'project_id' => 'restaurant-app-ed699',

    // المسار **المطلق** لملف مفتاح حساب الخدمة (JSON) على الاستضافة.
    // مهم جداً: ضع الملف خارج public_html حتى لا يكون قابلاً للتنزيل من
    // المتصفح. مثال على Bluehost:
    //   /home1/USERNAME/zadgo-secrets/service-account.json
    'service_account_path' => '/home/USERNAME/zadgo-secrets/service-account.json',

    // مجلد قابل للكتابة للتخزين المؤقت (شهادات جوجل + توكن الحساب).
    // sys_get_temp_dir() يكفي غالباً؛ أو ضع مجلداً خاصاً خارج public_html.
    'cache_dir' => sys_get_temp_dir(),

    // مفتاح ميسر السري (sk_...) — للتحقق الخادمي من الدفعات في verify.php.
    'moyasar_secret_key' => '',
];
