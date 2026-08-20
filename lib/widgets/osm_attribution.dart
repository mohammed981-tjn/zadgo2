// lib/widgets/osm_attribution.dart
//
// إسناد OpenStreetMap — التزام قانوني لا زينة (غنائم جولة تاكسي طيبة
// 2026-08-20): بلاطاتنا من مخدّم تبرّعات OSM، ورخصة ODbL **تُلزم**
// بإسنادٍ ظاهر على كل خريطة تعرض بياناتها، وكنا نعرضها في أربعة مواضع
// بلا سطر إسناد واحد. ودجة واحدة تُلحق بكل خريطة كي لا يتكرر النص
// بصيغ متباينة ثم ينسى موضعٌ خامس قادم.
//
// userAgentPackageName مضبوط أصلاً في كل TileLayer (شرط سياسة
// الاستخدام الآخر). ويبقى الاستهلاك الثقيل من تطبيق موزَّع مقيَّداً في
// السياسة — مقبول لإطلاق حيٍّ واحد، ومسجَّل في الخطوات المعلّقة أن
// التوسع يستلزم مزوّد بلاطات تجارياً.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) => SimpleAttributionWidget(
        source: const Text('© مساهمو OpenStreetMap'),
        // الضغط يفتح صفحة حقوق OSM — الرابط جزء من الإسناد المتعارف.
        onTap: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
      );
}
