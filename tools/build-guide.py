#!/usr/bin/env python3
"""يولّد صفحة دليلٍ منشورة من ملف Markdown في dev-docs/guides.

    python3 tools/build-guide.py <مصدر.md> <وجهة/index.html> <النكهة> \
        "<العنوان>" "<الوصف>" ["<سبب حجب الفهرسة>"]

المعامل السادس اختياري: إن مُرِّر أُضيف وسم `noindex` مسبوقاً بنصّه تعليقاً
يشرح سبب الحجب. **ولماذا معاملٌ لا تحريرٌ بعد التوليد؟** لأن ما يُضاف باليد
يضيع عند أول إعادة توليد، فتُفهرَس صفحةٌ كنّا قرّرنا حجبها ولا أحد ينتبه.

**لماذا مولِّدٌ لا تحرير يدوي؟** لأن نصّ الأدلة يكتبه مساعد التطبيق وهو
الأعلم بشاشاته، ونسخُه بيدي إلى HTML يعني مرجعين يفترقان عند أول تعديل —
ودليلٌ يكذب أسوأ من غياب دليل. فالمصدر واحد، وهذه الصفحة صورةٌ منه تُعاد
كلما تغيّر.

يدعم من Markdown ما تستعمله الأدلة فعلاً: العناوين، والجداول، والقوائم
المرقّمة والنقطية، والاقتباسات، وكتل الشيفرة، والغامق، والشيفرة السطرية.
وكل نصٍّ يُهرَّب قبل الإخراج.
"""
import html
import re
import sys

FLAVORS = {                     # ألوان نكهات التطبيق من lib/utils/theme.dart
    'restaurant': ('#E8590C', '#BF4506', '#2A1204', '#160902'),
    'customer':   ('#D4A017', '#B8860B', '#08211A', '#04120D'),
    'driver':     ('#1976D2', '#0D47A1', '#0A1E38', '#050F1E'),
    # الإدارة نكهةٌ لا وجود لها في التطبيق — ألوانها من لوحة التحكم نفسها
    # (docs/admin/index.html) ليعرف المدير أنه في بيت لوحته لا في صفحة عامة.
    'admin':      ('#13224a', '#26407f', '#0b1631', '#060e1f'),
}


def inline(t):
    """الغامق والشيفرة السطرية — بعد التهريب، فلا يصير نصُّ الدليل وسوماً."""
    t = html.escape(t)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', t)
    return t


def convert(md):
    out, i, lines = [], 0, md.split('\n')
    while i < len(lines):
        ln = lines[i]

        if ln.startswith('```'):                      # كتلة شيفرة
            i += 1
            buf = []
            while i < len(lines) and not lines[i].startswith('```'):
                buf.append(html.escape(lines[i]))
                i += 1
            out.append('<pre>' + '\n'.join(buf) + '</pre>')

        elif re.match(r'^\|.*\|\s*$', ln) and i + 1 < len(lines) \
                and re.match(r'^\|[\s:|-]+\|\s*$', lines[i + 1]):
            head = [c.strip() for c in ln.strip().strip('|').split('|')]
            i += 2
            rows = []
            while i < len(lines) and re.match(r'^\|.*\|\s*$', lines[i]):
                rows.append([c.strip() for c in lines[i].strip().strip('|').split('|')])
                i += 1
            i -= 1
            out.append(
                '<div class="tw"><table><thead><tr>'
                + ''.join(f'<th>{inline(c)}</th>' for c in head)
                + '</tr></thead><tbody>'
                + ''.join('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in r) + '</tr>'
                          for r in rows)
                + '</tbody></table></div>')

        elif ln.startswith('> '):                     # اقتباس
            buf = []
            while i < len(lines) and lines[i].startswith('>'):
                buf.append(lines[i].lstrip('>').strip())
                i += 1
            i -= 1
            out.append('<blockquote>' + inline(' '.join(buf)) + '</blockquote>')

        elif re.match(r'^\d+\. ', ln) or ln.startswith('- '):
            ordered = bool(re.match(r'^\d+\. ', ln))
            tag = 'ol' if ordered else 'ul'
            items = []
            while i < len(lines) and (re.match(r'^\d+\. ', lines[i]) or lines[i].startswith('- ')
                                      or lines[i].startswith('   ') or lines[i].startswith('  ')):
                if re.match(r'^\d+\. ', lines[i]):
                    items.append(re.sub(r'^\d+\. ', '', lines[i]))
                elif lines[i].startswith('- '):
                    items.append(lines[i][2:])
                elif items:
                    items[-1] += ' ' + lines[i].strip()   # سطر متابعة
                i += 1
            i -= 1
            out.append(f'<{tag}>' + ''.join(f'<li>{inline(x)}</li>' for x in items) + f'</{tag}>')

        elif ln.startswith('#'):
            # العنوان الأول (h1) في ترويسة الصفحة، فأقسام الملف تبدأ من h2.
            # والحدّ الأدنى h2 حتى لا يظهر عنوانان من الدرجة الأولى لو بقي
            # `#` في المتن — وهو ما يُربك قارئات الشاشة ومحركات البحث.
            lvl = max(2, min(len(ln) - len(ln.lstrip('#')), 4))
            out.append(f'<h{lvl}>{inline(ln.lstrip("# ").strip())}</h{lvl}>')

        elif ln.strip() == '---':
            out.append('<hr>')

        elif ln.strip():
            buf = []
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(('#', '-', '>', '|', '`')) \
                    and not re.match(r'^\d+\. ', lines[i]) and lines[i].strip() != '---':
                buf.append(lines[i].strip())
                i += 1
            i -= 1
            out.append('<p>' + inline(' '.join(buf)) + '</p>')

        i += 1
    return '\n'.join(out)


