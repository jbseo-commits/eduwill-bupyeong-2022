#!/usr/bin/env perl
# 해설집 배포본 — 표시 결함 패치 + 오염 현황 보고
#
# A. 지시문 오염 (2026-09-05 제보)
#    원본(exam-qa)의 지시문 추출기가 지시문 뒤에 이어지는 텍스트를 끊지 못해,
#    앞 지문의 꼬리와 «남의 선지»가 i(지시문) 필드에 딸려 들어온 문항이 있다.
#    ⛔ 지우지 않는다 — 15군데 중 7군데는 그 텍스트가 문서에서 «여기에만» 있다(실측).
#       데이터는 그대로 두고 화면에 «첫 문장(=진짜 지시문)만» 그린다.
#
# B. 지문이 접힌 채 «여는 버튼»까지 숨는 문제 (2026-09-06 제보)
#    card() 는 WIDE()(768px)를 «렌더 시점에 한 번» 평가해 details 의 open 을 굳히는데
#    CSS 는 실시간이다. 좁을 때 렌더된 카드를 넓히면
#    `.card.two .colp summary{display:none}` 로 여는 버튼이 사라지고 지문은 접힌 채 남는다.
#    실측 — details 높이 9px, 지문 열 방법 없음. 넓은 화면에서는 항상 열어 준다.
#
# 진짜 수정은 A 는 exam-qa 의 추출기, B 는 card() 의 open 판정이다.
# 멱등이다. 줄바꿈(LF/CRLF)에 의존하지 않는다. v1/v2 가 심긴 파일도 최신으로 승급한다.
use strict; use warnings; use utf8;
use Encode qw(decode_utf8 encode_utf8);
binmode(STDOUT, ':encoding(UTF-8)');

my $f = shift or die "usage: ins_split.pl <index.html>\n";
open(my $in, '<:raw', $f) or die "cannot open $f: $!\n";
local $/; my $d = <$in>; close $in;
my $before = length $d;
my $changed = 0;

