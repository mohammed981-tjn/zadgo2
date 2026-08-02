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
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            tabs: const [
              Tab(text: 'رسالة لكل السائقين'),
              Tab(text: 'رسالة لكل العملاء'),
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
      showError(context, 'يرجى إدخال العنوان ونص الرسالة');
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
      showSuccess(context, 'تم إرسال البث بنجاح');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final audienceLabel = widget.audience == BroadcastAudience.drivers ? 'السائقين' : 'العملاء';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إرسال رسالة جماعية لكل $audienceLabel',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان الرسالة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(labelText: 'نص الرسالة'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال لكل $audienceLabel'),
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
                return const AppEmpty(emoji: '📢', title: 'لا يوجد رسائل بث سابقة');
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
                      trailing: Text(
                        '${m.createdAt.day}/${m.createdAt.month} ${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
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
