#!/usr/bin/env bash
# 2022 편입영어 해설집 — GitHub Pages 배포 스크립트
#
# 하는 일: 산출물 최신성 + 배포 블로커를 «실측»한 뒤 통과할 때만 배포한다.
# 검사를 건너뛰려면: ./배포.sh --force   (테스트 배포용)

set -u
SRC_REPO="/c/Users/jbseo/Desktop/exam-qa"
SRC_HTML="$SRC_REPO/dist/2022/2022_편입영어_해설.html"
DIST="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

echo "== 1. 산출물 확인 =="
if [ ! -f "$SRC_HTML" ]; then
  echo "  🔴 산출물이 없다: $SRC_HTML"
  echo "     python scripts/build_expl_html.py 2022 --scope sale  를 먼저 돌려라."
  exit 1
fi
python - "$SRC_REPO" <<'PY'
import sys, os, glob, datetime
repo = sys.argv[1]
html = os.path.join(repo, "dist/2022/2022_편입영어_해설.html")
ht = os.path.getmtime(html)
print("  산출물: %s bytes · %s" % (
    format(os.path.getsize(html), ","),
    datetime.datetime.fromtimestamp(ht).strftime("%Y-%m-%d %H:%M")))
# parsed 가 산출물보다 새로우면 재빌드가 필요하다
newer = [p for p in glob.glob(os.path.join(repo, "parsed/2022/*.json"))
         if ".bak_" not in p and os.path.getmtime(p) > ht]
if newer:
    print("  🔴 parsed/2022 %d개가 산출물보다 «새롭다» — 재빌드가 필요하다." % len(newer))
    for p in newer[:5]:
        print("      %s" % os.path.basename(p))
    sys.exit(2)
print("  ✅ parsed/2022 대비 최신이다.")
PY
STALE=$?

echo
echo "== 2. 배포 블로커 실측 =="
python - "$SRC_REPO" <<'PY'
import sys, os, io, json, glob, re, collections
repo = sys.argv[1]
def load(p):
    return [q for q in json.loads(io.open(p, encoding="utf-8").read()) if isinstance(q, dict)]
files = [f for f in sorted(glob.glob(os.path.join(repo, "parsed/2022/*.json")))
         if "school_index" not in f]
def track(qs):
    c = collections.Counter((q.get("track") or "") for q in qs); c.pop("", None)
    return c.most_common(1)[0][0] if c else None
sale = [f for f in files if track(load(f)) != "자연"]

bad = 0
# ② 지시문 잘림
cut = 0
for f in sale:
    for q in load(f):
        for s in (q.get("instruction"), (q.get("print") or {}).get("instruction_block")):
            if s and re.search(r"answer the\s*$", s.strip()):
                cut += 1; break
print("  ② 지시문 잘림      : %d문항  (0 이어야 한다)" % cut)
bad += 1 if cut else 0

# ③ 구획형 오추출 — 보기에 문장부호로 끝나는 «지문 조각»이 들어간 경우
targets = [("성균관대학교_인문계", ("21", "22")), ("가천대학교_인문계2교시A형", ("27",))]
seg = 0
for sheet, qns in targets:
    p = os.path.join(repo, "parsed/2022/%s.json" % sheet)
    if not os.path.exists(p): continue
    for q in load(p):
        if str(q.get("question_num")) not in qns: continue
        ch = q.get("choices") or {}
        # 보기가 100자를 넘거나 마침표로 끝나면 지문 조각이다
        if any(len(str(v)) > 100 or str(v).strip().endswith(".") for v in ch.values()):
            seg += 1
            print("     🔴 %s Q%s" % (sheet, q.get("question_num")))
print("  ③ 구획형 오추출    : %d문항  (0 이어야 한다)" % seg)
bad += 1 if seg else 0

sys.exit(3 if bad else 0)
PY
BLOCKED=$?

echo
if [ "$STALE" != "0" ] || [ "$BLOCKED" != "0" ]; then
  echo "🔴 배포 조건을 만족하지 못했다."
  if [ "$FORCE" != "1" ]; then
    echo "   학생이 «돈을 내고» 보는 상품이다. 고친 뒤 다시 실행하라."
    echo "   테스트 목적이면: ./배포.sh --force"
    exit 1
  fi
  echo "⚠️  --force 라 «결함을 알면서» 계속한다."
else
  echo "✅ 배포 조건 통과."
fi

echo
echo "== 3. 복사 =="
cp "$SRC_HTML" "$DIST/index.html" || exit 1
python - "$SRC_HTML" "$DIST/index.html" <<'PY'
import sys, hashlib, os
a, b = sys.argv[1], sys.argv[2]
ha = hashlib.sha256(open(a, "rb").read()).hexdigest()
hb = hashlib.sha256(open(b, "rb").read()).hexdigest()
print("  %s bytes · sha256 %s · 동일 %s" % (format(os.path.getsize(b), ","), hb[:16], ha == hb))
sys.exit(0 if ha == hb else 1)
PY
[ $? -ne 0 ] && echo "  🔴 복사본이 원본과 다르다." && exit 1

echo
echo "== 4. 커밋 · 푸시 =="
cd "$DIST" || exit 1
git add index.html .nojekyll robots.txt README.md 배포.sh
if git diff --cached --quiet; then
  echo "  변경 없음 — 커밋 생략."
else
  git commit -m "재배포 $(date '+%Y-%m-%d %H:%M')" || exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
  git push && echo "  ✅ push 완료. Pages 반영에 최대 10분 걸린다(CDN 캐시)."
else
  echo "  ℹ️  origin 이 없다. README.md 의 «최초 1회» 절차를 먼저 하라."
fi
