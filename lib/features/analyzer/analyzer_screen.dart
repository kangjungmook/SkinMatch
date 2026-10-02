import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../data/product_repository.dart';
import '../../models/routine_result.dart';
import '../../providers/core_providers.dart';
import '../../providers/routine_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/vanity_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dashed_border.dart';
import '../auth/skin_options.dart';
import 'result_view.dart';
import 'widgets/routine_step_card.dart';

class AnalyzerScreen extends ConsumerStatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  ConsumerState<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends ConsumerState<AnalyzerScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 입력 → 분석 중 → 결과로 바뀔 때마다 맨 위로 올려요.
    ref.listen(routineProvider.select((s) => (s.analyzing, s.result)), (prev, next) {
      if (prev != next && _scroll.hasClients) _scroll.jumpTo(0);
    });
    final s = ref.watch(routineProvider);
    final pad = MediaQuery.paddingOf(context);
    final Widget body;
    final EdgeInsets inner;
    if (s.analyzing) {
      body = const AnalyzingSkeleton();
      inner = const EdgeInsets.fromLTRB(20, 8, 20, 200);
    } else if (s.result != null) {
      body = ResultView(result: s.result!, runId: s.runId, alternative: s.alternative);
      inner = const EdgeInsets.fromLTRB(20, 4, 20, 210);
    } else {
      body = const _InputView();
      inner = const EdgeInsets.fromLTRB(20, 8, 20, 200);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: inner.copyWith(top: inner.top + pad.top, bottom: inner.bottom + pad.bottom),
            child: body,
          ),
        ),
        if (!s.analyzing && s.result == null) const _AnalyzeCta(),
        if (!s.analyzing && s.result != null) _ResultActions(saved: s.saved),
      ],
    );
  }
}

class _InputView extends ConsumerWidget {
  const _InputView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final name = session.user?.name ?? '';
    final initial = name.isEmpty ? '' : name.characters.first;
    final s = ref.watch(routineProvider);
    final recent = ref.watch(vanityProvider.select((v) => v.recent));
    final n = ref.read(routineProvider.notifier);
    final isMock = ref.watch(productRepositoryProvider) is MockProductRepository;

    return FadeIn(
      ms: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SkinMatchLogo(size: 32, eye: 6, smile: false),
              const SizedBox(width: 8),
              Text('SkinMatch', style: st(17, w: w700, ls: -0.03)),
              const Spacer(),
              Pressable(
                onTap: () => context.go(Routes.profile),
                semanticLabel: '마이페이지',
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: SM.line),
                  ),
                  child: Text(
                    initial,
                    style: st(14, w: w700, c: SM.primaryTx),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$name님, 오늘 바를 루틴의\n성분 궁합을 확인해 보세요 '),
                // ✦ 글리프는 Pretendard에 없어서 기기마다 다르게 보이지 않도록 벡터로 그려요.
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Sparkle(size: 19, color: SM.primary),
                  ),
                ),
              ],
            ),
            style: st(24, w: w700, ls: -0.035, h: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              scale: 1,
              onTap: () => context.go(Routes.profile),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(skinSummary(session.profile), style: st(13, c: SM.inkSub)),
                  ),
                  const SizedBox(width: 4),
                  const SmIcon(Ic.chevronRight, size: 14, color: SM.inkSub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (recent.isNotEmpty) ...[
            Text('최근 분석', style: st(14, w: w600)),
            const SizedBox(height: 10),
            Bleed(
              height: 74,
              child: HScroll(
                bottomPad: 4,
                children: [for (final r in recent.take(3)) _RecentCard(r, onTap: () => n.loadSnapshot(r.steps))],
              ),
            ),
            const SizedBox(height: 22),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('내 스킨케어 루틴', style: st(17, w: w700)),
              const SizedBox(width: 8),
              Text(
                '${s.steps.length}단계',
                style: st(13, w: w600, c: SM.primaryTx),
              ),
              const Spacer(),
              if (s.filled.isNotEmpty)
                Pressable(
                  scale: 1,
                  onTap: n.clearAll,
                  child: SizedBox(
                    height: 32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text('비우기', style: st(12.5, c: SM.inkSub)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              _SampleButton(onTap: n.sample),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // 네이버 검색 결과에는 전성분이 없어서, 서버를 쓸 때는 문구를 바꿔요.
            isMock ? '제품명만 검색하면 전성분을 자동으로 불러와요. 바르는 순서대로 쌓아 주세요.' : '제품을 검색해서 고르고 전성분을 넣어 주세요. 바르는 순서대로 쌓아 주세요.',
            style: st(13, c: SM.inkSub, h: 1.55),
          ),
          const SizedBox(height: 8),
          if (isMock) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Pill('목업 · 샘플 제품 20개로 검색돼요 (실제 DB 연동 예정)', bg: SM.warnBg, fg: SM.warnTx, height: 26, hPad: 10, size: 11.5),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 8),
          for (var i = 0; i < s.steps.length; i++)
            RoutineStepCard(key: ValueKey(s.steps[i].id), step: s.steps[i], index: i, count: s.steps.length),
          const AddStepRow(),
        ],
      ),
    );
  }
}

