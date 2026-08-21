import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class OrderChatScreen extends StatefulWidget {
  final Order order;
  const OrderChatScreen({super.key, required this.order});

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  /// اسم الدور الظاهر أعلى كل رسالة — يميّز بوضوح حين يكتب "الإدارة" (المدير
  /// العام) حتى لا يظن العميل أو السائق أنه يتحدث مع الطرف الآخر للطلب.
  String _roleLabel(String senderRole) {
    if (senderRole == UserRole.admin.name) return 'الإدارة';
    for (final r in UserRole.values) {
      if (r.name == senderRole) return r.label;
    }
    return senderRole;
  }

  Color _roleColor(String senderRole) {
    if (senderRole == UserRole.admin.name) return Colors.deepPurple;
    if (senderRole == UserRole.driver.name) return AppColors.primary;
    return AppColors.secondary;
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    final msg = ChatMessage(
      id: const Uuid().v4(),
      orderId: widget.order.id,
      senderId: user.uid,
      senderName: user.name,
      senderRole: user.role.name,
      text: text,
      createdAt: DateTime.now(),
    );
    _msgCtrl.clear();
    await service.sendChatMessage(msg);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final auth = context.read<app_auth.AuthProvider>();
    final myUid = auth.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('محادثة الطلب #${widget.order.orderNumber}')),
      body: Column(children: [
        Expanded(
          child: AppStreamBuilder<List<ChatMessage>>(
            stream: () => service.streamChatMessages(widget.order.id),
            builder: (ctx, messages) {
              if (messages.isEmpty) {
                return const AppEmpty(emoji: '💬', title: 'ابدأ المحادثة');
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final isMe = m.senderId == myUid;
                  final isAdminMsg = m.senderRole == UserRole.admin.name;
                  final roleColor = _roleColor(m.senderRole);
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isAdminMsg
                            ? Colors.deepPurple.withOpacity(0.12)
                            : (isMe ? AppColors.primary : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: isAdminMsg ? Border.all(color: Colors.deepPurple, width: 1) : null,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // ✅ اسم المرسل ودوره دائماً ظاهران — لا يقتصر على
                        // رسائل الطرف الآخر — حتى يُدرك العميل والسائق بوضوح
                        // متى تكتب "الإدارة" بدل الطرف الآخر في الطلب.
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(m.senderName,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  // كحليّ على الفقاعة الذهبية الصادرة: الأبيض
                                  // عليها ~١٫٩:١ فتكاد الرسالة لا تُقرأ.
                                  color: isAdminMsg
                                      ? Colors.deepPurple
                                      : (isMe ? AppColors.dark.withOpacity(0.7) : AppColors.secondary))),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_roleLabel(m.senderRole),
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: roleColor)),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(m.text,
                            style: TextStyle(color: isAdminMsg ? AppColors.textDark : (isMe ? AppColors.dark : AppColors.textDark))),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(hintText: 'اكتب رسالتك...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(icon: const Icon(Icons.send, color: AppColors.dark, size: 18), onPressed: _send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
