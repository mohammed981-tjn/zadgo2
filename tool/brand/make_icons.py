# tool/brand/make_icons.py
#
# مولّد أيقونات المشغّل — الحرف Z مرسوم بمضلّعات هندسية لا صورةً مقصوصة.
#
# لماذا سكربت في المستودع لا حزمة flutter_launcher_icons: حزمة جديدة تعني
# «دفعة حزم» معزولة بإصدار مثبَّت (بند أ٦)، والسكربت يعطينا ما لا تعطيه
# الحزمة: طبقة خلفية متدرّجة، وأطوال أثر حركة مختلفة بين النسخة الكاملة
# والطبقة الأمامية (منطقة أمان adaptive أضيق فتُقصَّر الخطوط بدل أن يصغر
# الحرف). يعمل يدوياً مرة عند كل تغيير هوية، والنواتج تُودَع في المستودع،
# فلا يمسّ CI ولا زمن البناء:
#
#     python3 tool/brand/make_icons.py
#
# لماذا نكهتا السائق والمطعم فقط: قرار المالك (٢٠٢٦-٠٨-١٠) — أيقونة
# العميل ثابتة (وجه العلامة الذي يعرفه الناس)، والإدارة داخلية لم يُطلب
# تغييرها. عند تعميم القرار تُضاف النكهة إلى FLAVORS أدناه فقط.
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))

# فرط عيّنات ثم تصغير Lanczos = حواف نظيفة بلا برنامج رسوميات.
SS = 8

WHITE = (255, 255, 255)

# الهوية اللونية لكل نكهة تُغيَّر أيقونتها — يجب أن تطابق FlavorPalette
# في lib/utils/theme.dart، فهي مصدر الحقيقة للألوان داخل التطبيق نفسه.
FLAVORS = {
    # أزرق الكابتن: أعمق من أزرق Material الافتراضي السابق (#1976D2)
    # ومشتقّ من كحلي العلامة فينتمي لعائلتها.
    'driver': {'primary': (18, 85, 158)},
    # قرميدي: فصلٌ حاسم عن ذهبي العميل — البرتقالي السابق (#E8590C) كان
    # يُقرأ شقيقاً للذهبي في شبكة المشغّل عند 48dp.
    'restaurant': {'primary': (201, 42, 42)},
}

# مقاسات legacy (أجهزة API 23–25، minSdk عندنا 23) ثم مقاسات طبقات
# adaptive (‏108dp لكل كثافة) — النظام يقصّ منها 72dp ويحرّك الباقي.
LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ADAPTIVE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324,
            'xxxhdpi': 432}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""


def lighten(c, k):
    return tuple(int(v + (255 - v) * k) for v in c)


def z_polys(cx, cy, w, h, trail_lens, tb=0.205, dw=0.70, shear=0.13):
    """مضلّعات الحرف وخطوط السرعة. [trail_lens] أطوال الخطوط الثلاثة
    نسبةً إلى عرض الحرف — تُقصَّر في طبقة adaptive لضيق منطقة الأمان."""
    x0, y0 = cx - w / 2, cy - h / 2

    def P(u, v):
        # الميل حول منتصف الارتفاع فيبقى الحرف متوازناً بصرياً.
        return (x0 + (u + shear * (0.5 - v)) * w, y0 + v * h)

    z = [P(0, 0), P(1, 0), P(1, tb), P(1 - dw, 1 - tb), P(1, 1 - tb),
         P(1, 1), P(0, 1), P(0, 1 - tb), P(dw, tb), P(0, tb)]
    out = [z]
    # سُمك الخط 0.062 لا أرقّ — دونه يختفي عند 48dp ويترك ضجيجاً رمادياً.
    t, g = 0.062, 0.055
    for i, ln in enumerate(trail_lens):
        v = tb + g + i * (t + g)
        out.append([P(1.07, v), P(1.07 + ln, v),
                    P(1.07 + ln, v + t), P(1.07, v + t)])
    for i, ln in enumerate(trail_lens):
        v = 1 - tb - g - t - i * (t + g)
        out.append([P(-0.07, v), P(-0.07 - ln, v),
                    P(-0.07 - ln, v + t), P(-0.07, v + t)])
    return out


