import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/skin_profile.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/dashed_border.dart';
import 'skin_options.dart';

/// 피부 진단 3단계: 기본 타입 → 고민·민감도 → 사용 경험·주의 사항
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _scroll = ScrollController();
  int _step = 0;
  bool _quizOpen = false;
  int? _quizAns;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _set(SkinProfile p) => ref.read(sessionProvider.notifier).setProfile(p);

  void _go(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<String> _toggle(List<String> list, String v) => list.contains(v) ? list.where((x) => x != v).toList() : [...list, v];

  void _next(bool can) {
    if (!can) return ref.read(toastProvider.notifier).show(_step == 0 ? '기본 피부 타입을 선택해 주세요' : '자극 민감도를 선택해 주세요');
    if (_step < 2) return _go(_step + 1);
    ref.read(sessionProvider.notifier).finishOnboarding();
    ref.read(toastProvider.notifier).show('피부 프로필이 저장됐어요');
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(sessionProvider.select((s) => s.profile));
    final can = _step == 0 ? p.baseType != null : (_step == 1 ? p.sensitivity > 0 : true);
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: SM.bg,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top),
        child: FadeIn(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(
                  children: [
                    Pressable(
                      onTap: _step > 0 ? () => _go(_step - 1) : null,
                      scale: 1,
                      semanticLabel: '이전',
                      child: Opacity(
                        opacity: _step > 0 ? 1 : .35,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SM.border),
                          ),
                          alignment: Alignment.center,
                          child: const SmIcon(Ic.chevronLeft, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                height: 4,
                                decoration: BoxDecoration(color: i <= _step ? SM.primary : SM.line, borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_step + 1} / 3',
                        textAlign: TextAlign.right,
                        style: st(13, c: SM.inkSub, tabular: true),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  child: FadeIn(key: ValueKey(_step), ms: 400, child: [_step0(p), _step1(p), _step2(p)][_step]),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + pad.bottom),
                decoration: const BoxDecoration(
                  color: SM.bg,
                  border: Border(top: BorderSide(color: SM.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Pressable(
                      onTap: () => _next(can),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: can ? SM.ink : SM.line, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          _step < 2 ? '다음' : '피부 프로필 저장하고 시작하기',
                          style: st(16, w: w700, c: can ? Colors.white : SM.inkSub),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Pressable(
                      onTap: () => ref.read(sessionProvider.notifier).finishOnboarding(),
                      scale: 1,
                      child: SizedBox(
                        height: 38,
                        child: Center(
                          child: Text('나중에 설정할게요', style: st(13.5, c: SM.inkSub)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String eyebrow, String title, String desc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: st(12.5, w: w700, c: SM.primaryTx, ls: 0.02),
      ),
      const SizedBox(height: 8),
      Text(title, style: st(24, w: w700, ls: -0.035, h: 1.38)),
      const SizedBox(height: 8),
      Text(desc, style: st(14, c: SM.inkSub, h: 1.6)),
      const SizedBox(height: 20),
    ],
  );

  Widget _radioRow({required String label, required String desc, required bool on, required VoidCallback onTap, bool dashed = false}) {
    final border = on ? SM.primary : (dashed ? SM.slate300 : SM.border);
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: SM.ease,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: on ? SM.primaryBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: dashed ? null : Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: on ? SM.primary : SM.slate300, width: 2),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? SM.primary : Colors.transparent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: st(15.5, w: w600)),
                const SizedBox(height: 3),
                Text(desc, style: st(13, c: SM.inkSub, h: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      selected: on,
      child: Pressable(
        onTap: onTap,
        child: dashed ? DashedBorder(color: border, radius: 20, child: body) : body,
      ),
    );
  }

  Widget _step0(SkinProfile p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SM.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SmIcon(Ic.shieldCheck, size: 14, color: SM.primary),
            const SizedBox(width: 6),
            Text(
              'Baumann 피부 타입 분류 기준 참고 · 약 1분',
              style: st(12, w: w600, c: SM.ink700),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _heading('STEP 1 · 기본 피부 타입', '평소 피부 타입을 알려주세요', '세안 후 30분 동안 아무것도 바르지 않았을 때를 기준으로 골라주세요.'),
      for (final b in kBaseTypes) ...[
        _radioRow(
          label: b.key,
          desc: b.desc,
          on: p.baseType == b.key,
          onTap: () {
            setState(() {
              _quizOpen = false;
              _quizAns = null;
            });
            _set(p.copyWith(baseType: b.key));
          },
        ),
        const SizedBox(height: 8),
      ],
      _radioRow(
        label: '잘 모르겠어요',
        desc: '질문 하나로 간단히 추정해 드려요',
        on: _quizOpen,
        dashed: true,
        onTap: () {
          setState(() {
            _quizOpen = true;
            _quizAns = null;
          });
          _set(p.copyWith(clearBaseType: true));
        },
      ),
      if (_quizOpen) ...[
        const SizedBox(height: 10),
        FadeIn(
          ms: 350,
          child: _WhiteCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('세안 후 30분, 아무것도 바르지 않았을 때 피부는?', style: st(14.5, w: w600, h: 1.5)),
                const SizedBox(height: 12),
                EqualGrid(
                  cols: 2,
                  gap: 8,
                  children: [
                    for (var i = 0; i < kQuiz.length; i++)
                      Pressable(
                        onTap: () {
                          setState(() => _quizAns = i);
                          _set(p.copyWith(baseType: kQuiz[i].type));
                        },
                        scale: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _quizAns == i ? SM.ink : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _quizAns == i ? SM.ink : SM.line),
                          ),
                          child: Text(
                            kQuiz[i].text,
                            textAlign: TextAlign.center,
                            style: st(13.5, w: w600, c: _quizAns == i ? Colors.white : SM.ink700, h: 1.35),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_quizAns != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '→ ‘${p.baseType}’ 피부로 추정돼요. 위 목록에 반영했어요.',
                    style: st(13, w: w600, c: SM.primaryTx),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: SM.slate100, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SmIcon(Ic.info, size: 15, color: SM.ink600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('같은 성분이라도 피부 타입에 따라 자극 정도가 달라요. 선택한 정보는 충돌 위험도를 보정하는 데 사용돼요.', style: st(12.5, c: SM.ink600, h: 1.6)),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _step1(SkinProfile p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('STEP 2 · 피부 고민 & 민감도', '해당하는 피부 고민을 모두 골라주세요', '없다면 선택하지 않고 넘어가도 괜찮아요.'),
      EqualGrid(
        cols: 2,
        gap: 8,
        children: [
          for (final c in kConcerns)
            () {
              final on = p.concerns.contains(c.key);
              return Semantics(
                selected: on,
                child: Pressable(
                  scale: .97,
                  onTap: () => _set(p.copyWith(concerns: _toggle(p.concerns, c.key))),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: SM.ease,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
                    decoration: BoxDecoration(
                      color: on ? SM.primaryBg : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: on ? SM.primary : SM.line, width: 1.5),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: Text(c.key, style: st(14.5, w: w600)),
                            ),
                            const SizedBox(height: 4),
                            Text(c.desc, style: st(12, c: SM.inkSub, h: 1.45)),
                          ],
                        ),
                        Positioned(top: -2, right: -2, child: _CheckDot(on: on, radius: 10, size: 20)),
                      ],
                    ),
                  ),
                ),
              );
            }(),
        ],
      ),
      const SizedBox(height: 14),
      _WhiteCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('새 제품을 쓸 때 자극을 얼마나 자주 느끼나요?', style: st(15, w: w600, h: 1.45)),
            const SizedBox(height: 4),
            Text('따가움, 붉어짐, 가려움 모두 포함해요', style: st(12.5, c: SM.inkSub)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < kSensitivity.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Pressable(
                      scale: 1,
                      onTap: () => _set(p.copyWith(sensitivity: i + 1)),
                      child: () {
                        final on = p.sensitivity == i + 1;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 64,
                          decoration: BoxDecoration(
                            color: on ? SM.ink : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: on ? SM.ink : SM.line),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${i + 1}',
                                style: st(17, w: w700, c: on ? Colors.white : SM.ink),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                kSensitivity[i].label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: st(10.5, w: w500, c: on ? SM.slate300 : SM.inkSub),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              p.sensitivity > 0 ? kSensitivity[p.sensitivity - 1].desc : '1(거의 없음)부터 5(거의 항상)까지 골라주세요.',
              style: st(13, c: SM.ink600, h: 1.5),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _step2(SkinProfile p) {
    final rows = profileRows(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('STEP 3 · 사용 경험 & 주의 사항', '안전한 분석을 위해\n몇 가지만 더 확인할게요', '해당하는 항목만 체크해 주세요.'),
        for (final h in kHistory) ...[
          () {
            final on = p.history.contains(h.key);
            return Semantics(
              checked: on,
              child: Pressable(
                scale: 1,
                onTap: () => _set(p.copyWith(history: _toggle(p.history, h.key))),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: on ? SM.primaryBg : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: on ? SM.primary : SM.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      _CheckDot(on: on, radius: 7, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(h.text, style: st(14.5, w: w500, h: 1.45)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 2),
        _WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('임산부/수유부 주의 성분 알림', style: st(14.5, w: w600)),
                    const SizedBox(height: 3),
                    Text('레티노이드, 고농도 살리실산 감지 시 알려드려요', style: st(12.5, c: SM.inkSub, h: 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SmToggle(
                value: p.pregnancyAlert,
                label: '임산부 알림',
                onChanged: (v) => _set(p.copyWith(pregnancyAlert: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: SM.ink, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SmIcon(Ic.shieldCheck, size: 16, color: SM.primaryGlow),
                  const SizedBox(width: 8),
                  Text(
                    '내 피부 프로필',
                    style: st(14, w: w700, c: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final r in rows) KvRow(r.$1, r.$2, keyColor: SM.slate300, valueColor: Colors.white, divider: const Color(0x1AFFFFFF)),
              const SizedBox(height: 12),
              Text(adjustPreview(p), style: st(12.5, c: SM.primarySoft, h: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SmIcon(Ic.lock, size: 14, color: SM.inkSub),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '피부 정보는 분석 보정에만 사용되며 마이페이지에서 언제든 수정·삭제할 수 있어요. 결과는 참고용이며 의학적 진단을 대체하지 않아요.',
                  style: st(12, c: SM.inkSub, h: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SM.border),
      boxShadow: const [BoxShadow(color: Color(0x2E0F172A), offset: Offset(0, 10), blurRadius: 30, spreadRadius: -20)],
    ),
    child: child,
  );
}

/// 체크 표시 (원형 radius 10 / 네모 radius 7)
class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.on, required this.radius, required this.size});
  final bool on;
  final double radius;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: on ? SM.primary : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: on ? SM.primary : SM.slate300, width: 1.5),
    ),
    alignment: Alignment.center,
    child: const SmIcon(Ic.check, size: 12, color: Colors.white, strokeWidth: 3),
  );
}
