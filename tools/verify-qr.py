#!/usr/bin/env python3
"""فحص مولّد QR — الخطوة الثانية: يفكّ كل حالة بماسحٍ حقيقي.

يُرسم كل رمزٍ صورةً أبيض/أسود بهامش المعيار (٤ وحدات) ثم يُمرَّر على
كاشفَي OpenCV. الحكم على كاشف ArUco لأنه الأحدث والأقدر؛ ويُبلَّغ عن
عجز الكاشف التقليدي تنبيهاً لا فشلاً (يعجز عن القناع صفر حتى مع رموز
المكتبات المرجعية، ولهذا يستبعده مولّدنا أصلاً).

التشغيل:  node tools/verify-qr.js && python3 tools/verify-qr.py
يتطلّب:   pip install opencv-python-headless numpy
"""
import json
import os
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CASES = os.path.join(HERE, 'verify-qr-cases.json')

if not os.path.exists(CASES):
    sys.exit('لم يُعثر على الحالات — شغّل أولاً: node tools/verify-qr.js')

data = json.load(open(CASES, encoding='utf-8'))
aruco = cv2.QRCodeDetectorAruco()
legacy = cv2.QRCodeDetector()

SCALE, QUIET = 8, 4
ok = fail = 0
for text, q in data.items():
    n = q['n']
    size = (n + QUIET * 2) * SCALE
    img = np.full((size, size), 255, np.uint8)
    for i in range(n):
        for j in range(n):
            if q['m'][i][j]:
                img[(i + QUIET) * SCALE:(i + QUIET + 1) * SCALE,
                    (j + QUIET) * SCALE:(j + QUIET + 1) * SCALE] = 0
    got = aruco.detectAndDecode(img)[0]
    if got == text:
        ok += 1
        if legacy.detectAndDecode(img)[0] != text:
            print('⚠ الكاشف التقليدي عجز — إصدار %d قناع %d' % (q['ver'], q['mask']))
    else:
        fail += 1
        print('✗ إصدار %d قناع %d طول %d — قُرئ: %r' % (q['ver'], q['mask'], len(text), got[:40]))

print('\n%s %d من %d' % ('✗ فشل' if fail else '✓ نجح', fail or ok, ok + fail))
sys.exit(1 if fail else 0)
