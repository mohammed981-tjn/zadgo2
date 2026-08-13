// lib/screens/driver/scan_pickup_screen.dart
//
// مسح رمز الاستلام (دفعة و7): الكابتن يمسح QR المعروض على جهاز المطعم.
//
// نجاح المسح يثبت أن الجهازين تواجها في نفس المكان واللحظة — إثبات مادي
// يعلو على الزرّين المنفصلين. ثم يمرّ التأكيد بنفس تدفّق
// `DriverProofFlow.confirmPickup` (حارس النطاق، الصورة، مصارحة العُهدة)
// — المسح **اختصار طريق لا تجاوز حراسة**: كل ما كان شرطاً يبقى شرطاً.
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/models.dart';
import '../../utils/theme.dart';

class ScanPickupScreen extends StatefulWidget {
  final Order order;
  const ScanPickupScreen({super.key, required this.order});

  @override
  State<ScanPickupScreen> createState() => _ScanPickupScreenState();
}

class _ScanPickupScreenState extends State<ScanPickupScreen> {
  bool _handled = false;
  String? _mismatch;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final expected = 'zadgo:pickup:${widget.order.id}';
    if (raw == expected) {
      _handled = true;
      Navigator.pop(context, true);
      return;
    }
    // رمزٌ لطلبٍ آخر — يقع فعلاً حين تتجاور شاشتا طلبين على طاولة
    // المطعم. رسالة في الشاشة لا SnackBar: الكاميرا تعيد الالتقاط كل
    // لحظة وسيلٌ من الرسائل المنبثقة يحجب المعاينة نفسها.
    if (raw.startsWith('zadgo:pickup:')) {
      setState(() => _mismatch =
          'هذا رمز طلبٍ آخر — اطلب من المطعم رمز الطلب #${widget.order.orderNumber}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('مسح رمز الطلب #${widget.order.orderNumber}')),
        body: Stack(children: [
          MobileScanner(onDetect: _onDetect),
          // إطار تصويب بسيط — يوجّه الكاميرا دون حجب المعاينة.
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            bottom: 32, left: 24, right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _mismatch ??
                    'وجّه الكاميرا نحو الرمز على شاشة المطعم — يُلتقط تلقائياً',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _mismatch != null ? AppColors.warning : Colors.white,
                    fontSize: 13.5,
                    height: 1.6),
              ),
            ),
          ),
        ]),
      );
}
