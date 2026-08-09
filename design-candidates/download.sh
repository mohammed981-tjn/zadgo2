#!/usr/bin/env bash
# تنزيل مرشحات تصاميم Canva الاثني عشر (a1..c4) إلى هذا المجلد.
# الروابط موقّعة ومؤقتة (تنتهي صلاحيتها خلال ساعات من 2026-08-09 ~01:00 UTC).
# إن انتهت الصلاحية: أعد التصدير عبر Canva MCP (export-design) بمعرّفات التصاميم في urls.tsv.
set -u
cd "$(dirname "$0")"
ok=0
fail=""
while IFS=$'\t' read -r name design_id url; do
  [ -z "${name:-}" ] && continue
  if curl -fsSL --retry 3 --max-time 120 -o "$name" "$url" \
     && file "$name" | grep -q "JPEG" \
     && [ "$(stat -c%s "$name")" -gt 20480 ]; then
    ok=$((ok+1))
    echo "OK   $name ($(stat -c%s "$name") bytes)"
  else
    rm -f "$name"
    fail="$fail $name"
    echo "FAIL $name"
  fi
done < urls.tsv
echo "DONE: $ok/12${fail:+ — failed:$fail}"
