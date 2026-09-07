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
echo "== 3. 배포본 표시 패치 — 은퇴했다 (2026-09-07) =="
# 🔴 이 자리에 있던 `ins_split.pl` 호출을 «내렸다». 원본(exam-qa)이 고쳐졌기 때문이다.
#    · A 지시문 오염 — `parsed/2022` 의 instruction 을 군데별로 판정해 걷어냈다(46문항/14군데).
#      걷어낸 텍스트는 지우지 않고 `instruction_overflow` 에 남겼다.
#      → qa-work/지시문오염_20260907/fix_instruction_overflow.py
#    · B 지문 열림 — build_expl_html.py 가 `::details-content` 로 «CSS 에서» 펼치고,
#      옛 엔진용으로 psgSync(미디어쿼리 change)를 함께 낸다.
# 🔴 «왜 은퇴시켰나» — A 패치가 규칙(120자 초과 또는 선지기호 2개 이상 → 첫 문장까지)으로 잘라
#    세종대 [11-15] 의 「[보기] day : sun :: … 」 예시까지 지웠다. 그 5문항은 발문이
#    `appreciation : kindness ::` 뿐이라 «보기 없는 보기 문제»가 돼 있었다(2026-09-07 라이브 실측).
#    원본이 깨끗해진 지금, 이 패치에 남은 효과는 그 «오탐 피해»뿐이다.
# 📌 `ins_split.pl` 파일은 지우지 않았다 — 되돌릴 일이 생기면 이 줄 아래에 호출을 되살리면 된다.
#    오염이 다시 생기는지는 exam-qa 의 공통 관문 [J] 가 감시한다(tests/test_check_deploy_ready.py 2건).
echo "  ins_split.pl 호출 없음 — 원본이 고쳐졌다. 감시는 공통 관문 [J] 가 한다."
echo
# ─────────────────────────────────────────────────────────────────────────────
# 🛡️ 방어 1 — «사후 변형 금지» (2026-09-07 신설. 사고: exam-dist-2022 c8c7ca0·2949f1c·4eda738)
#   위 3단계 자리에 `ins_split.pl` 후처리 패치가 있었다. 복사 «뒤»에 배포본만 고치므로
#   원본은 고장난 채 남고, 공통 관문은 원본만 보니 **아무것도 안 걸렸다.**
#   그 패치의 규칙이 오탐을 내 세종대 [11-15] 5문항의 진짜 [보기]를 32시간 39분 동안 지웠다.
#   🔴 그래서 «커밋 직전에» 다시 잰다 — 2단계와 4단계 사이에 무엇을 끼워도 여기서 죽는다.
#      배포본을 고치고 싶어지면 그것은 «원본을 고쳐야 한다는 신호»다.
echo "== 4-0. 사후 변형 금지 검사 =="
PYTHONIOENCODING=utf-8 "$SRC_REPO/.venv/Scripts/python.exe" - "$SRC_HTML" "$DIST/index.html" <<'PY'
import sys, hashlib
a, b = sys.argv[1], sys.argv[2]
ha = hashlib.sha256(open(a, "rb").read()).hexdigest()
hb = hashlib.sha256(open(b, "rb").read()).hexdigest()
if ha == hb:
    print("  ✅ 배포본 == 산출방· sha256 %s" % hb[:16])
    sys.exit(0)
print("  🔴 배포본이 산출물과 다르다 — 복사 뒤에 누가 고쳤다.")
print("     산출 %s / 배포 %s" % (ha[:16], hb[:16]))
print("     → 배포본을 고지 말고 exam-qa 의 원본을 고친 뒤 다시 돌린다.")
sys.exit(1)
PY
if [ $? -ne 0 ]; then
  if [ "$FORCE" != "1" ]; then exit 1; fi
  echo "  ⚠️  --force 로 강행한다."
fi

# 🛡️ 방어 4 — «흔적 없는 배포 금지» (2026-09-07 신설. 사고: 09-06 작업이 작업로그 0행)
#   09-06 에 배포 저장소에만 커밋 3건이 남고 `작업로그.md` 에는 한 줄도 없었다.
#   exam-qa 쪽 세션은 그 패치의 존재를 알 길이 없었고, 재빌드하면 조용히 되돌아갔다.
echo "== 4-1. 작업로그 당일 행 검사 =="
TODAY="$(date '+%Y-%m-%d')"
if grep -q "^| $TODAY" "$SRC_REPO/작업로그.md"; then
  echo "  ✅ $TODAY 행이 있다."
else
  echo "  🔴 작업로그.md 에 $TODAY 행이 없다 — 배포는 «기록 없이» 나갈 수 없다."
  echo "     exam-qa 의 작업로그.md 이력 표에 오늘 한 줄을 먼저 남겨라."
  if [ "$FORCE" != "1" ]; then exit 1; fi
  echo "  ⚠️  --force 로 강행한다."
fi
echo
# ─────────────────────────────────────────────────────────────────────────────
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

echo
echo "== 5. 배포 후 검증 =="
( cd "$SRC_REPO" && .venv/Scripts/python.exe scripts/check_deploy_ready.py 2022 --post --skip-slow )
