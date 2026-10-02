import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/ingredient_db.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../providers/routine_provider.dart';
import '../../widgets/common.dart';
import 'label_scan.dart';
import 'sheets.dart';

/// 전성분을 넣는 방법: 사진 / 주요 성분만 / 직접 입력.
/// [base]는 검색으로 고른 제품(전성분 없음)이에요. 있으면 이름을 이어서 써요.
Future<void> showInputMethodSheet(
  BuildContext context,
  WidgetRef ref, {
  required String stepId,
  required String category,
  Product? base,
}) async {
  final choice = await showSmSheet<String>(context, (ctx) => _MethodSheet(base: base));
  if (choice == null || !context.mounted) return;
  await runInputMethod(context, ref, choice, stepId: stepId, category: category, base: base);
}

/// 'photo' | 'quick' | 'manual'
Future<void> runInputMethod(
  BuildContext context,
  WidgetRef ref,
  String method, {
  required String stepId,
  required String category,
  Product? base,
}) async {
  switch (method) {
    case 'photo':
      await startLabelScan(context, ref, stepId: stepId, category: category, base: base);
    case 'quick':
      await showQuickPickSheet(context, ref, stepId: stepId, category: base?.category ?? category, base: base);
    case 'manual':
      final n = ref.read(routineProvider.notifier);
      base == null ? n.manualMode(stepId) : n.manualFor(stepId, '${base.brand} ${base.name}');
  }
}

class _MethodSheet extends StatelessWidget {
  const _MethodSheet({this.base});
  final Product? base;

  @override
  Widget build(BuildContext context) {
    Widget option(String key, String icon, String title, String sub, {String? badge}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: () => Navigator.of(context).pop(key),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SM.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: SM.primaryBg, borderRadius: BorderRadius.circular(14)),
                child: SmIcon(icon, size: 20, color: SM.primaryTx, strokeWidth: 1.9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title, style: st(15, w: w600)),
                        ),
                        if (badge != null) ...[const SizedBox(width: 6), Pill(badge, bg: SM.primaryBg, fg: SM.primaryTx)],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(sub, style: st(12.5, c: SM.inkSub, h: 1.45)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SmIcon(Ic.chevronRight, size: 16, color: SM.inkFaint),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle(base == null ? '어떻게 넣을까요?' : '전성분을 어떻게 넣을까요?'),
        Text(
          base == null ? '검색되지 않는 제품도 바로 분석할 수 있어요' : '${base!.brand} ${base!.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: st(13, c: SM.inkSub, h: 1.45),
        ),
        const SizedBox(height: 14),
        option('photo', Ic.camera, '사진으로 전성분 넣기', '제품 뒷면을 찍으면 전성분을 읽어요. 가장 정확해요.', badge: '추천'),
        option('quick', Ic.zap, '주요 성분만 고르기', '레티놀, AHA처럼 아는 성분만 눌러서 5초 만에 넣어요'),
        option('manual', Ic.clipboard, '전성분 직접 입력', '판매 페이지의 전성분을 복사해서 붙여 넣어요'),
      ],
    );
  }
}

/// 주요 성분 칩 고르기 (간단 분석)
Future<void> showQuickPickSheet(BuildContext context, WidgetRef ref, {required String stepId, required String category, Product? base}) =>
    showSmSheet<void>(context, (ctx) => QuickPickSheet(stepId: stepId, category: category, base: base));

/// 고를 수 있는 성분 (충돌 분석에 쓰는 성분 + 진정·보습 + 자외선 차단)
const kQuickGroups = <({String title, List<String> keys})>[
  (title: '강한 성분', keys: ['retinol', 'aha', 'bha', 'pha', 'vitc', 'bpo']),
  (title: '기타 기능 성분', keys: ['niacin', 'copper']),
  (title: '진정 · 보습', keys: ['ceramide', 'ha', 'panthenol', 'cica']),
  (title: '자외선 차단', keys: ['uvf']),
];

/// 제품 이름과 종류로 들어 있을 만한 주요 성분을 추정해요. 사용자가 확인한 뒤에만 넣어요.
/// 예) "레티놀 0.1% 세럼" → 레티놀, 선크림 → 자외선 차단
Set<String> guessQuickKeys(String name, String category) {
  final all = {for (final g in kQuickGroups) ...g.keys};
  return {...detectIngredients(name).where(all.contains), if (category == '선크림') 'uvf'};
}

class QuickPickSheet extends ConsumerStatefulWidget {
  const QuickPickSheet({super.key, required this.stepId, required this.category, this.base});
  final String stepId;
  final String category;
  final Product? base;

  @override
  ConsumerState<QuickPickSheet> createState() => _QuickPickSheetState();
}

class _QuickPickSheetState extends ConsumerState<QuickPickSheet> {
  late final _name = TextEditingController(text: widget.base == null ? '' : '${widget.base!.brand} ${widget.base!.name}');
  late final Set<String> _guessed = widget.base == null ? const {} : guessQuickKeys(widget.base!.name, widget.category);
  late final _picked = {..._guessed};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    if (_picked.isEmpty) return;
    // 칩 순서대로 넣어요
    final keys = [
      for (final g in kQuickGroups)
        for (final k in g.keys)
          if (_picked.contains(k)) k,
    ];
    ref.read(routineProvider.notifier).setQuick(widget.stepId, name: _name.text, keys: keys);
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show('주요 성분 ${keys.length}개를 넣었어요');
  }

  @override
  Widget build(BuildContext context) {
    final n = _picked.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle('주요 성분 고르기'),
        Text(
          _guessed.isEmpty ? '제품 이름이나 포장에 적힌 주요 성분을 골라 주세요.' : '제품 이름을 보고 ${_guessed.length}개를 미리 골라 두었어요. 맞는지 확인해 주세요.',
          style: st(13, c: SM.inkSub, h: 1.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: SM.warnBg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SmIcon(Ic.info, size: 14, color: SM.warnTx),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('고르지 않은 성분은 들어 있지 않은 것으로 분석해요. 확실하지 않으면 사진으로 전성분을 넣는 게 더 정확해요.', style: st(12.5, c: SM.warnInk2, h: 1.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final g in kQuickGroups) ...[
          Text(
            g.title,
            style: st(13, w: w600, c: SM.ink600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in g.keys)
                () {
                  final on = _picked.contains(k);
                  return Semantics(
                    selected: on,
                    child: Pressable(
                      scale: .97,
                      onTap: () => setState(() => on ? _picked.remove(k) : _picked.add(k)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: on ? SM.primaryBg : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: on ? SM.primary : SM.line, width: 1.5),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            ingredientName(k),
                            style: st(14, w: w600, c: on ? SM.primaryTx : SM.ink700),
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Text(
          '제품 이름 (선택)',
          style: st(13, w: w600, c: SM.ink600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _name,
            style: st(15),
            decoration: InputDecoration(
              hintText: '예) 라운드랩 독도 토너',
              hintStyle: st(15, c: SM.inkFaint),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SM.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SM.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        smButton(
          n == 0 ? '성분을 하나 이상 골라 주세요' : '주요 성분 $n개로 넣기',
          n == 0 ? null : _done,
          height: 56,
          bg: n == 0 ? SM.line : SM.ink,
          fg: n == 0 ? SM.inkSub : Colors.white,
          size: 16,
          weight: w700,
        ),
      ],
    );
  }
}
