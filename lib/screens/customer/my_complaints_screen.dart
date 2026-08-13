// lib/screens/customer/my_complaints_screen.dart
//
// شاشة «شكاواي» — تعمل للأدوار الثلاثة (عميل/سائق/مدير مطعم) بنفس الكود،
// أسوةً بشاشة تقديم الشكوى المشتركة:
//   • العميل: قائمة واحدة بشكاواه المقدَّمة.
//   • السائق ومدير المطعم: تبويبان — «مقدَّمة مني» و«مقدَّمة عليّ» — لأن
//     كليهما طرف يُشتكى عليه أيضاً، ومن العدل أن يرى ما سُجّل ضده وحالته.
//
// كل شكوى تعرض: رقمها المختصر (يُملى هاتفياً بسهولة)، نوعها، حالتها بلون،
// رقم الطلب، ومهلة الرد الموعودة (نافذة 24 ساعة) — ثم شاشة تفاصيل فيها
// قرار الإدارة ودردشة مباشرة معها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'submit_ticket_screen.dart';

class MyComplaintsScreen extends StatelessWidget {
  final String uid;
  final UserRole role;

  /// معرّف مطعم المدير — لازم لتبويب «مقدَّمة عليّ» عنده، لأن الشكوى ضد
  /// المطعم تُسجَّل بمعرّف المطعم في againstUid لا بمعرّف مديره.
  final String? restaurantId;

  const MyComplaintsScreen({
    super.key,
    required this.uid,
    required this.role,
    this.restaurantId,
  });

  /// المطعم والسائق طرفان يُشتكى عليهما، فيحتاجان تبويب «مقدَّمة عليّ».
  bool get _showAgainstTab =>
      role == UserRole.driver ||
      (role == UserRole.restaurantManager &&
          (restaurantId ?? '').isNotEmpty);

  /// فتح تذكرة عامة (مالية/تحديث بيانات/استفسار) — بلا ارتباط بطلب.
  Widget _newTicketFab(BuildContext context) => FloatingActionButton.extended(
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('تذكرة جديدة'),
        onPressed: () {
          final auth = context.read<app_auth.AuthProvider>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubmitTicketScreen(
                submittedByUid: uid,
                submittedByName: auth.user?.name ?? '',
                submittedByRole: role,
                restaurantId: restaurantId,
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    if (!_showAgainstTab) {
      return Scaffold(
        appBar: AppBar(title: const Text('شكاواي')),
        floatingActionButton: _newTicketFab(context),
        body: _ComplaintsList(
          stream: () => service.streamComplaintsSubmittedBy(uid),
          emptyTitle: 'لا شكاوى مقدَّمة',
          emptySubtitle: 'تُقدَّم الشكوى من صفحة الطلب خلال 24 ساعة من انتهائه',
        ),
      );
    }

    // «مقدَّمة عليّ»: السائق يُشتكى عليه بمعرّفه هو، والمطعم بمعرّف المطعم —
    // استعلام المطعم يجلب كل شكاوى مطعمه ثم يُرشَّح محلياً لما هو ضده فعلاً.
    final Stream<List<Complaint>> Function() againstStream =
        role == UserRole.driver
            ? () => service.streamComplaintsAgainst(uid)
            : () => service
                .streamComplaintsForRestaurant(restaurantId!)
                .map((all) => all
                    .where((c) =>
                        c.againstRole == UserRole.restaurantManager &&
                        c.submittedByUid != uid)
                    .toList());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: _newTicketFab(context),
        appBar: AppBar(
          title: const Text('الشكاوى'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'مقدَّمة مني'),
              Tab(text: 'مقدَّمة عليّ'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _ComplaintsList(
            stream: () => service.streamComplaintsSubmittedBy(uid),
            emptyTitle: 'لا شكاوى مقدَّمة',
            emptySubtitle: 'تُقدَّم الشكوى من صفحة الطلب خلال 24 ساعة من انتهائه',
          ),
          _ComplaintsList(
            stream: againstStream,
            emptyTitle: 'لا شكاوى عليك',
            emptySubtitle: 'سجلّ نظيف — استمر 👏',
            readOnly: true,
          ),
        ]),
      ),
    );
  }
}

class _ComplaintsList extends StatelessWidget {
  final Stream<List<Complaint>> Function() stream;
  final String emptyTitle;
  final String? emptySubtitle;

  /// الشكاوى المقدَّمة عليّ تُعرض للاطلاع فقط: لا دردشة فيها، فالمحادثة حق
  /// مقدّم الشكوى مع الإدارة، والمشكوّ عليه يرى الحالة والنتيجة فقط.
  final bool readOnly;