class _SampleButton extends StatefulWidget {
  const _SampleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SampleButton> createState() => _SampleButtonState();
}

class _SampleButtonState extends State<_SampleButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: DashedBorder(
        color: _h ? SM.primary : SM.slate300,
        radius: 16,
        width: 1,
        dash: 3,
        gap: 3,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
          child: Text(
            '+ 샘플 5단계 루틴',
            style: st(12.5, w: w500, c: _h ? SM.primaryTx : SM.ink600),
          ),
        ),
      ),
    ),
  );
}

class _RecentCard extends StatelessWidget {
  const _RecentCard(this.r, {required this.onTap});
  final SavedRoutine r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bd = BandStyle.of(r.band);
    String two(int v) => v.toString().padLeft(2, '0');
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SM.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bd.bg, borderRadius: BorderRadius.circular(15)),
              child: Text(
                '${r.risk}%',
                style: st(14, w: w700, c: bd.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${r.steps.length}단계 루틴 ',
                          style: st(13, w: w600),
                        ),
                        TextSpan(
                          text: '· ${two(r.at.hour)}:${two(r.at.minute)}',
                          style: st(13, w: w500, c: SM.inkFaint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.labels.join(' → '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: st(12, c: SM.inkSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 고정 CTA: "N개 제품 성분 충돌 & 자극 분석하기"
class _AnalyzeCta extends ConsumerWidget {
  const _AnalyzeCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filled = ref.watch(routineProvider.select((s) => s.filled.length));
    final ready = filled >= 2;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        _Fade(height: 200 + bottom, solid: .55),
        Positioned(
          left: 16,
          right: 16,
          bottom: 100 + bottom,
          child: Pressable(
            onTap: ref.read(routineProvider.notifier).analyze,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: SM.ease,
              height: 60,
              decoration: BoxDecoration(
                color: ready ? SM.ink : SM.line,
                borderRadius: BorderRadius.circular(20),
                boxShadow: ready
                    ? const [BoxShadow(color: Color(0x800F172A), offset: Offset(0, 16), blurRadius: 32, spreadRadius: -12)]
                    : const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SmIcon(Ic.zap, size: 19, stroke: false, fill: ready ? SM.primaryGlow : SM.inkFaint),
                  const SizedBox(width: 8),
                  Text(
                    ready ? '$filled개 제품 성분 충돌 & 자극 분석하기' : '제품을 2개 이상 입력해 주세요',
                    style: st(16.5, w: w700, c: ready ? Colors.white : SM.inkSub),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultActions extends ConsumerWidget {
  const _ResultActions({required this.saved});
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(routineProvider.notifier);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final fg = saved ? SM.primaryTx : Colors.white;
    return Stack(
      children: [
        _Fade(height: 230 + bottom, solid: .6),
        Positioned(
          left: 16,
          right: 16,
          bottom: 96 + bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Pressable(
                onTap: saved ? null : n.save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 58,
                  decoration: BoxDecoration(
                    color: saved ? SM.primaryBg : SM.ink,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x730F172A), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -12)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SmIcon(Ic.bookmark, size: 18, color: fg, fill: saved ? fg : null),
                      const SizedBox(width: 8),
                      Text(
                        saved ? '내 화장대에 저장됨' : '내 화장대에 이 루틴 저장하기',
                        style: st(16, w: w700, c: fg),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Pressable(
                scale: 1,
                onTap: n.backToInput,
                child: SizedBox(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SmIcon(Ic.refresh, size: 15, color: SM.ink600),
                      const SizedBox(width: 6),
                      Text(
                        '루틴 수정해서 다시 검사',
                        style: st(14, w: w600, c: SM.ink600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 아래쪽 흐려지는 배경 (linear-gradient(to top, #F8FAFC solid%, transparent))
class _Fade extends StatelessWidget {
  const _Fade({required this.height, required this.solid});
  final double height;
  final double solid;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: height,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: const [SM.bg, SM.bg, Color(0x00F8FAFC)],
            stops: [0, solid, 1],
          ),
        ),
      ),
    ),
  );
}
