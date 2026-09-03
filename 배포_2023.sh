#!/usr/bin/env bash
# 2023 편입영어 해설집 — 같은 Pages 저장소의 «/2023/» 하위 경로로 배포한다.
#
# 🔴 2023 전용 저장소를 따로 만들지 않은 것은 2026-09-03 사용자 결정이다.
#    URL 에 2022 가 남지만 저장소·자격증명을 하나로 유지하는 쪽을 택했다.
# 검사를 건너뛰려면: ./배포_2023.sh --force   (테스트 배포용)

set -u
SRC_REPO="/c/Users/jbseo/Desktop/exam-qa"
SRC_HTML="$SRC_REPO/dist/2023/2023_편입영어_해설.html"
DIST="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

echo "== 1. 산출물 확인 =="
if [ ! -f "$SRC_HTML" ]; then
  echo "  🔴 산출물이 없다: $SRC_HTML"
  echo "     python scripts/build_expl_html.py 2023 --scope sale  를 먼저 돌려라."
  exit 1
fi
python - "$SRC_REPO" <<'PY'
import sys, os, glob, datetime
repo = sys.argv[1]
html = os.path.join(repo, "dist/2023/2023_편입영어_해설.html")
ht = os.path.getmtime(html)
print("  산출물: %s bytes · %s" % (
    format(os.path.getsize(html), ","),
    datetime.datetime.fromtimestamp(ht).strftime("%Y-%m-%d %H:%M")))
newer = [p for p in glob.glob(os.path.join(repo, "parsed/2023/*.json"))
         if ".bak_" not in p and os.path.getmtime(p) > ht]
if newer:
    print("  🔴 parsed/2023 %d개가 산출물보다 «새롭다» — 재빌드가 필요하다." % len(newer))
    for p in newer[:5]:
        print("      %s" % os.path.basename(p))
    sys.exit(2)
print("  ✅ parsed/2023 대비 최신이다.")
PY
STALE=$?

echo
echo "== 2. 게이트 =="
# 🔴 2022 스크립트는 블로커를 손으로 열거하지만 2023 은 게이트를 그대로 부른다 —
#    검사 목록이 갈라져 한쪽만 낡는 것을 막는다.
( cd "$SRC_REPO" && PYTHONIOENCODING=utf-8 .venv/Scripts/python.exe scripts/gate_expl_html.py 2023 --scope sale >/dev/null 2>&1 )
GATE=$?
[ "$GATE" = "0" ] && echo "  ✅ gate_expl_html 2023 --scope sale PASS" \
                  || echo "  🔴 게이트 FAIL — exam-qa 에서 직접 돌려 원인을 볼 것."

echo
if [ "$STALE" != "0" ] || [ "$GATE" != "0" ]; then
  echo "🔴 배포 조건을 만족하지 못했다."
  if [ "$FORCE" != "1" ]; then
    echo "   학생이 «돈을 내고» 보는 상품이다. 고친 뒤 다시 실행하라."
    exit 1
  fi
  echo "⚠️  --force 라 «결함을 알면서» 계속한다."
else
  echo "✅ 배포 조건 통과."
fi

echo
echo "== 3. 복사 =="
mkdir -p "$DIST/2023"
cp "$SRC_HTML" "$DIST/2023/index.html" || exit 1
python - "$SRC_HTML" "$DIST/2023/index.html" <<'PY'
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
git add 2023/index.html 배포_2023.sh README.md
if git diff --cached --quiet; then
  echo "  변경 없음 — 커밋 생략."
else
  git commit -m "2023 재배포 $(date '+%Y-%m-%d %H:%M')" || exit 1
fi
git push && echo "  ✅ push 완료. https://jbseo-commits.github.io/eduwill-bupyeong-2022/2023/"