  const _ComplaintsList({
    required this.stream,
    required this.emptyTitle,
    this.emptySubtitle,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => AppStreamBuilder<List<Complaint>>(
        stream: stream,
        builder: (context, complaints) {
          if (complaints.isEmpty) {
            return AppEmpty(emoji: '📮', title: emptyTitle, subtitle: emptySubtitle);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: complaints.length,
            itemBuilder: (_, i) => _ComplaintCard(
              complaint: complaints[i],
              readOnly: readOnly,
            ),
          );
        },
      );
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final bool readOnly;

  const _ComplaintCard({required this.complaint, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(
              complaintId: c.id,
              readOnly: readOnly,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  c.type.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
              StatusChip(label: c.status.label, color: c.status.color),
            ]),
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.tag_rounded,
              text: c.isGeneralTicket
                  ? 'تذكرة #${c.displayNumber}'
                  : 'شكوى #${c.displayNumber} — طلب #${c.orderNumber}',
            ),
            InfoRow(
              icon: Icons.schedule_rounded,
              text: _slaLine(c),
            ),
            if ((c.resolution ?? '').trim().isNotEmpty ||
                (c.adminNote ?? '').trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('صدر ردّ من الإدارة — افتح التفاصيل',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }

  /// سطر المهلة: وعدُ ردٍّ صريح ما دامت الشكوى بانتظار المعالجة، وتاريخ
  /// التقديم بعد انتهائها.
  String _slaLine(Complaint c) {
    if (!c.isAwaitingAction) return 'قُدّمت في ${_fmtDate(c.createdAt)}';
    final left = c.expectedResponseBy.difference(DateTime.now());
    if (left.isNegative) return 'تجاوزت مهلة الرد — نعتذر، تُعالج بأولوية';
    if (left.inHours >= 1) return 'الرد المتوقع خلال ${left.inHours} ساعة';
    return 'الرد المتوقع خلال دقائق';
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// شاشة تفاصيل الشكوى لمقدّمها — الحالة، القرار، والدردشة مع الإدارة.
// ---------------------------------------------------------------------------
class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;
  final bool readOnly;

  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
    this.readOnly = false,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _chatCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(Complaint c) async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = context.read<app_auth.AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await context.read<FirebaseService>().sendComplaintChatMessage(ChatMessage(
            id: const Uuid().v4(),
            orderId: c.id,
            senderId: user.uid,
            senderName: user.name,
            senderRole: user.role.name,
            text: text,
            createdAt: DateTime.now(),
          ));
      _chatCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الشكوى')),
      // متابعة حيّة لمستند الشكوى نفسه: تغيّر الحالة أو صدور القرار يظهر
      // لمقدّمها لحظياً وهو داخل الشاشة، بلا إغلاق وفتح.
      body: StreamBuilder<Complaint?>(
        stream: service.streamComplaint(widget.complaintId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null) {
            return const AppEmpty(emoji: '❓', title: 'الشكوى غير موجودة');
          }
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child:
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                              c.isGeneralTicket
                                  ? 'تذكرة #${c.displayNumber}'
                                  : 'شكوى #${c.displayNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                        ),
                        StatusChip(label: c.status.label, color: c.status.color),
                      ]),
                      const Divider(height: 20),
                      InfoRow(icon: Icons.category_outlined, text: c.type.label, bold: true),
                      if (!c.isGeneralTicket) ...[
                        InfoRow(icon: Icons.receipt_long_outlined, text: 'الطلب #${c.orderNumber}'),
                        InfoRow(
                            icon: Icons.storefront_outlined,
                            text: c.restaurantName.isEmpty ? '—' : c.restaurantName),
                      ],
                      InfoRow(
                          icon: Icons.access_time_rounded,
                          text: 'قُدّمت في ${_fmtDate(c.createdAt)}'),
                      if (c.isAwaitingAction)
                        InfoRow(
                            icon: Icons.hourglass_bottom_rounded,
                            text:
                                'نلتزم بالرد قبل ${_fmtDate(c.expectedResponseBy)}'),
                      const SizedBox(height: 8),
                      const Text('التفاصيل',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(c.description, style: const TextStyle(fontSize: 13.5)),
                    ]),
                  ),
                ),

                // قرار الإدارة — أهم ما ينتظره مقدّم الشكوى، فيُبرز في بطاقة
                // مستقلة بلون النجاح لا سطراً ضائعاً.
                if ((c.resolution ?? '').trim().isNotEmpty ||
                    (c.adminNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: AppColors.success.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.verified_outlined,
                                  size: 18, color: AppColors.success),
                              SizedBox(width: 8),
                              Text('ردّ الإدارة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success)),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if ((c.resolution ?? '').trim().isNotEmpty)
                                  c.resolution!.trim(),
                                if ((c.adminNote ?? '').trim().isNotEmpty)
                                  c.adminNote!.trim(),
                              ].join('\n'),
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ]),
                    ),
                  ),
                ],

                if (!widget.readOnly) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'محادثة مع الإدارة'),
                  StreamBuilder<List<ChatMessage>>(
                    stream: service.streamComplaintChat(c.id),
                    builder: (ctx, chatSnap) {
                      final messages = chatSnap.data ?? [];
                      if (messages.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                              'لا رسائل بعد — اكتب لنا أي توضيح إضافي هنا',
                              style: TextStyle(
                                  color: AppColors.textGray, fontSize: 12.5)),
                        );
                      }
                      final myUid =
                          context.read<app_auth.AuthProvider>().user?.uid;
                      return Column(
                        children: messages.map((m) {
                          final mine = m.senderId == myUid;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mine ? 'أنا' : m.senderName,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold)),
                                    Text(m.text,
                                        style: const TextStyle(fontSize: 13.5)),
                                  ]),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ]),
            ),

            // الإدخال يختفي بعد إغلاق الشكوى نهائياً — الملف أُقفل، والجديد
            // يُفتح بشكوى جديدة لا بذيلٍ على ملف مغلق.
            if (!widget.readOnly && c.status != ComplaintStatus.closed)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(c),
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة للإدارة...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: AppColors.primary),
                      onPressed: _sending ? null : () => _send(c),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
