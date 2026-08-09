#!/usr/bin/env bash
# ينزّل خلفيات صفحة الهبوط الثلاث ويضعها مباشرة في docs/images/.
# تُشغَّل من جذر المستودع:  bash design-drop/download.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/docs/images"
mkdir -p "$dest"
ok=0; fail=""
while IFS=$'\t' read -r name design_id url; do
  [ -z "${name:-}" ] && continue
  out="$dest/$name"
  if curl -fsSL --retry 3 --max-time 120 -o "$out" "$url" \
     && file "$out" | grep -q "JPEG" \
     && [ "$(stat -c%s "$out")" -gt 20480 ]; then
    ok=$((ok+1)); echo "OK   $name  ($(stat -c%s "$out") bytes)  ← $design_id"
  else
    rm -f "$out"; fail="$fail $name"; echo "FAIL $name  ← $design_id"
  fi
done < "$root/design-drop/urls.tsv"
echo "DONE: $ok/3${fail:+ — failed:$fail}"
[ -z "$fail" ] || exit 2
