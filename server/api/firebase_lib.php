<?php
// server/api/firebase_lib.php
//
// مكتبة مساعدة بلا أي اعتماديات خارجية (لا Composer) للعمل مع Firebase من
// استضافة PHP عادية (مثل استضافة الدومين):
//   • التحقق من توكن هوية Firebase (ID Token) القادم من التطبيق.
//   • الحصول على Access Token بحساب الخدمة (Service Account) عبر OAuth2.
//   • قراءة مستندات Firestore عبر REST.
//   • إرسال إشعارات FCM v1.
//
// لماذا هذا الملف أصلاً؟ Cloud Functions تتطلّب خطة Blaze غير المتاحة الآن،
// بينما إرسال FCM وقراءة Firestore بحساب خدمة مجانيان ولا يحتاجان إلا خادماً
// موثوقاً يحمل مفتاح الحساب — وهذه الاستضافة تقوم بذلك.

declare(strict_types=1);

// ---------------------------------------------------------------------------
// أدوات عامة
// ---------------------------------------------------------------------------

function b64url_decode(string $s): string|false {
    return base64_decode(strtr($s, '-_', '+/'));
}

function b64url_encode(string $s): string {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

function http_json(string $method, string $url, ?array $body, array $headers = []): array {
    $ch = curl_init($url);
    $hdrs = array_merge(['Content-Type: application/json'], $headers);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_HTTPHEADER     => $hdrs,
        CURLOPT_TIMEOUT        => 15,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $raw  = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($raw === false) return ['_status' => 0];
    $data = json_decode($raw, true);
    if (!is_array($data)) $data = ['_raw' => $raw];
    $data['_status'] = $code;
    return $data;
}

// ---------------------------------------------------------------------------
// التحقق من توكن هوية Firebase القادم من التطبيق
// ---------------------------------------------------------------------------

/// شهادات جوجل العامة للتحقق من توقيع التوكن — تُخزَّن مؤقتاً في ملف لأن
/// جلبها مع كل طلب بطيء بلا داعٍ (تتجدّد كل بضع ساعات فقط).
function google_id_certs(string $cacheDir): array {
    $cacheFile = rtrim($cacheDir, '/') . '/google_certs.json';
    if (is_file($cacheFile) && (time() - filemtime($cacheFile)) < 3600) {
        $cached = json_decode((string)file_get_contents($cacheFile), true);
        if (is_array($cached)) return $cached;
    }
    $certs = http_json('GET',
        'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
        null);
    unset($certs['_status']);
    if ($certs) @file_put_contents($cacheFile, json_encode($certs));
    return $certs;
}

/// يتحقق من توكن الهوية ويُرجع uid صاحبه، أو null إن كان مزوراً أو منتهياً.
/// الفحوص: التوقيع بشهادة جوجل المطابقة لـ kid، والجمهور (aud) = معرّف
/// المشروع، والمُصدر (iss)، وعدم انتهاء الصلاحية.
function verify_firebase_id_token(string $jwt, string $projectId, string $cacheDir): ?string {
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) return null;
    [$h64, $p64, $s64] = $parts;

    $header  = json_decode((string)b64url_decode($h64), true);
    $payload = json_decode((string)b64url_decode($p64), true);
    $sig     = b64url_decode($s64);
    if (!is_array($header) || !is_array($payload) || $sig === false) return null;
    if (($header['alg'] ?? '') !== 'RS256') return null;

    $kid = $header['kid'] ?? '';
    $certs = google_id_certs($cacheDir);
    $pem = $certs[$kid] ?? null;
    if ($pem === null) return null;

    $pubKey = openssl_pkey_get_public($pem);
    if ($pubKey === false) return null;
    $ok = openssl_verify("$h64.$p64", $sig, $pubKey, OPENSSL_ALGO_SHA256);
    if ($ok !== 1) return null;

    $now = time();
    if (($payload['aud'] ?? '') !== $projectId) return null;
    if (($payload['iss'] ?? '') !== "https://securetoken.google.com/$projectId") return null;
    if (($payload['exp'] ?? 0) < $now) return null;
    if (($payload['iat'] ?? PHP_INT_MAX) > $now + 300) return null;

    $uid = $payload['sub'] ?? '';
    return is_string($uid) && $uid !== '' ? $uid : null;
}

// ---------------------------------------------------------------------------
// Access Token بحساب الخدمة (للقراءة من Firestore والإرسال عبر FCM)
// ---------------------------------------------------------------------------

function service_account_token(array $sa, string $cacheDir): ?string {
    $cacheFile = rtrim($cacheDir, '/') . '/sa_token.json';
    if (is_file($cacheFile)) {
        $cached = json_decode((string)file_get_contents($cacheFile), true);
        if (is_array($cached) && ($cached['exp'] ?? 0) > time() + 60) {
            return $cached['token'];
        }
    }

    $now = time();
    $claims = [
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/datastore '
                 . 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => $sa['token_uri'],
        'iat'   => $now,
        'exp'   => $now + 3600,
    ];
    $h = b64url_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $c = b64url_encode(json_encode($claims));
    $signature = '';
    if (!openssl_sign("$h.$c", $signature, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
        return null;
    }
    $assertion = "$h.$c." . b64url_encode($signature);

    // token_uri يتوقّع form-encoded لا JSON — نداء مخصص:
    $ch = curl_init($sa['token_uri']);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $assertion,
        ]),
        CURLOPT_TIMEOUT        => 15,
    ]);
    $raw = curl_exec($ch);
    curl_close($ch);
    $data = json_decode((string)$raw, true);
    $token = $data['access_token'] ?? null;
    if (!is_string($token)) return null;

    @file_put_contents($cacheFile, json_encode([
        'token' => $token,
        'exp'   => $now + (int)($data['expires_in'] ?? 3600),
    ]));
    return $token;
}

