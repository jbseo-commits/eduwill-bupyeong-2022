#!/usr/bin/env bash
# 2022 편입영어 해설집 — GitHub Pages 배포 스크립트
#
# 🔴 2026-09-05 — 검사를 «공통 관문»으로 옮겼다.
#    그 전에는 이 스크립트와 배포_2023.sh 가 «서로 다른 것»을 검사했다:
#      · 배포.sh 는 블로커를 손으로 열거하고 게이트를 안 불렀다 · PYTHONIOENCODING 도 없었다
#      · 배포_2023.sh 는 게이트만 부르고 규모·자립성·밑줄·사람판정을 안 봤다
#    이제 둘 다 `scripts/check_deploy_ready.py` 하나를 부른다.
#    **어느 세션(Claude·Codex·안티그래비티)이 돌려도 같은 판정이 나온다.**
#    검사를 늘리려면 이 파일이 아니라 그 스크립트를 고칠 것.
#
# 검사를 건너뛰려면: ./배포.sh --force   (테스트 배포용)
#   ⛔ --force 는 「결함을 알면서 강행한다」는 뜻이다. 습관적으로 쓰지 말 것.

set -u
SRC_REPO="/c/Users/jbseo/Desktop/exam-qa"
SRC_HTML="$SRC_REPO/dist/2022/2022_편입영어_해설.html"
DIST="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

echo "== 1. 배포 전 공통 관문 =="
# 🔴 PYTHONIOENCODING 은 관문 «안에서» 못박혀 있다 — 호출자에게 당부하지 않는다(2026-08-31 사고).
( cd "$SRC_REPO" && .venv/Scripts/python.exe scripts/check_deploy_ready.py 2022 )
READY=$?

echo
if [ "$READY" != "0" ]; then
  echo "🔴 배포 조건을 만족하지 못했다."
  if [ "$FORCE" != "1" ]; then
    echo "   학생이 «돈을 내고» 보는 상품이다. 고친 뒤 다시 실행하라."
    exit 1
  fi
  echo "⚠️  --force 라 «결함을 알면서» 계속한다."
fi

echo "== 2. 복사 =="
cp "$SRC_HTML" "$DIST/index.html" || exit 1
PYTHONIOENCODING=utf-8 "$SRC_REPO/.venv/Scripts/python.exe" - "$SRC_HTML" "$DIST/index.html" <<'PY'
import sys, hashlib, os
a, b = sys.argv[1], sys.argv[2]
ha = hashlib.sha256(open(a, "rb").read()).hexdigest()
hb = hashlib.sha256(open(b, "rb").read()).hexdigest()
print("  %s bytes · sha256 %s · 동일 %s" % (format(os.path.getsize(b), ","), hb[:16], ha == hb))
sys.exit(0 if ha == hb else 1)
PY
[ $? -ne 0 ] && echo "  🔴 복사본이 원본과 다르다." && exit 1
echo
echo "== 3. 지시문 표시 패치 · 오염 현황 =="
# 🔴 «복사 뒤»에 와야 한다 — 2단계가 원본으로 덮어써 이 패치를 지우기 때문이다.
#    원본(exam-qa)의 지시문 추출기가 지시문 뒤 텍스트를 못 끊어, 앞 지문 꼬리와 남의 선지가
#    i(지시문) 필드에 딸려 들어온 문항이 있다(2022: 51문항·15군데·9개 시험지, 2026-09-05 확인).
#    ⛔ 데이터를 «지우지 않는다» — 15군데 중 7군데는 그 텍스트가 문서에서 «여기에만» 있다(실측).
#       그래서 화면에서만 두 블록으로 가른다. 내용 손실 0을 실측으로 확인했다.
#    📌 아래 출력이 «오염 의심 0개»가 되면 원본이 고쳐진 것이다. 그때 이 단계를 지워라.
perl "$DIST/ins_split.pl" "$DIST/index.html" || {
  echo "  🔴 지시문 표시 패치에 실패했다."; exit 1; }
# 조용히 빠지면 지시문이 다시 한 줄로 이어져 나간다 — 파일에 «있는지» 눈으로 확인한다.
grep -q "function insBlocks(" "$DIST/index.html" || {
  echo "  🔴 표시 패치가 파일에 들어가지 않았다."; exit 1; }

echo
echo "== 4. 커밋 · 푸시 =="
cd "$DIST" || exit 1
git add index.html .nojekyll robots.txt README.md ins_split.pl 배포.sh
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

echo
echo "== 5. 배포 후 검증 =="
( cd "$SRC_REPO" && .venv/Scripts/python.exe scripts/check_deploy_ready.py 2022 --post --skip-slow )
