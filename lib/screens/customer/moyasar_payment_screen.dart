// lib/screens/customer/moyasar_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:moyasar/moyasar.dart';

/// Result returned to [CheckoutScreen] after a real Moyasar card charge
/// attempt. The order must only be created when [success] is true.
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

/// TODO: replace with your real Moyasar publishable key (test key while in
/// sandbox). Never put the secret key here — only the publishable key is
/// safe to ship inside the app.
const String moyasarPublishableApiKey = 'pk_test_XXXXXXXXXXXXXXXXXXXXXXXX';

/// Real card-payment screen backed by Moyasar's hosted `CreditCard` widget.
///
/// Unlike [CreditCardInputScreen] (which only validates the card fields'
/// *format*), this screen performs an actual charge through Moyasar and only
/// returns success once the gateway confirms the payment.
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
    final paymentConfig = PaymentConfig(
      publishableApiKey: moyasarPublishableApiKey,
      // Moyasar expects the amount in halalas (smallest currency unit), not SAR.
      amount: (amountSar * 100).round(),
      description: orderDescription,
      metadata: const {'source': 'zadgo_app'},
      creditCard: const CreditCardConfig(saveCard: false, manual: false),
    );

    void onPaymentResult(result) {
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
              const MoyasarPaymentResult(
                success: false,
                errorMessage: 'فشلت عملية الدفع، تأكد من بيانات البطاقة أو الرصيد',
              ),
            );
            break;
          default:
            Navigator.pop(
              context,
              const MoyasarPaymentResult(
                success: false,
                errorMessage: 'لم تكتمل عملية الدفع',
              ),
            );
        }
      } else {
        // Gateway/network-level failure (not a declined charge).
        Navigator.pop(
          context,
          MoyasarPaymentResult(
            success: false,
            errorMessage: result?.toString() ?? 'حدث خطأ غير متوقع أثناء الدفع',
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الدفع بالبطاقة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CreditCard(
          config: paymentConfig,
          onPaymentResult: onPaymentResult,
        ),
      ),
    );
  }
}
