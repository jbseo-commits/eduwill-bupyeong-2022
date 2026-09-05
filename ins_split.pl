#!/usr/bin/env perl
# 해설집 — 지시문 오염 «표시» 완화 + 오염 현황 보고
#
# 무엇을 고치나: 원본(exam-qa)의 지시문 추출기가 지시문 뒤에 이어지는 텍스트를 끊지 못해,
#   앞 지문의 꼬리와 남의 선지가 i(지시문) 필드에 딸려 들어온 문항이 있다.
#   화면에서 지시문 한 줄로 이어져 나와 «다른 문제의 지문»처럼 읽힌다(2026-09-05 제보).
#
# 왜 지우지 않나: 15군데 중 7군데는 그 텍스트가 문서 안에서 «여기에만» 있다(실측).
#   지우면 내용이 사라진다. 그래서 데이터는 그대로 두고 «화면에서만» 두 블록으로 가른다.
#
# 진짜 수정은 exam-qa 의 추출기다. 거기가 고쳐지면 이 패치는 아무 일도 하지 않는다
#   (플래그가 선 문항이 없으면 insBlocks 는 종전과 똑같이 한 블록만 그린다).
#
# 멱등이다. 줄바꿈(LF/CRLF)에 의존하지 않는다.
use strict; use warnings; use utf8;
use Encode qw(decode_utf8 encode_utf8);
binmode(STDOUT, ':encoding(UTF-8)');

my $f = shift or die "usage: ins_split.pl <index.html>\n";
open(my $in, '<:raw', $f) or die "cannot open $f: $!\n";
local $/; my $d = <$in>; close $in;
my $before = length $d;