TPL = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; script-src 'none'; object-src 'none'; base-uri 'self'; form-action 'none'; connect-src 'none'">
<meta name="referrer" content="strict-origin-when-cross-origin">{noindex}
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — زادقو ZadGo</title>
<meta name="description" content="{desc}">
<meta name="theme-color" content="{dark}">
<link rel="canonical" href="https://zadgo.co/{path}">
<link rel="icon" href="/images/zadgo-logo-gold.png">
<link rel="apple-touch-icon" href="/images/apple-touch-icon.png">
<meta property="og:type" content="article">
<meta property="og:title" content="{title} — زادقو ZadGo">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="https://zadgo.co/{path}">
<meta property="og:image" content="https://zadgo.co/images/og-card.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet">
<style>
:root {{ --c:{c1}; --c2:{c2}; --dark:{dark}; --darker:{darker};
  --bg:#F3F5F4; --card:#fff; --line:#E6E9E8; --text:#16211c; --muted:#6f7b76; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ font-family:'Tajawal',Tahoma,sans-serif; background:var(--bg); color:var(--text);
  line-height:1.95; }}
.hero {{ background:linear-gradient(160deg,var(--dark),var(--darker)); color:#fff;
  padding:44px 20px 38px; text-align:center; }}
.hero img {{ height:38px; margin-bottom:14px; }}
.hero h1 {{ font-size:clamp(1.65rem,6vw,2.4rem); font-weight:900; }}
.hero p {{ color:rgba(255,255,255,.72); margin-top:9px; font-size:.98rem; }}
main {{ max-width:760px; margin:0 auto; padding:22px 16px 60px; }}
h2 {{ font-size:1.28rem; font-weight:900; margin:28px 0 10px; padding-inline-start:12px;
  border-inline-start:4px solid var(--c); }}
h3 {{ font-size:1.06rem; font-weight:800; margin:20px 0 8px; color:var(--c2); }}
h4 {{ font-size:.98rem; font-weight:800; margin:16px 0 6px; }}
p {{ margin:10px 0; }}
ul, ol {{ margin:10px 0; padding-inline-start:22px; }}
li {{ margin-bottom:7px; }}
b {{ color:var(--c2); }}
code {{ background:#eceeed; border-radius:6px; padding:1px 6px; font-size:.9em;
  font-family:ui-monospace,monospace; direction:ltr; display:inline-block; }}
pre {{ background:var(--darker); color:#e8efe9; border-radius:13px; padding:15px 17px;
  overflow-x:auto; direction:ltr; text-align:left; font-family:ui-monospace,monospace;
  font-size:.86rem; line-height:1.8; margin:14px 0; }}
blockquote {{ background:#fff; border-inline-start:4px solid var(--c); border-radius:11px;
  padding:12px 16px; margin:14px 0; color:var(--muted); box-shadow:0 2px 8px rgba(0,0,0,.05); }}
.tw {{ overflow-x:auto; margin:14px 0; border-radius:13px; box-shadow:0 2px 10px rgba(0,0,0,.06); }}
table {{ width:100%; border-collapse:collapse; background:var(--card); font-size:.93rem;
  min-width:420px; }}
th {{ background:var(--c); color:#fff; padding:11px 13px; text-align:start; font-weight:800; }}
td {{ padding:11px 13px; border-top:1px solid var(--line); }}
hr {{ border:0; border-top:1px solid var(--line); margin:26px 0; }}
footer {{ border-top:1px solid var(--line); padding:24px 16px 40px; text-align:center;
  color:var(--muted); font-size:.86rem; }}
footer nav {{ display:flex; gap:14px; justify-content:center; flex-wrap:wrap; margin-bottom:10px; }}
footer a {{ color:var(--c2); text-decoration:none; }}
</style>
</head>
<body>
<div class="hero">
  <img src="/images/zadgo-logo.png" alt="ZadGo">
  <h1>{title}</h1>
  <p>{desc}</p>
</div>
<main>
{body}
</main>
<footer>
  <nav>
    <a href="/">الرئيسية</a>
    <a href="/partner/">ضمّ مطعمك</a>
    <a href="/contact.html">التواصل والدعم</a>
    <a href="/terms.html">الشروط والأحكام</a>
  </nav>
  <div>© 2026 زادقو ZadGo — zadgo.co</div>
</footer>
</body>
</html>
"""

if __name__ == '__main__':
    src, dest, flavor, title, desc = sys.argv[1:6]
    hide = sys.argv[6] if len(sys.argv) > 6 else ''
    noindex = ('\n<!-- ' + hide + ' -->\n<meta name="robots" content="noindex">') if hide else ''
    md = open(src, encoding='utf-8').read()
    # العنوان الأول ومذكّرة النسخة يُستبدلان بترويسة الصفحة، فلا يتكرّران.
    md = re.sub(r'^# .*?\n', '', md, count=1)
    md = re.sub(r'^> نسخة التطبيق.*?\n', '', md, count=1, flags=re.M)
    md = md.lstrip('\n-')
    c1, c2, dark, darker = FLAVORS[flavor]
    page = TPL.format(title=html.escape(title), desc=html.escape(desc),
                      path=dest.replace('docs/', '').replace('index.html', ''),
                      c1=c1, c2=c2, dark=dark, darker=darker, body=convert(md),
                      noindex=noindex)
    open(dest, 'w', encoding='utf-8').write(page)
    print(f'{dest}: {len(page)} حرفاً')
