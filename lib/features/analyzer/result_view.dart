import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analyzer_engine.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/routine_result.dart';
import '../../providers/core_providers.dart';
import '../../providers/routine_provider.dart';
import '../../widgets/common.dart';

const _levelText = ['자극 거의 없음', '가벼운 당김 가능성', '예민 부위 따끔거림 가능성', '따가움/붉은기 유발 가능성', '강한 자극 · 각질 손상 위험'];

/// 루틴 분석 결과 (게이지는 1.2초 동안 ease-out cubic으로 올라가요)
class ResultView extends ConsumerStatefulWidget {
  const ResultView({super.key, required this.result, required this.runId, this.alternative});

  final RoutineResult result;
  final int runId;
  final AlternativeSuggestion? alternative;

  @override
  ConsumerState<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<ResultView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  @override
  void didUpdateWidget(ResultView old) {
    super.didUpdateWidget(old);
    if (old.runId != widget.runId) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final r = widget.result;
    final txt =
        '[SkinMatch 루틴 분석] 충돌 위험도 ${r.risk}% · ${BandStyle.of(r.band).label}\n'
        '${r.products.map((p) => '${p.n}. ${p.label}').join('\n')}\n💡 ${r.tip}';
    try {
      await SharePlus.instance.share(ShareParams(text: txt, title: 'SkinMatch 분석 결과'));
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: txt));
        ref.read(toastProvider.notifier).show('결과 요약을 복사했어요');
      } catch (_) {
        ref.read(toastProvider.notifier).show('공유를 지원하지 않는 환경이에요');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final bd = BandStyle.of(r.band);
    final n = ref.read(routineProvider.notifier);
    final alt = widget.alternative;
    return FadeIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SquareBtn(icon: Ic.chevronLeft, iconSize: 20, label: '뒤로', onTap: n.backToInput),
              Expanded(
                child: Text(
                  '루틴 분석 결과',
                  textAlign: TextAlign.center,
                  style: st(16, w: w700),
                ),
              ),
              _SquareBtn(icon: Ic.share, iconSize: 18, stroke: 1.9, label: '결과 공유', onTap: _share),
            ],
          ),
          const SizedBox(height: 14),
          Bleed(
            height: 38,
            child: HScroll(
              gap: 6,
              children: [
                for (final p in r.products)
                  Container(
                    height: 38,
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.only(left: 6, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SM.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NumDot(p.n, size: 26, font: 11.5),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            p.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: st(12.5, w: w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (r.warning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: SM.warnBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SM.warnLine),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: SmIcon(Ic.warning, size: 18, color: SM.warnInk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.warning, style: st(13.5, c: SM.warnInk, h: 1.5)),
                  ),
                ],
              ),
            ),
          ],
          ..._inputNotice(),
          const SizedBox(height: 12),
          _gaugeCard(r, bd),
          const SizedBox(height: 12),
          _levelCard(r, bd),
          const SizedBox(height: 12),
          _matrixCard(r),
          if (alt != null) ...[const SizedBox(height: 12), _altCard(alt)],
          const SizedBox(height: 12),
          SmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('핵심 성분 충돌 태그', style: st(15, w: w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final t in r.tags)
                      () {
                        final (bg, fg) = switch (t.kind) {
                          TagKind.clash => (SM.dangerBg, SM.dangerTx),
                          TagKind.caution => (SM.warnBg, SM.warnTx),
                          TagKind.good => (SM.primaryBg, SM.primaryTx),
                        };
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            t.text,
                            style: st(13, w: w600, c: fg),
                          ),
                        );
                      }(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _morningCard(r),
          const SizedBox(height: 12),
          _nightCard(r),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SM.primaryBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: SM.primaryLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: SM.primary, borderRadius: BorderRadius.circular(12)),
                  child: const SmIcon(Ic.bulb, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rule of Thumb',
                        style: st(12, w: w700, c: SM.primaryTx),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.tip,
                        style: st(14.5, w: w600, c: SM.primaryInk, h: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (r.reordered) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('입력한 순서와 달리, 묽은 제형 → 꾸덕한 제형 → 선크림 기준의 권장 순서로 정리했어요.', style: st(12, c: SM.inkSub, h: 1.6)),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('본 결과는 성분 정보 기반의 참고용 가이드이며, 의학적 진단을 대체하지 않습니다.', style: st(11.5, c: SM.inkFaint, h: 1.6)),
          ),
        ],
      ),
    );
  }

  /// 주요 성분만 넣은 제품(간단 분석)과 전성분이 없어 빠진 제품을 알려 줘요.
  List<Widget> _inputNotice() {
    final steps = ref.watch(routineProvider.select((s) => s.steps));
    final quick = steps.where((s) => s.quick && s.isFilled).length;
    final skipped = steps.where((s) => s.product != null && !s.product!.hasIngredients && !s.isFilled).length;
    if (quick == 0 && skipped == 0) return const [];
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: SM.slate100, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SmIcon(Ic.info, size: 16, color: SM.ink600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (quick > 0) Text('주요 성분만 넣은 제품 $quick개는 간단 분석이에요. 전성분을 넣으면 더 정확해져요.', style: st(13, c: SM.ink600, h: 1.5)),
                  if (quick > 0 && skipped > 0) const SizedBox(height: 4),
                  if (skipped > 0) Text('전성분을 넣지 않은 제품 $skipped개는 분석에서 빠졌어요.', style: st(13, c: SM.ink600, h: 1.5)),
                  const SizedBox(height: 8),
                  Pressable(
                    onTap: ref.read(routineProvider.notifier).backToInput,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: SM.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SmIcon(Ic.camera, size: 14, color: SM.ink700, strokeWidth: 2),
                          const SizedBox(width: 6),
                          Text(
                            '전성분 넣고 자세히 분석하기',
                            style: st(13, w: w600, c: SM.ink700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _gaugeCard(RoutineResult r, BandStyle bd) => SmCard(
    radius: 28,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('루틴 전체 충돌 위험도', style: st(15, w: w600)),
            ),
            const SizedBox(width: 8),
            Text('${r.products.length}개 제품 · ${r.pairs.length}개 조합', style: st(12, c: SM.inkSub)),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final pct = r.risk * Curves.easeOutCubic.transform(_c.value);
            return SizedBox(
              width: 240,
              height: 138,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _GaugePainter(pct / 100, bd.color))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${pct.round()}', style: st(52, w: w700, ls: -0.05, h: 1, tabular: true)),
                        const SizedBox(width: 2),
                        Text(
                          '%',
                          style: st(22, w: w600, c: SM.inkSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: st(11, c: SM.inkFaint)),
                Text('100', style: st(11, c: SM.inkFaint)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: bd.bg, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: bd.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  bd.label,
                  textAlign: TextAlign.center,
                  style: st(13.5, w: w600, c: bd.text, h: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (r.adjustments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SmIcon(Ic.shieldCheck, size: 13, color: SM.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '내 피부 프로필 반영 · ${r.adjustments.join(' · ')}',
                  textAlign: TextAlign.center,
                  style: st(12, c: SM.inkSub),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _levelCard(RoutineResult r, BandStyle bd) => SmCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text('자극 지수', style: st(15, w: w600)),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Level ${r.level} ',
                    style: st(14, w: w700, c: bd.text),
                  ),
                  TextSpan(
                    text: '/ 5',
                    style: st(14, w: w500, c: SM.inkFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final pct = r.risk * Curves.easeOutCubic.transform(_c.value);
            final live = math.min(r.level, (pct / 20).ceil());
            return Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 10,
                      decoration: BoxDecoration(color: i < live ? bd.color : SM.muted, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(_levelText[r.level - 1], style: st(13.5, c: SM.ink600)),
      ],
    ),
  );

  Widget _matrixCard(RoutineResult r) {
    final nP = r.products.length;
    String short(String l) => l.length > 14 ? '${l.substring(0, 13)}…' : l;
    final rows = r.sorted.where((q) => q.risk > 30 || q.hits.isNotEmpty).toList();
    return SmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('제품별 충돌 맵', style: st(15, w: w600)),
              ),
              Text('숫자 = 루틴 순서', style: st(12, c: SM.inkSub)),
            ],
          ),
          const SizedBox(height: 4),
          Text('모든 제품을 1:1로 비교한 충돌 위험도(%)예요', style: st(12.5, c: SM.inkSub)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cell = (c.maxWidth - 22 - 4 * nP) / nP;
              final h = math.min(cell, 48.0);
              Widget box(String t, Color bg, Color fg, double w) => Container(
                width: w,
                height: h,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  t,
                  style: st(12, w: w700, c: fg, tabular: true),
                ),
              );
              Widget row(List<Widget> cells) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 4), cells[i]],
                  ],
                ),
              );
              return Column(
                children: [
                  row([
                    box('', Colors.transparent, SM.inkSub, 22),
                    for (final p in r.products) box('${p.n}', Colors.transparent, SM.inkSub, cell),
                  ]),
                  for (var i = 0; i < nP; i++)
                    row([
                      box('${i + 1}', Colors.transparent, SM.inkSub, 22),
                      for (var j = 0; j < nP; j++)
                        if (i == j)
                          box('', SM.slate100, SM.inkFaint, cell)
                        else
                          () {
                            final q = r.pairOf(i, j);
                            final (bg, fg) = BandStyle.cell(bandOf(q.risk));
                            return box('${q.risk}', bg, fg, cell);
                          }(),
                    ]),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [_legend(SM.primarySoft, '안심 0~30'), _legend(SM.warnLine, '시간차 31~70'), _legend(SM.dangerLine, '비추천 71~')],
          ),
          const SizedBox(height: 16),
          for (final q in rows)
            () {
              final (bg, fg) = BandStyle.cell(bandOf(q.risk));
              final tags = <String>{for (final h in q.hits) ...h.tags}.join(' ');
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: SM.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _NumDot(q.i + 1, size: 22, font: 11),
                        const SizedBox(width: 3),
                        _NumDot(q.j + 1, size: 22, font: 11),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${short(r.products[q.i].label)} × ${short(r.products[q.j].label)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: st(13, w: w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pill('${q.risk}%', bg: bg, fg: fg, height: 24, hPad: 9, size: 12, weight: w700),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Text(tags.isEmpty ? '액티브 성분 중첩 — 시간차 사용 권장' : tags, style: st(12, c: fg, h: 1.5)),
                    ),
                  ],
                ),
              );
            }(),
          if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SM.border)),
              ),
              child: Text(
                '충돌 위험이 있는 조합이 없어요',
                style: st(13, w: w600, c: SM.primaryTx),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(t, style: st(11.5, c: SM.inkSub)),
    ],
  );

  Widget _altCard(AlternativeSuggestion alt) => SmCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Pill('대체 추천', bg: SM.primaryBg, fg: SM.primaryTx, size: 11, weight: w700),
            const SizedBox(width: 8),
            Expanded(
              child: Text('더 순한 조합으로 바꿔 보세요', style: st(15, w: w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(alt.title, style: st(12.5, c: SM.inkSub, h: 1.5)),
        const SizedBox(height: 12),
        for (var i = 0; i < alt.items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SM.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SM.border),
            ),
            child: Row(
              children: [
                StripeBox(tint: SM.tint(alt.items[i].product.category), stripe: 5, width: 40, height: 40, radius: 12, base: SM.bg),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alt.items[i].product.brand, style: st(11.5, c: SM.inkSub)),
                      Text(
                        alt.items[i].product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: st(13.5, w: w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '교체 시 최대 충돌 ${alt.items[i].worst}%',
                        style: st(11.5, w: w600, c: SM.primaryTx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Pressable(
                  onTap: () => ref.read(routineProvider.notifier).swap(alt.stepId, alt.items[i].product),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: SM.ink, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '교체하기',
                      style: st(12.5, w: w600, c: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _routineHeader({
    required String eyebrow,
    required String title,
    required Widget icon,
    required Color iconBg,
    required bool dark,
    Widget? trailing,
  }) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: icon,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: st(12, w: w600, c: dark ? SM.slate300 : SM.inkSub),
            ),
            Text(
              title,
              style: st(15, w: w700, c: dark ? Colors.white : SM.ink),
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );

  Widget _routineRow({
    required String step,
    required String label,
    required String cat,
    required Color labelColor,
    required Color stepColor,
    required Color catBg,
    required Color catFg,
    required Color divider,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: divider)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            step,
            textAlign: TextAlign.center,
            style: st(12, w: w700, c: stepColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: st(14, w: w600, c: labelColor),
          ),
        ),
        const SizedBox(width: 10),
        Pill(cat, bg: catBg, fg: catFg),
      ],
    ),
  );

  Widget _morningCard(RoutineResult r) => SmCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _routineHeader(
          eyebrow: 'Morning Routine',
          title: '아침 권장 순서',
          icon: const SmIcon(Ic.sun, size: 19, color: SM.warnDeep, strokeWidth: 1.9),
          iconBg: SM.warnBg,
          dark: false,
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < r.morning.length; i++)
          () {
            final p = r.morning[i];
            return _routineRow(
              step: p.ghost ? '+' : '${i + 1}',
              label: p.label,
              cat: p.category,
              labelColor: p.ghost ? SM.warnTx : SM.ink,
              stepColor: SM.inkFaint,
              catBg: p.ghost ? SM.warnBg : SM.slate100,
              catFg: p.ghost ? SM.warnTx : SM.ink600,
              divider: SM.border,
            );
          }(),
      ],
    ),
  );

  Widget _nightCard(RoutineResult r) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(color: SM.ink, borderRadius: BorderRadius.circular(26)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _routineHeader(
          eyebrow: 'Night Routine',
          title: '저녁 권장 순서',
          icon: const SmIcon(Ic.moon, size: 18, color: Colors.white, strokeWidth: 1.9),
          iconBg: const Color(0x1AFFFFFF),
          dark: true,
          trailing: r.split ? const Pill('격일 분리', bg: SM.dangerBg, fg: SM.dangerTx, height: 26, hPad: 10, size: 11.5, weight: w700) : null,
        ),
        const SizedBox(height: 6),
        for (final g in r.night) ...[
          const SizedBox(height: 10),
          Text(
            g.title,
            style: st(12, w: w700, c: SM.primaryMint),
          ),
          const SizedBox(height: 2),
          for (var i = 0; i < g.items.length; i++)
            _routineRow(
              step: '${i + 1}',
              label: g.items[i].label,
              cat: g.items[i].category,
              labelColor: Colors.white,
              stepColor: SM.inkSub,
              catBg: const Color(0x1AFFFFFF),
              catFg: SM.ink200,
              divider: const Color(0x14FFFFFF),
            ),
        ],
      ],
    ),
  );
}