# ── 1. 현황 보고 (패치 여부와 무관하게 «항상» 찍는다) ──────────────
my $h = decode_utf8($d);
my $beg = index($h, '[{"s":"');
my %flag; my $items = 0; my $flagged = 0;
if ($beg >= 0) {
  my $fin = index($h, '</script>', $beg);
  my $arr = substr($h, $beg, $fin - $beg);
  my @st; my $pos = 0;
  while (($pos = index($arr, '{"s":"', $pos)) >= 0) { push @st, $pos; $pos += 6 }
  my %seen;
  for my $k (0 .. $#st) {
    my $rec = substr($arr, $st[$k], ($k < $#st ? $st[$k+1]-$st[$k] : length($arr)-$st[$k]));
    my ($s) = $rec =~ /^\{"s":"([^"]*)"/;
    my $ia = index($rec, '"i":"'); my $iz = index($rec, '","q":"', $ia);
    next if $ia < 0 || $iz < 0;
    my $i = substr($rec, $ia+5, $iz-$ia-5);
    $items++;
    my $circ = () = $i =~ /[\x{2460}-\x{2473}]/g;
    next unless (length($i) > 120 || $circ >= 2);
    $flagged++;
    $flag{$s}{n}++;
    $flag{$s}{sites}{$i} = 1;
  }
}
my $sites = 0; $sites += scalar(keys %{$flag{$_}{sites}}) for keys %flag;
printf "  지시문 점검: 문항 %d개 중 오염 의심 %d개 · %d군데 · %d개 시험지\n",
  $items, $flagged, $sites, scalar(keys %flag);
if (%flag) {
  for my $s (sort { $flag{$b}{n} <=> $flag{$a}{n} } keys %flag) {
    printf "      %-28s %2d문항 / %d군데\n", $s, $flag{$s}{n}, scalar(keys %{$flag{$s}{sites}});
  }
  print "      (원본 exam-qa 의 지시문 추출기 문제다. 화면에서는 아래 패치가 갈라 준다.)\n";
}

# ── 2. 패치 ────────────────────────────────────────────────────
if (index($d, 'function insBlocks(') >= 0) {
  # v1 -> v2 승급 — v1 은 딸려온 텍스트를 «별도 블록으로 보여줬다».
  # 학생이 돈 내고 보는 화면에 «남의 문제 지문»이 남는다는 지적(2026-09-06)에 따라 아예 안 그린다.
  # 데이터는 그대로다 — 파일 안에 남아 있고, 위 현황 출력이 계속 개수를 알려 준다.
  my $v1 = q{"</div>"     + "<div class=" + Q + "ins insx" + Q + ">" + esc(rest) + "</div>";};
  my $v2 = q{"</div>";};
  my $c = () = $d =~ /\Q$v1\E/g;
  if ($c == 1) {
    $d =~ s/\Q$v1\E/$v2/;
    open(my $o, ">:raw", $f) or die $!; print $o $d; close $o;
    print "  ✅ 표시 패치 v1 → v2 승급 (딸려온 텍스트를 화면에 그리지 않는다)\n";
  } else {
    print "  ℹ️  표시 패치(v2)는 이미 적용돼 있다.\n";
  }
  exit 0;
}

my $FN = encode_utf8(join(qq{},
  '/* 지시문 오염 «표시» 완화 (2026-09-05) — 데이터는 그대로 두고 화면에서만 가른다.',
  '   원본(exam-qa) 추출기가 지시문 뒤 텍스트를 못 끊어 앞 지문 꼬리·남의 선지가 i 에 딸려 온다.',
  '   지우지 않는 이유: 15군데 중 7군데는 그 텍스트가 문서에서 «여기에만» 있다(실측).',
  '   플래그(120자 초과 또는 선지기호 2개 이상)가 선 것만 가른다 — 정상 지시문은 손대지 않는다. */',
  'function insBlocks(t){',
  'if(!t) return "";',
  'var circ=0, z;',
  'for(z=0; z<t.length; z++){ var cc=t.charCodeAt(z); if(cc>=9312 && cc<=9331) circ++; }',
  'if(t.length<=120 && circ<2) return "<div class=" + String.fromCharCode(34) + "ins" + String.fromCharCode(34) + ">" + esc(t) + "</div>";',
  'var cut=-1;',
  'for(z=0; z<t.length; z++){ var ch=t.charAt(z); if(ch==="." || ch==="?" || ch==="!"){ cut=z; break; } }',
  'var Q=String.fromCharCode(34);',
  'if(cut<0) return "<div class=" + Q + "ins" + Q + ">" + esc(t) + "</div>";',
  'var head=t.slice(0,cut+1), rest=t.slice(cut+1);',
  'while(rest.charAt(0)===" ") rest=rest.slice(1);',
  'if(!rest) return "<div class=" + Q + "ins" + Q + ">" + esc(t) + "</div>";',
  q{return "<div class=" + Q + "ins" + Q + ">" + esc(head) + "</div>";},
  '}',
));

my @P = (
  ['function card(x){',            $FN . 'function card(x){'],
  ['${x.i?`<div class="ins">${esc(x.i)}</div>`:' . "''" . '}',  '${insBlocks(x.i)}'],
  ['.ins{font-size:var(--fs-sm);color:var(--mut);margin-bottom:var(--sp-2);overflow-wrap:anywhere}',
   '.ins{font-size:var(--fs-sm);color:var(--mut);margin-bottom:var(--sp-2);overflow-wrap:anywhere}'
   . '.insx{border-left:3px solid var(--mut);padding-left:8px;margin-top:4px;opacity:.9}'],
);

my $n = 0;
for my $p (@P) {
  $n++;
  my $c = () = $d =~ /\Q$p->[0]\E/g;
  die "  🔴 ${n}번 패치 대상이 ${c}곳이다(1이어야 한다). 원본이 바뀌었다 — 아무것도 쓰지 않고 중단한다.\n"
    if $c != 1;
}
$n = 0;
for my $p (@P) { $d =~ s/\Q$p->[0]\E/$p->[1]/; $n++; printf "  ✅ %d/%d 적용\n", $n, scalar(@P); }

open(my $out, '>:raw', $f) or die "cannot write $f: $!\n";
print $out $d; close $out;
printf "  ✅ 표시 패치 완료 — %d → %d bytes (+%d)\n", $before, length($d), length($d)-$before;
