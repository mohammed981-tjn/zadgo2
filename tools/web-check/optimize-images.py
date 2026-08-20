#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""يولّد نسخ WebP و AVIF من صور الموقع بالمقاسات المطلوبة فعلاً.

── لماذا؟ ──────────────────────────────────────────────────────────
صور الموقع 2.5 م.ب بصيغة JPEG، وأكثرها **أكبر مما يُعرض**: صورة الباب
360×360 تُعرض في 54 بكسل، وخلفية المطبخ 1920 عرضاً تُعرض في 459.
والقياس أثبت: WebP يوفّر 58٪ و AVIF يوفّر 65٪ — أي نحو 800 ك.ب عن كل
زائر، وهو أكبر مكسبٍ منفرد في سرعة الصفحة.

── ولماذا الصيغتان معاً؟ ────────────────────────────────────────────
AVIF أخفّ لكن سفاري لم يدعمه إلا 16.4، وفي السعودية آيفونات كثيرة أقدم.
فتُكتب الثلاث ويختار المتصفّح بـ<picture>: AVIF ثم WebP ثم JPEG الأصلي.
والأصل **يبقى في المستودع** ولا يُحذف — فمن لا يدعم شيئاً يجد صورةً.

── الاستعمال ───────────────────────────────────────────────────────
    python3 tools/web-check/optimize-images.py            # يكتب
    python3 tools/web-check/optimize-images.py --dry-run  # يقيس فقط

المقاسات مأخوذة من قياسٍ حقيقي بالمتصفّح (عرض العنصر × 2 لكثافة الشاشة)
لا من التخمين. إن غُيّر تصميمٌ فغُيّر معه المقاس هنا.
"""
import io
import os
import sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'images')
DRY = '--dry-run' in sys.argv

# أقصى عرضٍ تحتاجه الصورة فعلاً (مقيس بالمتصفّح ×2 للكثافة العالية)
WIDTHS = {
    'city-night.jpg': 1920,          # خلفية البطل العريضة
    'city-night-portrait.jpg': 900,  # خلفية البطل على الجوّال
    'bg-dining.jpg': 1920,
    'bg-table.jpg': 1600,
    'bg-table-portrait.jpg': 810,
    'bg-kitchen.jpg': 1000,
    'road-night.jpg': 1600,
    'p-customer.jpg': 160,           # صور الأبواب الدائرية — تُعرض في 54px
    'p-partner.jpg': 160,
    'p-captain.jpg': 160,
    'og-card.jpg': 1200,             # بطاقة المشاركة — مقاسها معياري
}
FOOD_WIDTH = 700                     # بطاقات الطعام في الشريط الأفقي

Q_WEBP = 82
Q_AVIF = 62


def targets():
    out = dict(WIDTHS)
    for f in sorted(os.listdir(ROOT)):
        if f.startswith('food-') and f.endswith('.jpg'):
            out[f] = FOOD_WIDTH
    return out


def main():
    if not os.path.isdir(ROOT):
        sys.exit('لم أجد مجلّد الصور: ' + ROOT)
    tot_src = tot_webp = tot_avif = 0
    made = 0
    print(f"{'الملف':<30}{'الأصل':>8}{'WebP':>8}{'AVIF':>8}   المقاس")
    for name, w in sorted(targets().items()):
        src = os.path.join(ROOT, name)
        if not os.path.exists(src):
            continue
        orig = os.path.getsize(src)
        im = Image.open(src).convert('RGB')
        if im.width > w:
            im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
        stem = os.path.splitext(name)[0]

        bw = io.BytesIO()
        im.save(bw, 'WEBP', quality=Q_WEBP, method=6)
        ba = io.BytesIO()
        try:
            im.save(ba, 'AVIF', quality=Q_AVIF)
            avif_ok = True
        except Exception:
            avif_ok = False

        if not DRY:
            open(os.path.join(ROOT, stem + '.webp'), 'wb').write(bw.getvalue())
            if avif_ok:
                open(os.path.join(ROOT, stem + '.avif'), 'wb').write(ba.getvalue())
            made += 1

        tot_src += orig
        tot_webp += bw.tell()
        tot_avif += ba.tell() if avif_ok else bw.tell()
        print(f"{name:<30}{orig//1024:>6}ك{bw.tell()//1024:>7}ك"
              f"{(ba.tell()//1024) if avif_ok else 0:>7}ك   {im.width}×{im.height}")

    print(f"\n{'المجموع':<30}{tot_src//1024:>6}ك{tot_webp//1024:>7}ك{tot_avif//1024:>7}ك")
    if tot_src:
        print(f"التوفير بـWebP: {(tot_src-tot_webp)//1024} ك.ب ({100-100*tot_webp//tot_src}٪)")
        print(f"التوفير بـAVIF: {(tot_src-tot_avif)//1024} ك.ب ({100-100*tot_avif//tot_src}٪)")
    print('\n(قياسٌ فقط — لم يُكتب شيء)' if DRY else f'\nكُتبت نسخ {made} صورة.')
    print('تذكير: استعمل <picture> بترتيب AVIF ← WebP ← الأصل، ولا تحذف الأصل.')


if __name__ == '__main__':
    main()
