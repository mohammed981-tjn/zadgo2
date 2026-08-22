// lib/screens/admin/broadcast_tab.dart
//
// شاشة "البث الجماعي" — منفصلة تماماً عن دردشة الطلب الفردية بين العميل
// والسائق. تتيح للمدير العام إرسال رسالة واحدة لكل السائقين، أو رسالة أخرى
// منفصلة لكل العملاء.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class BroadcastTab extends StatefulWidget {
  const BroadcastTab({super.key});
  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          // ت١٦: كان التبويب المحدَّد ذهبياً على أبيض (١٫٧٢:١ — دون حدّ
          // القراءة) ولونُ نصّه غير لون مؤشّره، وذهبيُّ العميل يتسرّب
          // للوحة البنفسجية أصلاً. لون النكهة الداكن يقرأ ويطابق الهوية.
          child: TabBar(
            controller: _tabController,
            labelColor: context.flavorColors.primaryDark,
            indicatorColor: context.flavorColors.primary,
            tabs: [
              Tab(text: tr('رسالة لكل السائقين', 'Message all drivers')),
              Tab(text: tr('رسالة لكل العملاء', 'Message all customers')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _BroadcastPanel(audience: BroadcastAudience.drivers),
              _BroadcastPanel(audience: BroadcastAudience.customers),
            ],
          ),
        ),
      ],
    );
  }
}

class _BroadcastPanel extends StatefulWidget {
  final BroadcastAudience audience;
  const _BroadcastPanel({required this.audience});

  @override
  State<_BroadcastPanel> createState() => _BroadcastPanelState();
}

class _BroadcastPanelState extends State<_BroadcastPanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      showError(context, tr('يرجى إدخال العنوان ونص الرسالة',
          'Please enter a title and message body'));
      return;
    }
    setState(() => _sending = true);
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final msg = BroadcastMessage(
      id: const Uuid().v4(),
      audience: widget.audience,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      sentBy: auth.user?.name ?? auth.user?.uid ?? 'admin',
      createdAt: DateTime.now(),
    );
    await service.sendBroadcast(msg);
    _titleCtrl.clear();
    _bodyCtrl.clear();
    if (mounted) {
      setState(() => _sending = false);
      showSuccess(context, tr('تم إرسال البث بنجاح', 'Broadcast sent'));
    }
  }

  Future<void> _delete(BroadcastMessage m) async {
    final ok = await showConfirmDialog(context,
        title: tr('حذف الرسالة', 'Delete message'),
        content: tr('سيختفي هذا البثّ عن كل من وُجّه إليهم. متأكد؟',
            'This broadcast will disappear for everyone it was sent to. Are you sure?'),
        confirmLabel: tr('حذف', 'Delete'),
        confirmColor: AppColors.error);
    if (ok != true || !mounted) return;
    try {
      await context.read<FirebaseService>().deleteBroadcast(m);
      if (mounted) showSuccess(context, tr('حُذفت الرسالة', 'Message deleted'));
    } catch (_) {
      if (mounted) {
        showError(context, tr('تعذّر الحذف — حاول مجدداً',
            'Could not delete — try again'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final audienceLabel = widget.audience == BroadcastAudience.drivers
        ? tr('السائقين', 'drivers')
        : tr('العملاء', 'customers');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('إرسال رسالة جماعية لكل $audienceLabel',
                      'Send a broadcast to all $audienceLabel'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                    labelText: tr('عنوان الرسالة', 'Message title')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                decoration: InputDecoration(
                    labelText: tr('نص الرسالة', 'Message body')),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(_sending
                      ? tr('جارٍ الإرسال...', 'Sending...')
                      : tr('إرسال لكل $audienceLabel',
                          'Send to all $audienceLabel')),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AppStreamBuilder<List<BroadcastMessage>>(
            stream: () => service.streamBroadcasts(widget.audience),
            builder: (ctx, list) {
              if (list.isEmpty) {
                return AppEmpty(
                    emoji: '📢',
                    title: tr('لا يوجد رسائل بث سابقة', 'No past broadcasts'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(m.body),
                      // زرّ حذف لكل رسالة: البثّ بلا مدّة انتهاء، فيبقى على شاشات
                      // العملاء حتى تُزيله الإدارة. الأحدث هو ما يظهر للعميل،
                      // فحذفه يُزيل الشريط أو يُظهر ما قبله.
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${m.createdAt.day}/${m.createdAt.month} ${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          tooltip: tr('حذف', 'Delete'),
                          onPressed: () => _delete(m),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