# ── 현황 보고 (패치 여부와 무관하게 «항상» 찍는다) ────────────────
my $h = decode_utf8($d);
my $beg = index($h, '[{"s":"');
my %flag; my $items = 0; my $flagged = 0;
if ($beg >= 0) {
  my $fin = index($h, '</script>', $beg);
  my $arr = substr($h, $beg, $fin - $beg);
  my @st; my $pos = 0;
  while (($pos = index($arr, '{"s":"', $pos)) >= 0) { push @st, $pos; $pos += 6 }
  for my $k (0 .. $#st) {
    my $rec = substr($arr, $st[$k], ($k < $#st ? $st[$k+1]-$st[$k] : length($arr)-$st[$k]));
    my ($s) = $rec =~ /^\{"s":"([^"]*)"/;
    my $ia = index($rec, '"i":"'); my $iz = index($rec, '","q":"', $ia);
    next if $ia < 0 || $iz < 0;
    my $i = substr($rec, $ia+5, $iz-$ia-5);
    $items++;
    my $circ = () = $i =~ /[\x{2460}-\x{2473}]/g;
    next unless (length($i) > 120 || $circ >= 2);
    $flagged++; $flag{$s}{n}++; $flag{$s}{sites}{$i} = 1;
  }
}
my $sites = 0; $sites += scalar(keys %{$flag{$_}{sites}}) for keys %flag;
printf "  지시문 점검: 문항 %d개 중 오염 의심 %d개 · %d군데 · %d개 시험지\n",
  $items, $flagged, $sites, scalar(keys %flag);
if (%flag) {
  for my $s (sort { $flag{$b}{n} <=> $flag{$a}{n} } keys %flag) {
    printf "      %-28s %2d문항 / %d군데\n", $s, $flag{$s}{n}, scalar(keys %{$flag{$s}{sites}});
  }
  print "      (원본 exam-qa 의 지시문 추출기 문제다. 화면에는 첫 문장만 그린다.)\n";
}

# ── A. 지시문: 첫 문장만 그린다 ──────────────────────────────────
my $V1TAIL = '"</div>"     + "<div class=" + Q + "ins insx" + Q + ">" + esc(rest) + "</div>";';
my $V2TAIL = '"</div>";';

if (index($d, 'function insBlocks(') >= 0) {
  my $c = () = $d =~ /\Q$V1TAIL\E/g;
  if ($c == 1) { $d =~ s/\Q$V1TAIL\E/$V2TAIL/; $changed++;
    print "  ✅ A 지시문 패치 v1 → v2 승급 (딸려온 텍스트를 그리지 않는다)\n"; }
  else { print "  ℹ️  A 지시문 패치는 이미 최신이다.\n"; }
} else {
  my $FN = encode_utf8(join('',
    '/* 지시문 오염 표시 완화 — 데이터는 그대로 두고 «첫 문장만» 그린다.',
    '   플래그(120자 초과 또는 선지기호 2개 이상)가 선 것만 자른다. 정상 지시문은 손대지 않는다. */',
    'function insBlocks(t){',
    'if(!t) return "";',
    'var circ=0, z;',
    'for(z=0; z<t.length; z++){ var cc=t.charCodeAt(z); if(cc>=9312 && cc<=9331) circ++; }',
    'var Q=String.fromCharCode(34);',
    'if(t.length<=120 && circ<2) return "<div class=" + Q + "ins" + Q + ">" + esc(t) + "</div>";',
    'var cut=-1;',
    'for(z=0; z<t.length; z++){ var ch=t.charAt(z); if(ch==="." || ch==="?" || ch==="!"){ cut=z; break; } }',
    'if(cut<0) return "<div class=" + Q + "ins" + Q + ">" + esc(t) + "</div>";',
    'var head=t.slice(0,cut+1), rest=t.slice(cut+1);',
    'while(rest.charAt(0)===" ") rest=rest.slice(1);',
    'if(!rest) return "<div class=" + Q + "ins" + Q + ">" + esc(t) + "</div>";',
    'return "<div class=" + Q + "ins" + Q + ">" + esc(head) + "</div>";',
    '}'));
  my @P = (
    ['function card(x){', $FN . 'function card(x){'],
    ['${x.i?`<div class="ins">${esc(x.i)}</div>`:' . "''" . '}', '${insBlocks(x.i)}'],
  );
  my $n = 0;
  for my $p (@P) { $n++; my $c = () = $d =~ /\Q$p->[0]\E/g;
    die "  🔴 A${n} 패치 대상이 ${c}곳이다(1이어야). 원본이 바뀌었다 — 중단한다.\n" if $c != 1; }
  for my $p (@P) { $d =~ s/\Q$p->[0]\E/$p->[1]/ }
  $changed++;
  print "  ✅ A 지시문 패치 신규 적용\n";
}

# ── B. 넓은 화면에서 지문을 항상 연다 ────────────────────────────
if (index($d, '__psgSync') >= 0) {
  print "  ℹ️  B 지문 열림 동기화는 이미 적용돼 있다.\n";
} else {
  my $JS = encode_utf8(join('',
    '<script>/* __psgSync — 지문이 접힌 채 «여는 버튼»까지 숨는 문제 (2026-09-06)',
    '   card() 가 WIDE()(768px)를 렌더 시점에 한 번만 보고 details 의 open 을 굳히는데 CSS 는 실시간이다.',
    '   좁을 때 렌더된 카드를 넓히면 .card.two .colp summary{display:none} 로 여는 버튼이 사라지고',
    '   지문은 접힌 채 남아 열 방법이 없어진다(실측 details 높이 9px).',
    '   넓은 화면에서 지문이 늘 보이는 것이 원래 의도이므로 그렇게 맞춰 준다.',
    '   진짜 수정은 card() 의 open 판정이다 — exam-qa 가 고쳐지면 이 블록은 아무 일도 하지 않는다. */',
    '(function(){',
    'var mq = window.matchMedia("(min-width:768px)");',
    'function sync(){ if(!mq.matches) return;',
    '  var l = document.querySelectorAll("details.colp:not([open])");',
    '  for(var i=0;i<l.length;i++) l[i].open = true; }',
    'if(mq.addEventListener) mq.addEventListener("change", sync); else if(mq.addListener) mq.addListener(sync);',
    'window.addEventListener("resize", sync);',
    'if(window.MutationObserver) new MutationObserver(sync).observe(document.documentElement,{childList:true,subtree:true});',
    'sync();',
    '})();</script>'));
  my $anchor = '</script></body></html>';
  my $c = () = $d =~ /\Q$anchor\E/g;
  die "  🔴 B 주입 지점이 ${c}곳이다(1이어야). 중단한다.\n" if $c != 1;
  $d =~ s/\Q$anchor\E/'<\/script>' . $JS . '<\/body><\/html>'/e;
  $changed++;
  print "  ✅ B 지문 열림 동기화 적용\n";
}

if (!$changed) { print "  ℹ️  바뀐 것이 없다.\n"; exit 0 }
open(my $out, '>:raw', $f) or die "cannot write $f: $!\n";
print $out $d; close $out;
printf "  ✅ 표시 패치 완료 — %d → %d bytes (%+d)\n", $before, length($d), length($d)-$before;
