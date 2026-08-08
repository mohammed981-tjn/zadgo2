<?php
declare(strict_types=1);
require __DIR__ . '/../api/firebase_lib.php';

// ١) ترميز base64url ذهاباً وإياباً
assert(b64url_decode(b64url_encode('سلام ZadGo!')) === 'سلام ZadGo!');

// ٢) توقيع RS256 والتحقق منه بنفس أدوات openssl المستخدمة في المكتبة —
// نحاكي مسار verify_firebase_id_token بمفتاح وشهادة نولّدهما محلياً.
$key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
$csr = openssl_csr_new(['commonName' => 'test'], $key);
$cert = openssl_csr_sign($csr, null, $key, 1);
openssl_x509_export($cert, $pem);

$projectId = 'restaurant-app-ed699';
$now = time();
$header = ['alg' => 'RS256', 'typ' => 'JWT', 'kid' => 'testkid'];
$payload = [
  'aud' => $projectId,
  'iss' => "https://securetoken.google.com/$projectId",
  'exp' => $now + 3600, 'iat' => $now, 'sub' => 'uid_123',
];
$h = b64url_encode(json_encode($header));
$p = b64url_encode(json_encode($payload));
openssl_sign("$h.$p", $sig, $key, OPENSSL_ALGO_SHA256);
$jwt = "$h.$p." . b64url_encode($sig);

// نزرع الشهادة في ملف الكاش الذي تقرأه google_id_certs
$cacheDir = sys_get_temp_dir() . '/relaytest';
@mkdir($cacheDir);
file_put_contents("$cacheDir/google_certs.json", json_encode(['testkid' => $pem]));

$uid = verify_firebase_id_token($jwt, $projectId, $cacheDir);
assert($uid === 'uid_123');

// ٣) توكن منتهي الصلاحية يُرفض
$payload['exp'] = $now - 10;
$p2 = b64url_encode(json_encode($payload));
openssl_sign("$h.$p2", $sig2, $key, OPENSSL_ALGO_SHA256);
assert(verify_firebase_id_token("$h.$p2." . b64url_encode($sig2), $projectId, $cacheDir) === null);

// ٤) توقيع معبوث به يُرفض
assert(verify_firebase_id_token("$h.$p." . b64url_encode(strrev($sig)), $projectId, $cacheDir) === null);

// ٥) جمهور (aud) خاطئ يُرفض
assert(verify_firebase_id_token($jwt, 'other-project', $cacheDir) === null);

// ٦) تحويل قيم Firestore REST
$fields = ['name' => ['stringValue' => 'فطير'], 'price' => ['doubleValue' => 12.5],
           'n' => ['integerValue' => '3'], 'ok' => ['booleanValue' => true],
           'arr' => ['arrayValue' => ['values' => [['stringValue' => 'a']]]]];
$out = fs_fields($fields);
assert($out['name'] === 'فطير' && $out['price'] === 12.5 && $out['n'] === 3 && $out['ok'] === true && $out['arr'] === ['a']);

echo "ALL TESTS PASSED\n";