/// 반원 게이지 (SVG viewBox 220×126을 240×138로 그린 것과 같아요)
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.color);
  final double f;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 220;
    canvas.scale(s);
    final rect = Rect.fromCircle(center: const Offset(110, 110), radius: 90);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = SM.slate100;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    if (f > 0) canvas.drawArc(rect, math.pi, math.pi * f, false, base..color = color);
    final tick = Paint()
      ..color = SM.slate300
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(82.2, 24.4), const Offset(84.6, 31.9), tick);
    canvas.drawLine(const Offset(137.8, 24.4), const Offset(135.4, 31.9), tick);
    final ang = math.pi - math.pi * f;
    final knob = Offset(110 + 90 * math.cos(ang), 110 - 90 * math.sin(ang));
    canvas.drawCircle(knob, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.f != f || o.color != color;
}

class _NumDot extends StatelessWidget {
  const _NumDot(this.n, {required this.size, required this.font});
  final int n;
  final double size;
  final double font;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: SM.ink, shape: BoxShape.circle),
    child: Text(
      '$n',
      style: st(font, w: w700, c: Colors.white),
    ),
  );
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.icon, required this.label, required this.onTap, this.iconSize = 20, this.stroke = 2});
  final String icon;
  final String label;
  final VoidCallback onTap;
  final double iconSize;
  final double stroke;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SM.border),
      ),
      child: SmIcon(icon, size: iconSize, strokeWidth: stroke),
    ),
  );
}

/// 분석 중 스켈레톤 (400ms)
class AnalyzingSkeleton extends StatelessWidget {
  const AnalyzingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: .4, child: Shimmer(height: 22, radius: 8)),
      const SizedBox(height: 12),
      const Shimmer(height: 260, radius: 26),
      const SizedBox(height: 12),
      const Shimmer(height: 96, radius: 26),
      const SizedBox(height: 12),
      const Row(
        children: [
          Expanded(child: Shimmer(height: 140, radius: 24)),
          SizedBox(width: 12),
          Expanded(child: Shimmer(height: 140, radius: 24)),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '성분 조합을 분석하고 있어요…',
        textAlign: TextAlign.center,
        style: st(13, c: SM.inkSub),
      ),
    ],
  );
}
