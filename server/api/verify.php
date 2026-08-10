<?php
// server/api/verify.php — التحقق الخادمي من دفعات ميسر (البند د٣-أ).
//
// كان التطبيق يكتب isPaid بنفسه بعد نجاح شاشة الدفع — أي أن عميلاً معدَّل
// البرمجية «ينجح» بلا دفع. هذا الملف يغلق الباب بلا Blaze: التطبيق يرسل
// معرّف العملية، والخادم يسأل ميسر مباشرة بالمفتاح السري، وإن كانت
// مدفوعة فعلاً يختم verified_payments/{paymentId} بحساب الخدمة — وقواعد
// Firestore ترفض إنشاء أي طلب بمعرّف دفعة لا ختم له.
//
// العقد: POST /verify.php
//   Authorization: Bearer <Firebase ID Token>
//   {"payment_id": "..."}
// الردّ: {"ok":true,"amount_halalas":N} أو {"ok":false,"error":"..."}
declare(strict_types=1);
require __DIR__ . '/firebase_lib.php';
$config = require __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');

function fail(int $code, string $msg): never {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg]);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail(405, 'method');
$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (!str_starts_with($auth, 'Bearer ')) fail(401, 'no_token');
$uid = verify_firebase_id_token(substr($auth, 7), $config['project_id'], $config['cache_dir']);
if ($uid === null) fail(401, 'bad_token');

$body = json_decode(file_get_contents('php://input') ?: '', true);
$paymentId = trim((string)($body['payment_id'] ?? ''));
// معرّفات ميسر UUID — أي شكل آخر يُرفض قبل أن يبلغ البوابة.
if (!preg_match('/^[a-f0-9-]{20,60}$/i', $paymentId)) fail(400, 'bad_payment_id');

$secret = $config['moyasar_secret_key'] ?? '';
if ($secret === '') fail(503, 'moyasar_not_configured');

// السؤال من المصدر لا من العميل: GET بالمفتاح السري.
[$code, $p] = http_json('GET', "https://api.moyasar.com/v1/payments/{$paymentId}", null,
    ['Authorization: Basic ' . base64_encode($secret . ':')]);
if ($code !== 200 || !is_array($p)) fail(502, 'gateway_error');
if (($p['status'] ?? '') !== 'paid') fail(409, 'not_paid');
if (strtoupper((string)($p['currency'] ?? '')) !== 'SAR') fail(409, 'wrong_currency');

$token = service_account_token($config['service_account'], $config['cache_dir']);
if ($token === null) fail(500, 'sa_token');

// الختم باسم الدافع والمبلغ — القواعد تربط الطلب بهما لا بكلمة العميل.
$ok = firestore_set($config['project_id'], "verified_payments/{$paymentId}", [
    'uid'            => $uid,
    'amountHalalas'  => (int)($p['amount'] ?? 0),
    'source'         => 'moyasar',
    'verifiedAt'     => gmdate('c'),
], $token);
if (!$ok) fail(500, 'stamp_failed');

echo json_encode(['ok' => true, 'amount_halalas' => (int)($p['amount'] ?? 0)]);
