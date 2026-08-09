// lib/widgets/connectivity_banner.dart
//
// شريط «لا يوجد اتصال بالإنترنت» — يلتف حول التطبيق كله من builder في
// MaterialApp، فيظهر فوق أي شاشة فور انقطاع الشبكة ويختفي فور عودتها
// (نمط تويو/جاهز). بدونه كان الانقطاع يظهر أخطاءً تقنية أو شاشات فارغة
// بلا تفسير — ملاحظة وردت في تقرير مقارنة تويو.
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // فحص أولي ثم متابعة حيّة — الإصدار 6 يُرجع قائمة واجهات (WiFi وبيانات
    // معاً مثلاً)؛ «غير متصل» فقط حين لا واجهة إطلاقاً.
    Connectivity().checkConnectivity().then(_update);
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (offline != _offline && mounted) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // الشريط يدفع المحتوى للأسفل بدل أن يغطيه — لا يحجب زراً ولا حقلاً.
      if (_offline)
        Material(
          color: AppColors.error,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('لا يوجد اتصال بالإنترنت',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      Expanded(child: widget.child),
    ]);
  }
}
