// lib/screens/customer/moyasar_payment_screen.dart
//
// شاشة الدفع بالبطاقة عبر بوابة «ميسر» (Moyasar) — بوابة سعودية تدعم mada
// وVisa وMastercard وApple Pay.
//
// لماذا ودجت البوابة الجاهزة (CreditCard) لا حقول من تصميمنا؟ لأن بيانات
// البطاقة لا تمرّ حينها بشيفرتنا إطلاقاً، فيبقى التطبيق خارج نطاق التزامات
// PCI-DSS الثقيلة. أي شاشة نجمع فيها رقم البطاقة بأنفسنا تنقل إلينا مسؤولية
// أمنية وقانونية لا داعي لها.
//
// قاعدة أساسية: الطلب لا يُنشأ إلا بعد أن تؤكّد البوابة نجاح الشحن فعلياً،
// و[Order.isPaid] لا تصبح true إلا بوجود معرّف عملية حقيقي من البوابة.
import 'package:flutter/material.dart';
import 'package:moyasar/moyasar.dart';
import '../../utils/app_lang.dart';
import '../../utils/payment_config.dart';

/// نتيجة محاولة الدفع تُعاد إلى شاشة إتمام الطلب.
class MoyasarPaymentResult {
  final bool success;
  final String? paymentId;
  final String? errorMessage;

  const MoyasarPaymentResult({
    required this.success,
    this.paymentId,
    this.errorMessage,
  });
}

class MoyasarPaymentScreen extends StatelessWidget {
  final double amountSar;
  final String orderDescription;

  const MoyasarPaymentScreen({
    super.key,
    required this.amountSar,
    required this.orderDescription,
  });

  @override
  Widget build(BuildContext context) {
    // حماية من الإطلاق بمفتاح غير مضبوط: بدلاً من فشل غامض داخل البوابة،
    // تُعرض رسالة صريحة توضّح سبب التعطّل لمن يشغّل التطبيق.
    if (!PaymentConfig_.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('الدفع بالبطاقة', 'Pay by card'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              tr(
                  'الدفع بالبطاقة غير مفعّل بعد.\n'
                  'يلزم ضبط مفتاح بوابة الدفع في إعدادات التطبيق.',
                  'Card payments aren\'t enabled yet.\n'
                  'The payment gateway key needs to be set in the app settings.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final paymentConfig = PaymentConfig(
      publishableApiKey: PaymentConfig_.moyasarPublishableKey,
      // البوابة تتعامل بالهللات لا الريالات، لذا يُضرب المبلغ في 100 ويُقرَّب
      // لأقرب عدد صحيح تفادياً لكسور الفاصلة العائمة.
      amount: (amountSar * 100).round(),
      description: orderDescription,
      metadata: const {'source': 'zadgo_app'},
      // ليست const: مُنشئ CreditCardConfig في حزمة ميسر غير ثابت (حقوله
      // قابلة للتعديل)، فوضع const هنا خطأ ترجمة.
      creditCard: CreditCardConfig(saveCard: false, manual: false),
    );

    void onPaymentResult(dynamic result) {
      if (result is PaymentResponse) {
        switch (result.status) {
          case PaymentStatus.paid:
            Navigator.pop(
              context,
              MoyasarPaymentResult(success: true, paymentId: result.id),
            );
            break;
          case PaymentStatus.failed:
            Navigator.pop(
              context,
              MoyasarPaymentResult(
                success: false,
                errorMessage: tr(
                    'فشلت عملية الدفع، تأكّد من بيانات البطاقة أو الرصيد',
                    'Payment failed — check your card details or balance'),
              ),
            );
            break;
          default:
            Navigator.pop(
              context,
              MoyasarPaymentResult(
                success: false,
                errorMessage: tr('لم تكتمل عملية الدفع', 'Payment wasn\'t completed'),
              ),
            );
        }
      } else {
        // فشل على مستوى الشبكة أو البوابة، لا رفضٌ للبطاقة.
        Navigator.pop(
          context,
          MoyasarPaymentResult(
            success: false,
            errorMessage: tr('تعذّر الاتصال ببوابة الدفع، حاول مرة أخرى',
                'Couldn\'t reach the payment gateway, please try again'),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('الدفع بالبطاقة', 'Pay by card'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('المبلغ المطلوب', 'Amount due'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      tr('${amountSar.toStringAsFixed(2)} ر.س',
                          '${amountSar.toStringAsFixed(2)} SAR'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // نموذج البطاقة بلغة التطبيق الحالية — الحزمة توفّر العربية
            // والإنجليزية جاهزتين، فلا داعي لنموذج من تصميمنا يخرجنا من
            // نطاق PCI.
            CreditCard(
              config: paymentConfig,
              onPaymentResult: onPaymentResult,
              locale: AppLang.en
                  ? const Localization.en()
                  : const Localization.ar(),
            ),
          ],
        ),
      ),
    );
  }
}
