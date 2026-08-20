<?php
// server/api/notify.php
//
// نقطة إشعارات ZadGo — تقوم مقام Cloud Functions (المؤجَّلة لعدم توفر خطة
// Blaze) في إرسال إشعارات FCM الفورية. تُستضاف على استضافة الدومين وتُنادى
// من التطبيق بعد كل حدث طلب.
//
// العقد مع التطبيق (lib/providers/notify_relay.dart):
//   POST /notify.php
//   Authorization: Bearer <Firebase ID Token>
//   {"orderId": "...", "event": "created" | "assigned" | "status"}
//
// مبدأ الأمان الحاكم: العميل لا يُملي نصاً ولا مستلمين — يبلّغ بمعرّف طلب
// ونوع حدث فقط، والخادم يقرأ الطلب بنفسه من Firestore (بحساب الخدمة،
// متجاوزاً قواعد الأمان لأنه طرف موثوق) ويتحقق أن المُبلِّغ طرفٌ في الطلب،
// ثم يؤلّف الإشعار من بيانات Firestore لا من بيانات الطلب الوارد. أسوأ ما
// يستطيعه عميلٌ خبيث: إرسال إشعار مشروع عن طلب هو طرف فيه أصلاً.

declare(strict_types=1);
require __DIR__ . '/firebase_lib.php';

header('Content-Type: application/json; charset=utf-8');

function fail(int $code, string $msg): never {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail(405, 'POST فقط');

$config = require __DIR__ . '/config.php';
$projectId = $config['project_id'];
$cacheDir  = $config['cache_dir'];

// --- 1) التحقق من هوية المُبلِّغ --------------------------------------------
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (!preg_match('/^Bearer\s+(\S+)$/', $authHeader, $m)) fail(401, 'توكن مفقود');
$callerUid = verify_firebase_id_token($m[1], $projectId, $cacheDir);
if ($callerUid === null) fail(401, 'توكن غير صالح');

// --- 2) قراءة الطلب ---------------------------------------------------------
$input   = json_decode((string)file_get_contents('php://input'), true) ?: [];
$orderId = $input['orderId'] ?? '';
$event   = $input['event'] ?? '';
if (!is_string($orderId) || !preg_match('/^[A-Za-z0-9_-]{4,64}$/', $orderId)) {
    fail(400, 'orderId غير صالح');
}
if (!in_array($event, ['created', 'assigned', 'status'], true)) {
    fail(400, 'event غير معروف');
}

$sa = json_decode((string)file_get_contents($config['service_account_path']), true);
if (!is_array($sa)) fail(500, 'إعداد الخادم ناقص');
$saToken = service_account_token($sa, $cacheDir);
if ($saToken === null) fail(500, 'تعذّر توثيق حساب الخدمة');

$order = firestore_get($projectId, "orders/$orderId", $saToken);
if ($order === null) fail(404, 'الطلب غير موجود');

// --- 3) المُبلِّغ طرف في الطلب؟ ---------------------------------------------
$caller = firestore_get($projectId, "users/$callerUid", $saToken);
$callerRole = $caller['role'] ?? '';
// استثناء «تمرير العرض» (2026-08-20): جهاز الكابتن الرافض يمرّر العرض
// للتالي ثم يُبلغ — ولحظتها لم يعد driverId له فكان يُرفض 403 دائماً
// ولا يُشعَر البديل. حدث assigned يُقبل من أي حساب بدور كابتن: أثره
// الوحيد إشعار المُسنَد الحقيقي في المستند بنص يبنيه الخادم.
$isParty =
    ($order['customerId'] ?? '') === $callerUid ||
    ($order['driverId'] ?? '')   === $callerUid ||
    $callerRole === 'admin' ||
    ($event === 'assigned' && $callerRole === 'driver') ||
    ($callerRole === 'restaurantManager' &&
        ($caller['restaurantId'] ?? '') === ($order['restaurantId'] ?? ''));
if (!$isParty) fail(403, 'لست طرفاً في هذا الطلب');

// --- 4) تحديد المستلمين والنص حسب الحدث -------------------------------------
$orderNumber = (string)($order['orderNumber'] ?? '');
$tokens = [];   // fcmTokens المستلمين
$title = '';
$body = '';

switch ($event) {
    case 'created':
        // طلب جديد → مديرو المطعم المعني.
        $managers = firestore_query_eq($projectId, 'users', [
            'role'         => 'restaurantManager',
            'restaurantId' => (string)($order['restaurantId'] ?? ''),
        ], $saToken);
        foreach ($managers as $u) {
            if (!empty($u['fcmToken'])) $tokens[] = $u['fcmToken'];
        }
        $title = '🛎️ طلب جديد';
        $body  = "طلب #$orderNumber وصل الآن — افتح التطبيق لتأكيد الاستلام";
        break;

    case 'assigned':
        // إسناد → السائق.
        $driverId = (string)($order['driverId'] ?? '');
        if ($driverId !== '') {
            $driver = firestore_get($projectId, "users/$driverId", $saToken);
            if (!empty($driver['fcmToken'])) $tokens[] = $driver['fcmToken'];
        }
        $rest = (string)($order['restaurantName'] ?? '');
        $title = '🛵 طلب مُسند إليك';
        $body  = "طلب #$orderNumber — الاستلام من $rest";
        break;

    case 'status':
        // تغيّر الحالة → العميل، وفي حالات مختارة فقط حتى لا تتحول
        // الإشعارات إلى ضجيج يتجاهله.
        $labels = [
            'restaurantAccepted' => 'المطعم استلم طلبك وأكّده ✅',
            'preparing'          => 'مطعمك بدأ تحضير طلبك 👨‍🍳',
            'onTheWay'           => 'السائق في الطريق إليك 🛵',
            'delivered'          => 'تم توصيل طلبك، بالهناء والشفاء 🎉',
            'cancelled'          => 'أُلغي طلبك — راجع التطبيق للتفاصيل',
            'restaurantRejected' => 'اعتذر المطعم عن طلبك — راجع التطبيق',
            'refunded'           => 'تم استرداد مبلغ طلبك إلى محفظتك 💰',
        ];
        $status = (string)($order['status'] ?? '');
        if (!isset($labels[$status])) {
            echo json_encode(['ok' => true, 'sent' => 0, 'skipped' => 'حالة لا تُشعر'],
                JSON_UNESCAPED_UNICODE);
            exit;
        }
        $customerId = (string)($order['customerId'] ?? '');
        if ($customerId !== '') {
            $customer = firestore_get($projectId, "users/$customerId", $saToken);
            if (!empty($customer['fcmToken'])) $tokens[] = $customer['fcmToken'];
        }
        $title = "طلب #$orderNumber";
        $body  = $labels[$status];
        break;
}

// --- 5) الإرسال -------------------------------------------------------------
$sent = 0;
foreach (array_unique($tokens) as $t) {
    if (fcm_send($projectId, $saToken, $t, $title, $body,
        ['orderId' => $orderId, 'event' => $event])) {
        $sent++;
    }
}

echo json_encode(['ok' => true, 'sent' => $sent], JSON_UNESCAPED_UNICODE);
