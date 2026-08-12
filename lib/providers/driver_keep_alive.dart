// lib/providers/driver_keep_alive.dart
//
// إبقاء تطبيق الكابتن حيّاً في الخلفية — دفعة و2، ٢٠٢٦-٠٨-١٢.
//
// بلاغ المالك المتكرّر: «التطبيق يختفي ثم يطلب تسجيل دخول». والسبب ليس
// في التطبيق: أندرويد يقتل أي عملية في الخلفية حين يحتاج ذاكرة، وأشدّه
// أجهزة شاومي وهواوي وأوبو التي تقتل بعد دقائق ولو كانت الذاكرة متاحة.
// وحين يُقتل تطبيق الكابتن وهو يقود:
//   • ينقطع بثّ موقعه، فتتجمّد خريطة العميل على آخر نقطة.
//   • لا يصله عرضٌ جديد، فيبقى الطلب بلا كابتن ونظنّ الإسناد معطوباً.
//   • ويعود لواجهة تسجيل الدخول أحياناً — وهو ما لاحظه المالك.
//
// الخدمة الأمامية هي **الوسيلة الوحيدة** التي يقرّها أندرويد لمنع ذلك:
// إشعارٌ ثابت يقول «زاد جو يعمل»، ومقابله عقدٌ من النظام بألّا يقتل
// العملية. ولا حيلة برمجية تُغني عنه — كل ما يُقال عن «خدمات خفية»
// إمّا لا يعمل منذ أندرويد ٨ أو يُرفض في المتجر.
//
// وما نشغّله خدمةٌ **بلا معالج مهام** (`callback` غير ممرَّر عمداً):
// المعالج يعمل في عزلة (isolate) مستقلة لا ترى Firestore ولا مزوّداتنا،
// فنسخُ منطق الموقع إليها ازدواجٌ يتعفّن. والمطلوب أبسط: أن تبقى
// العملية حيّة، فتستمر مؤقّتات التطبيق الأصلية تعمل كما هي.
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

class DriverKeepAlive {
  DriverKeepAlive._();

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zadgo_driver_online',
        channelName: 'حالة الاتصال',
        channelDescription: 'يظهر ما دمت متصلاً لاستقبال الطلبات',
        // أدنى أهمية بلا صوت ولا اهتزاز: هذا إشعار حالة لا تنبيه.
        // ورفعُه فوق ذلك يجعل الكابتن يُسكت قناة التطبيق كلها فيفقد
        // تنبيهات العروض الحقيقية معها.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // لا حدث دوري: لا معالج مهام أصلاً، والغرض إبقاء العملية حيّة.
        eventAction: ForegroundTaskEventAction.nothing(),
        // لا تشغيل تلقائي عند الإقلاع: كابتنٌ أطفأ هاتفه ليلاً يستيقظ
        // على تطبيق يظنّه متاحاً وهو نائم، فتذهب إليه عروضٌ تضيع.
        // الاتصال قرارٌ يتخذه بيده كل يوم.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// يبدأ الخدمة إن لم تكن تعمل. يُنادى عند اتصال الكابتن.
  ///
  /// الفشل لا يُرمى: كابتنٌ لا تعمل عنده الخدمة يبقى قادراً على العمل
  /// ما دام التطبيق مفتوحاً أمامه — والعطل هنا يخصم من الموثوقية لا
  /// يمنع التشغيل، فلا يجوز أن يُفشل تبديل الحالة نفسه.
  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      _ensureInitialized();

      // إذن الإشعارات شرطٌ لعرض إشعار الخدمة على أندرويد ١٣+.
      final permission = await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // نوع الخدمة يُختار وقت التشغيل لا في المانيفست وحده: أندرويد ١٤+
      // يرمي استثناءً **يُسقط التطبيق** إن بدأت خدمةَ نوعها `location`
      // بلا إذن موقع ممنوح. فمن رفض الإذن تعمل خدمته بنوع `dataSync` —
      // تبقيه حيّاً لاستقبال العروض، وإن كان بثّ موقعه معطّلاً أصلاً.
      final hasLocation = await _hasLocationPermission();

      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: 4201,
        serviceTypes: [
          hasLocation
              ? ForegroundServiceTypes.location
              : ForegroundServiceTypes.dataSync,
        ],
        notificationTitle: 'زاد جو — أنت متصل',
        notificationText: 'تصلك العروض ما دام هذا الإشعار ظاهراً',
      );
    } catch (e) {
      debugPrint('DriverKeepAlive.start: $e');
    }
  }

  /// يوقف الخدمة. يُنادى عند فصل الاتصال أو الخروج — وإلا بقي الإشعار
  /// ظاهراً لكابتنٍ أنهى دوامه، فيظنّه عاملاً ويشكو استنزاف البطارية.
  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('DriverKeepAlive.stop: $e');
    }
  }

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _hasLocationPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