def grad(size, top, bottom):
    """تدرّج قطري — اتجاه الضوء نفسه اتجاه ميل الحرف فيبدوان قطعة واحدة."""
    g = Image.new('RGB', (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = (x / size) * 0.45 + (y / size) * 0.55
            px[x, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t)
                             for i in range(3))
    return g


def draw_mark(canvas, mark_h_ratio, trail_lens, fg, shadow=True):
    """يرسم الحرف وأثره على [canvas] (RGBA) في مركزه."""
    S = canvas.size[0]
    h = S * mark_h_ratio
    w = h * 0.86
    polys = z_polys(S / 2, S / 2, w, h, trail_lens)
    if shadow:
        # ظلّ ناعم يفصل الحرف عن الخلفية — الفرق بين «ملصق» و«جسم».
        sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        for p in polys:
            sd.polygon([(x + S * 0.012, y + S * 0.018) for x, y in p],
                       fill=(0, 0, 0, 90))
        sh = sh.filter(ImageFilter.GaussianBlur(S * 0.016))
        canvas.alpha_composite(sh)
    d = ImageDraw.Draw(canvas)
    for p in polys:
        d.polygon(p, fill=fg)
    return canvas


def legacy_icon(size, primary):
    """أيقونة كاملة بزوايا مستديرة مخبوزة — لمشغّلات API 23–25 التي تعرض
    الملف كما هو بلا قناع."""
    S = size * SS
    base = grad(S, lighten(primary, 0.42), primary).convert('RGBA')
    draw_mark(base, 0.60, (0.46, 0.34, 0.22), WHITE + (255,))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=255)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def adaptive_fg(size, fg):
    """الطبقة الأمامية: الحرف داخل دائرة الأمان (66 من 108dp). خطوط
    السرعة أقصر من النسخة الكاملة كي لا تقصّها أقنعة المشغّلات."""
    S = size * SS
    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_mark(canvas, 0.37, (0.30, 0.22, 0.14), fg)
    return canvas.resize((size, size), Image.LANCZOS)


def adaptive_bg(size, primary):
    S = size * SS
    return grad(S, lighten(primary, 0.42), primary) \
        .resize((size, size), Image.LANCZOS)


def store_icon(primary):
    """أصل متجر جوجل: 512×512 مربّع كامل بلا شفافية — المتجر يرفض ألفا."""
    S = 512 * SS
    base = grad(S, lighten(primary, 0.42), primary).convert('RGBA')
    draw_mark(base, 0.60, (0.46, 0.34, 0.22), WHITE + (255,))
    return base.convert('RGB').resize((512, 512), Image.LANCZOS)


def main():
    for flavor, cfg in FLAVORS.items():
        primary = cfg['primary']
        res = os.path.join(ROOT, 'android', 'app', 'src', flavor, 'res')
        for density, sz in LEGACY.items():
            d = os.path.join(res, f'mipmap-{density}')
            os.makedirs(d, exist_ok=True)
            legacy_icon(sz, primary).save(os.path.join(d, 'ic_launcher.png'))
        for density, sz in ADAPTIVE.items():
            d = os.path.join(res, f'mipmap-{density}')
            adaptive_fg(sz, WHITE + (255,)) \
                .save(os.path.join(d, 'ic_launcher_foreground.png'))
            adaptive_bg(sz, primary) \
                .save(os.path.join(d, 'ic_launcher_background.png'))
            # طبقة monochrome للأيقونات المُثيَّمة (أندرويد 13+): النظام
            # يلوّنها بنفسه، فتكفي نسخة بيضاء من الطبقة الأمامية.
            adaptive_fg(sz, WHITE + (255,)) \
                .save(os.path.join(d, 'ic_launcher_monochrome.png'))
        anydpi = os.path.join(res, 'mipmap-anydpi-v26')
        os.makedirs(anydpi, exist_ok=True)
        with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w') as f:
            f.write(ADAPTIVE_XML)
        store_dir = os.path.join(ROOT, 'dev-docs', 'brand')
        os.makedirs(store_dir, exist_ok=True)
        store_icon(primary).save(
            os.path.join(store_dir, f'ic_store_{flavor}_512.png'))
        print(f'{flavor}: تم — legacy×5 + adaptive×5×3 + anydpi + store 512')


if __name__ == '__main__':
    main()
