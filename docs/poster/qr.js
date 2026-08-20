/* مولّد رمز QR — نمط البايت، تصحيح خطأ M.
 *
 * **لماذا نكتبه بأنفسنا؟** سياسة أمان المحتوى تمنع تحميل أي سكربت من خارج
 * النطاق، ومكتبات QR الجاهزة كلها من شبكات توصيل خارجية. والملصق يجب أن
 * يعمل عند المالك بلا إنترنت أيضاً (يفتحه ويطبعه في المطعم).
 *
 * وصحّته ليست ادّعاءً: كلُّ رمزٍ يولّده هذا الملف يُرسم صورةً ثم **يفكّه
 * ماسحٌ حقيقي** (OpenCV) ويُقارن الناتج بالنصّ الأصلي حرفاً بحرف، على
 * خمسٍ وعشرين حالة تغطّي الإصدارات ١..٩ والعربية والأرقام
 * (`tools/verify-qr.js` + `tools/verify-qr.py`).
 *
 * ولم نكتفِ بمقارنة المصفوفة بمكتبة `segno` المرجعية لأن المقارنة خدعتنا
 * مرّتين: مرّةً أظهرت فروقاً وهمية سببها اختلاف حشو النهاية (segno يحشو
 * صفراً قبل EC/11، ونحن نبدأ بـEC مباشرة — وكلاهما صحيح لأن القارئ يتوقّف
 * عند عدّاد الطول فلا يبلغ الحشو أصلاً)، ومرّةً أخفت خللاً حقيقياً في
 * موضع بتّات النسق كان يجعل الرمز غير مقروء رغم سلامة بياناته. الفكُّ
 * بماسحٍ حقيقي هو الحكم، وما عداه قرينة.
 *
 * ورمزٌ مطبوعٌ لا يُقرأ أسوأ من لا ملصق: يقف العميل أمام الكاونتر يحاول
 * ويفشل، فينصرف.
 */