// ---------------------------------------------------------------------------
// Firestore REST
// ---------------------------------------------------------------------------

/// يحوّل قيمة Firestore REST (typed value) إلى قيمة PHP عادية.
function fs_value(array $v): mixed {
    if (isset($v['stringValue']))  return $v['stringValue'];
    if (isset($v['integerValue'])) return (int)$v['integerValue'];
    if (isset($v['doubleValue']))  return (float)$v['doubleValue'];
    if (isset($v['booleanValue'])) return (bool)$v['booleanValue'];
    if (isset($v['nullValue']))    return null;
    if (isset($v['timestampValue'])) return $v['timestampValue'];
    if (isset($v['mapValue']))     return fs_fields($v['mapValue']['fields'] ?? []);
    if (isset($v['arrayValue'])) {
        return array_map('fs_value', $v['arrayValue']['values'] ?? []);
    }
    return null;
}

function fs_fields(array $fields): array {
    $out = [];
    foreach ($fields as $k => $v) $out[$k] = fs_value($v);
    return $out;
}

/// يقرأ مستنداً واحداً ويُرجع حقوله، أو null إن لم يوجد.
function firestore_get(string $projectId, string $path, string $token): ?array {
    $url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$path";
    $doc = http_json('GET', $url, null, ["Authorization: Bearer $token"]);
    if (($doc['_status'] ?? 0) !== 200 || !isset($doc['fields'])) return null;
    return fs_fields($doc['fields']);
}

/// استعلام مساواة بسيط على مجموعة، يُرجع مصفوفة حقول المستندات المطابقة.
function firestore_query_eq(string $projectId, string $collection, array $eqFilters, string $token): array {
    $filters = [];
    foreach ($eqFilters as $field => $value) {
        $typed = is_bool($value) ? ['booleanValue' => $value] : ['stringValue' => (string)$value];
        $filters[] = [
            'fieldFilter' => [
                'field' => ['fieldPath' => $field],
                'op'    => 'EQUAL',
                'value' => $typed,
            ],
        ];
    }
    $where = count($filters) === 1
        ? $filters[0]
        : ['compositeFilter' => ['op' => 'AND', 'filters' => $filters]];

    $body = [
        'structuredQuery' => [
            'from'  => [['collectionId' => $collection]],
            'where' => $where,
            'limit' => 20,
        ],
    ];
    $url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery";
    $rows = http_json('POST', $url, $body, ["Authorization: Bearer $token"]);
    unset($rows['_status']);

    $out = [];
    foreach ($rows as $row) {
        if (isset($row['document']['fields'])) {
            $out[] = fs_fields($row['document']['fields']);
        }
    }
    return $out;
}

// ---------------------------------------------------------------------------
// إرسال FCM v1
// ---------------------------------------------------------------------------

/// يرسل إشعاراً لتوكن جهاز واحد. يُرجع true عند القبول.
function fcm_send(string $projectId, string $token, string $deviceToken,
                  string $title, string $body, array $data = []): bool {
    $message = [
        'message' => [
            'token'        => $deviceToken,
            'notification' => ['title' => $title, 'body' => $body],
            'android'      => [
                'priority'     => 'HIGH',
                'notification' => ['sound' => 'default'],
            ],
            'apns'         => [
                'payload' => ['aps' => ['sound' => 'default']],
            ],
            // بيانات إضافية ليستخدمها التطبيق لاحقاً في التنقّل المباشر
            // لشاشة الطلب من الإشعار.
            'data'         => array_map('strval', $data),
        ],
    ];
    $resp = http_json('POST',
        "https://fcm.googleapis.com/v1/projects/$projectId/messages:send",
        $message, ["Authorization: Bearer $token"]);
    return ($resp['_status'] ?? 0) === 200;
}

// ترميز قيم PHP إلى صيغة Firestore REST — عكس fs_value.
function fs_encode(mixed $v): array {
    if (is_bool($v))   return ['booleanValue' => $v];
    if (is_int($v))    return ['integerValue' => (string)$v];
    if (is_float($v))  return ['doubleValue' => $v];
    return ['stringValue' => (string)$v];
}

// كتابة/دمج مستند عبر REST بحساب الخدمة — تتجاوز قواعد الأمان عمداً:
// الخادم طرف موثوق، والقواعد تمنع العملاء من الكتابة في هذه المجموعات.
function firestore_set(string $projectId, string $path, array $data, string $token): bool {
    $fields = [];
    $mask   = [];
    foreach ($data as $k => $v) { $fields[$k] = fs_encode($v); $mask[] = 'updateMask.fieldPaths=' . rawurlencode($k); }
    $url = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents/{$path}?" . implode('&', $mask);
    [$code, ] = http_json('PATCH', $url, ['fields' => $fields], ["Authorization: Bearer {$token}"]);
    return $code >= 200 && $code < 300;
}