(function (global) {
  'use strict';

  // ── حقل جالوا GF(256) لتصحيح ريد–سولومون ──
  var EXP = new Uint8Array(512), LOG = new Uint8Array(256);
  (function () {
    for (var x = 1, i = 0; i < 255; i++) {
      EXP[i] = x; LOG[x] = i;
      x <<= 1; if (x & 0x100) x ^= 0x11d;      // كثير الحدود الأولي للـQR
    }
    for (var j = 255; j < 512; j++) EXP[j] = EXP[j - 255];
  })();
  function mul(a, b) { return a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]]; }

  function rsPoly(n) {
    var p = [1];
    for (var i = 0; i < n; i++) {
      var q = p.concat([0]);
      for (var j = 0; j < p.length; j++) q[j + 1] ^= mul(p[j], EXP[i]);
      p = q;
    }
    return p;
  }
  function rsEncode(data, n) {
    var gen = rsPoly(n), res = new Array(n).fill(0);
    for (var i = 0; i < data.length; i++) {
      var f = data[i] ^ res[0];
      res.shift(); res.push(0);
      if (f !== 0) for (var j = 0; j < gen.length - 1; j++) res[j] ^= mul(gen[j + 1], f);
    }
    return res;
  }

  // ── جداول السعة والكتل لمستوى التصحيح M (الإصدارات ١..١٠ تكفي رابطاً) ──
  // [مجموع وحدات البيانات بالبايت، عدد وحدات التصحيح لكل كتلة، كتل المجموعة١، كتل المجموعة٢]
  var CAP_M = {
    1: [16, 10, 1, 0], 2: [28, 16, 1, 0], 3: [44, 26, 1, 0], 4: [64, 18, 2, 0],
    5: [86, 24, 2, 0], 6: [108, 16, 4, 0], 7: [124, 18, 4, 0], 8: [154, 22, 2, 2],
    9: [182, 22, 3, 2], 10: [216, 26, 4, 1]
  };
  var ALIGN = {
    1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30],
    6: [6, 34], 7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50]
  };

  function bytesOf(str) {
    var out = [], s = encodeURIComponent(str);
    for (var i = 0; i < s.length; i++) {
      if (s[i] === '%') { out.push(parseInt(s.substr(i + 1, 2), 16)); i += 2; }
      else out.push(s.charCodeAt(i));
    }
    return out;
  }

  function pickVersion(len) {
    for (var v = 1; v <= 10; v++) {
      var cw = CAP_M[v][0];
      var head = 4 + (v < 10 ? 8 : 16);          // مؤشّر النمط + عدّاد الطول
      if (len * 8 + head <= cw * 8) return v;
    }
    throw new Error('النصّ أطول مما يسعه الرمز');
  }

  function buildData(bytes, ver) {
    var t = CAP_M[ver], total = t[0];
    var bits = [];
    function push(val, n) { for (var i = n - 1; i >= 0; i--) bits.push((val >> i) & 1); }
    push(4, 4);                                   // نمط البايت
    push(bytes.length, ver < 10 ? 8 : 16);
    for (var i = 0; i < bytes.length; i++) push(bytes[i], 8);
    var cap = total * 8;
    for (var k = 0; k < 4 && bits.length < cap; k++) bits.push(0);   // نهاية
    while (bits.length % 8) bits.push(0);
    var words = [];
    for (var b = 0; b < bits.length; b += 8) {
      var v = 0; for (var j = 0; j < 8; j++) v = (v << 1) | bits[b + j];
      words.push(v);
    }
    var pad = [0xEC, 0x11], pi = 0;
    while (words.length < total) words.push(pad[pi++ % 2]);
    return words;
  }

  function interleave(words, ver) {
    var t = CAP_M[ver], total = t[0], ecLen = t[1], g1 = t[2], g2 = t[3];
    var nBlocks = g1 + g2;
    var short = Math.floor(total / nBlocks);      // طول كتلة المجموعة الأولى
    var blocks = [], ecs = [], pos = 0;
    for (var i = 0; i < nBlocks; i++) {
      var len = i < g1 ? short : short + 1;
      var blk = words.slice(pos, pos + len); pos += len;
      blocks.push(blk); ecs.push(rsEncode(blk, ecLen));
    }
    var out = [], maxLen = short + (g2 ? 1 : 0);
    for (var c = 0; c < maxLen; c++)
      for (var b = 0; b < nBlocks; b++)
        if (c < blocks[b].length) out.push(blocks[b][c]);
    for (var e = 0; e < ecLen; e++)
      for (var b2 = 0; b2 < nBlocks; b2++) out.push(ecs[b2][e]);
    return out;
  }

  // ── رسم المصفوفة ──
  function makeMatrix(ver) {
    var n = ver * 4 + 17;
    var m = [], reserved = [];
    for (var i = 0; i < n; i++) { m.push(new Array(n).fill(0)); reserved.push(new Array(n).fill(0)); }

    function finder(r, c) {
      for (var dr = -1; dr <= 7; dr++) for (var dc = -1; dc <= 7; dc++) {
        var rr = r + dr, cc = c + dc;
        if (rr < 0 || cc < 0 || rr >= n || cc >= n) continue;
        var on = (dr >= 0 && dr <= 6 && (dc === 0 || dc === 6)) ||
                 (dc >= 0 && dc <= 6 && (dr === 0 || dr === 6)) ||
                 (dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4);
        m[rr][cc] = on ? 1 : 0; reserved[rr][cc] = 1;
      }
    }
    finder(0, 0); finder(0, n - 7); finder(n - 7, 0);

    for (var t = 8; t < n - 8; t++) {             // أنماط التوقيت
      var bit = t % 2 === 0 ? 1 : 0;
      m[6][t] = bit; reserved[6][t] = 1;
      m[t][6] = bit; reserved[t][6] = 1;
    }

    var al = ALIGN[ver];
    for (var a = 0; a < al.length; a++) for (var b = 0; b < al.length; b++) {
      var ar = al[a], ac = al[b];
      if ((ar <= 8 && ac <= 8) || (ar <= 8 && ac >= n - 9) || (ar >= n - 9 && ac <= 8)) continue;
      for (var dr2 = -2; dr2 <= 2; dr2++) for (var dc2 = -2; dc2 <= 2; dc2++) {
        var on2 = Math.max(Math.abs(dr2), Math.abs(dc2)) !== 1;
        m[ar + dr2][ac + dc2] = on2 ? 1 : 0; reserved[ar + dr2][ac + dc2] = 1;
      }
    }

    m[n - 8][8] = 1; reserved[n - 8][8] = 1;      // الوحدة الداكنة الثابتة
    for (var f = 0; f <= 8; f++) {                // مواضع معلومات النسق
      if (f !== 6) { reserved[8][f] = 1; reserved[f][8] = 1; }
    }
    for (var f2 = 0; f2 < 8; f2++) { reserved[8][n - 1 - f2] = 1; reserved[n - 1 - f2][8] = 1; }

    // كتلتا معلومات الإصدار (٧ فأعلى) تُحجزان هنا لا عند كتابتهما: بلا
    // الحجز تملؤهما `placeData` ببتّات بيانات ثم يدهسها `putVersion` —
    // فتضيع ٣٦ بتّة من التيّار دفعةً واحدة، وهو تلفٌ يتجاوز ما يصلحه
    // تصحيح الخطأ فيصير الرمز غير مقروء. (ظهر في الإصدار ٧ وحده.)
    if (ver >= 7) {
      for (var vi = 0; vi < 18; vi++) {
        var va = n - 11 + (vi % 3), vb = Math.floor(vi / 3);
        reserved[vb][va] = 1; reserved[va][vb] = 1;
      }
    }
    return { m: m, reserved: reserved, n: n };
  }

  function placeData(st, words) {
    var m = st.m, res = st.reserved, n = st.n;
    var bits = [];
    for (var i = 0; i < words.length; i++)
      for (var b = 7; b >= 0; b--) bits.push((words[i] >> b) & 1);
    var idx = 0, up = true;
    for (var col = n - 1; col > 0; col -= 2) {
      if (col === 6) col--;                        // عمود التوقيت يُتخطّى
      for (var r = 0; r < n; r++) {
        var row = up ? n - 1 - r : r;
        for (var c = 0; c < 2; c++) {
          var cc = col - c;
          if (res[row][cc]) continue;
          m[row][cc] = idx < bits.length ? bits[idx++] : 0;
        }
      }
      up = !up;
    }
  }

  function maskFn(k) {
    return [
      function (r, c) { return (r + c) % 2 === 0; },
      function (r) { return r % 2 === 0; },
      function (r, c) { return c % 3 === 0; },
      function (r, c) { return (r + c) % 3 === 0; },
      function (r, c) { return (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0; },
      function (r, c) { return (r * c) % 2 + (r * c) % 3 === 0; },
      function (r, c) { return ((r * c) % 2 + (r * c) % 3) % 2 === 0; },
      function (r, c) { return ((r + c) % 2 + (r * c) % 3) % 2 === 0; }
    ][k];
  }

  function penalty(m, n) {
    var p = 0, i, j, run, dark = 0;
    for (i = 0; i < n; i++) {                       // ١: تتابعات متجانسة
      run = 1;
      for (j = 1; j < n; j++) {
        if (m[i][j] === m[i][j - 1]) run++;
        else { if (run >= 5) p += 3 + (run - 5); run = 1; }
      }
      if (run >= 5) p += 3 + (run - 5);
      run = 1;
      for (j = 1; j < n; j++) {
        if (m[j][i] === m[j - 1][i]) run++;
        else { if (run >= 5) p += 3 + (run - 5); run = 1; }
      }
      if (run >= 5) p += 3 + (run - 5);
    }
    for (i = 0; i < n - 1; i++) for (j = 0; j < n - 1; j++) { // ٢: مربّعات
      var v = m[i][j];
      if (v === m[i][j + 1] && v === m[i + 1][j] && v === m[i + 1][j + 1]) p += 3;
    }
    var pat1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0], pat2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
    function match(get, len) {                       // ٣: نمط شبيه بالمُحدِّد
      for (var s = 0; s + 11 <= len; s++) {
        var ok1 = true, ok2 = true;
        for (var k = 0; k < 11; k++) {
          var val = get(s + k);
          if (val !== pat1[k]) ok1 = false;
          if (val !== pat2[k]) ok2 = false;
        }
        if (ok1) p += 40;
        if (ok2) p += 40;
      }
    }
    for (i = 0; i < n; i++) {
      (function (row) { match(function (k) { return m[row][k]; }, n); })(i);
      (function (col) { match(function (k) { return m[k][col]; }, n); })(i);
    }
    for (i = 0; i < n; i++) for (j = 0; j < n; j++) if (m[i][j]) dark++;
    var ratio = dark * 100 / (n * n);                // ٤: توازن الداكن
    p += Math.floor(Math.abs(ratio - 50) / 5) * 10;
    return p;
  }

  // معلومات النسق: مستوى M = 00، مع BCH(15,5) وقناع 0x5412
  function formatBits(mask) {
    var data = (0 << 3) | mask;                      // 00 = المستوى M
    var v = data << 10;
    for (var i = 4; i >= 0; i--) if (v & (1 << (i + 10))) v ^= 0x537 << i;
    return ((data << 10) | v) ^ 0x5412;
  }
  /* موضع بتّات النسق: **الصفّ والعمود لا يُبدَّلان**. كانا مقلوبين فوقعت
   * البتّات في مواضع منقولة بالمحورين — والنتيجة رمزٌ سليم البيانات لا
   * يقرؤه قارئ إطلاقاً، لأن النسق أوّل ما يقرأه ليعرف القناع والمستوى.
   * كشفه فحصٌ بقارئٍ حقيقي بعد أن أوهمتني مقارنةُ المصفوفات أن الخلل
   * في البيانات. */
  function putFormat(st, mask) {
    var bitsF = formatBits(mask), n = st.n, m = st.m;
    for (var i = 0; i < 15; i++) {
      var bit = (bitsF >> i) & 1;
      // النسخة الأولى: عمود ٨ نزولاً، ثم صفّ ٨ نحو اليسار
      if (i < 6) m[i][8] = bit;
      else if (i === 6) m[7][8] = bit;
      else if (i === 7) m[8][8] = bit;
      else if (i === 8) m[8][7] = bit;
      else m[8][14 - i] = bit;
      // النسخة الثانية: طرف صفّ ٨، ثم أسفل عمود ٨
      if (i < 8) m[8][n - 1 - i] = bit;
      else m[n - 15 + i][8] = bit;
    }
  }
  // معلومات الإصدار (٧ فأعلى فقط)
  function putVersion(st, ver) {
    if (ver < 7) return;
    var v = ver << 12;
    for (var i = 5; i >= 0; i--) if (v & (1 << (i + 12))) v ^= 0x1f25 << i;
    var bitsV = (ver << 12) | v, n = st.n;
    for (var i2 = 0; i2 < 18; i2++) {
      var bit = (bitsV >> i2) & 1;
      var r = Math.floor(i2 / 3), c = i2 % 3;
      st.m[n - 11 + c][r] = bit;
      st.m[r][n - 11 + c] = bit;
    }
  }

  /** [forceMask] لتثبيت القناع في الاختبارات — يُترك فارغاً في الإنتاج
   * فيُختار أقلّ الأقنعة عقوبةً كما يوجب المعيار.
   *
   * القناع صفر (رقعة الشطرنج) مستبعَد عمداً: الرمز به سليمٌ مئة بالمئة
   * ومطابقٌ للمعيار، لكن كاشف OpenCV التقليدي يعجز عن قراءته — أثبتُّ
   * أنه عجزُ الكاشف لا عجزُ مولّدنا بأن مرّرت له رمز مكتبة segno بالقناع
   * نفسه ففشل هو أيضاً، بينما قرأه كاشف ArUco في المكتبة ذاتها بكل
   * المقاييس. وما دام هذا الكاشف مدفوناً في تطبيقات مسحٍ كثيرة، وما دام
   * أيُّ قناعٍ آخر يعطي رمزاً صحيحاً بفارق «عقوبة» ضئيل، فاستبعاده ثمنٌ
   * زهيد أمام ملصقٍ مطبوعٍ يمسحه ناسٌ بتطبيقات لا نعرفها. */
  function encode(text, forceMask) {
    var bytes = bytesOf(text);
    var ver = pickVersion(bytes.length);
    var words = interleave(buildData(bytes, ver), ver);
    var best = null;
    for (var k = 0; k < 8; k++) {
      if (forceMask != null && k !== forceMask) continue;
      if (forceMask == null && k === 0) continue;
      var st = makeMatrix(ver);
      placeData(st, words);
      var f = maskFn(k);
      for (var r = 0; r < st.n; r++) for (var c = 0; c < st.n; c++)
        if (!st.reserved[r][c] && f(r, c)) st.m[r][c] ^= 1;
      putFormat(st, k); putVersion(st, ver);
      var pen = penalty(st.m, st.n);
      if (!best || pen < best.pen) best = { pen: pen, m: st.m, n: st.n, ver: ver, mask: k };
    }
    return best;
  }

  /** يُرجع نصّ SVG لرمزٍ يمثّل [text]، بهامشٍ قدره ٤ وحدات (المعيار). */
  function svg(text, opts) {
    opts = opts || {};
    var q = encode(text), n = q.n, quiet = 4, size = n + quiet * 2;
    var d = '';
    for (var r = 0; r < n; r++) for (var c = 0; c < n; c++)
      if (q.m[r][c]) d += 'M' + (c + quiet) + ' ' + (r + quiet) + 'h1v1h-1z';
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + size + ' ' + size +
      '" shape-rendering="crispEdges" role="img" aria-label="' + (opts.label || 'QR') + '">' +
      '<rect width="' + size + '" height="' + size + '" fill="' + (opts.bg || '#fff') + '"/>' +
      '<path d="' + d + '" fill="' + (opts.fg || '#000') + '"/></svg>';
  }

  // يُكشف الداخل للفحص وحده (tools/verify-qr.js): تشخيص أيّ فشلٍ في الفكّ
  // يحتاج بلوغ الكلمات والمصفوفة قبل القناع، ولا سبيل إليها بلا هذا.
  global.ZadQR = { encode: encode, svg: svg,
    _internals: { buildData: buildData, interleave: interleave,
                  makeMatrix: makeMatrix, maskFn: maskFn, pickVersion: pickVersion,
                  bytesOf: bytesOf, placeData: placeData, putFormat: putFormat,
                  putVersion: putVersion, penalty: penalty } };
})(typeof window !== 'undefined' ? window : globalThis);
