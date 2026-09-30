import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../models/routine_result.dart';
import '../../providers/routine_provider.dart';
import '../../providers/vanity_provider.dart';
import '../../widgets/common.dart';
import '../analyzer/sheets.dart';

const _filters = ['전체', '토너', '세럼', '크림', '선크림'];

class VanityScreen extends ConsumerWidget {
  const VanityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(vanityProvider);
    final filter = ref.watch(vanityFilterProvider);
    final vis = v.products.where((p) => filter == '전체' || p.category == filter).toList();
    final pad = MediaQuery.paddingOf(context);

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8 + pad.top, 20, 190 + pad.bottom),
            child: FadeIn(
              ms: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('내 화장대', style: st(26, w: w700, ls: -0.035)),
                  const SizedBox(height: 4),
                  Text('등록된 제품 ${v.products.length}개', style: st(13.5, c: SM.inkSub)),
                  const SizedBox(height: 18),
                  if (v.combos.isNotEmpty) ...[
                    Text('저장한 조합', style: st(14, w: w600)),
                    const SizedBox(height: 10),
                    Bleed(
                      height: 80,
                      child: HScroll(
                        bottomPad: 4,
                        children: [
                          for (final c in v.combos)
                            _ComboCard(
                              c,
                              onTap: () {
                                ref.read(routineProvider.notifier).loadSnapshot(c.steps);
                                context.go(Routes.analyzer);
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Bleed(
                    height: 38,
                    child: HScroll(
                      gap: 8,
                      children: [
                        for (final f in _filters)
                          Semantics(
                            selected: filter == f,
                            child: Pressable(
                              scale: 1,
                              onTap: () => ref.read(vanityFilterProvider.notifier).set(f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: filter == f ? SM.ink : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: filter == f ? SM.ink : SM.line),
                                ),
                                child: Text(
                                  f,
                                  style: st(14, w: w600, c: filter == f ? Colors.white : SM.ink600),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  EqualGrid(cols: 2, gap: 12, children: [for (final p in vis) _ProductCard(p)]),
                  if (vis.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                      child: Text(
                        '이 카테고리에 등록된 제품이 없어요.\n아래 + 버튼으로 추가해 보세요.',
                        textAlign: TextAlign.center,
                        style: st(14, c: SM.inkSub, h: 1.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 100 + pad.bottom,
          child: FadeIn(
            ms: 400,
            child: Pressable(
              scale: .96,
              onTap: () => showAddProductSheet(context, ref, initialCategory: filter != '전체' ? filter : '세럼'),
              child: Container(
                height: 54,
                padding: const EdgeInsets.only(left: 16, right: 20),
                decoration: BoxDecoration(
                  color: SM.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: Color(0x800F172A), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: SM.primary, shape: BoxShape.circle),
                      child: const SmIcon(Ic.plus, size: 16, color: Colors.white, strokeWidth: 2.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '제품 직접 등록하기',
                      style: st(15, w: w600, c: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard(this.c, {required this.onTap});
  final SavedRoutine c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bd = BandStyle.of(c.band);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: SM.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bd.bg, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '${c.risk}%',
                style: st(15, w: w700, c: bd.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.steps.length}단계 루틴',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: st(13, w: w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.labels.join(' → '),
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

class _ProductCard extends ConsumerWidget {
  const _ProductCard(this.p);
  final Product p;

  static final _pct = RegExp(r'\s?\d+(\.\d+)?%');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = p.ingredients.length > 2
        ? [...p.ingredients.take(2).map((x) => x.replaceFirst(_pct, '')), '+${p.ingredients.length - 2}']
        : p.ingredients;
    return FadeIn(
      ms: 400,
      child: Pressable(
        scale: .97,
        onTap: () => showProductDetailSheet(context, ref, p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SM.border),
            boxShadow: const [BoxShadow(color: Color(0x380F172A), offset: Offset(0, 12), blurRadius: 30, spreadRadius: -22)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1 / .86,
                child: StripeBox(
                  tint: SM.vanityTint(p.category),
                  stripe: 9,
                  radius: 18,
                  child: Stack(
                    children: [
                      const Center(
                        child: Text(
                          'product image',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: SM.inkSub, letterSpacing: .4),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Pill(p.category, bg: const Color(0xD9FFFFFF), fg: SM.ink700, height: 24, hPad: 9, size: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.brand,
                      style: st(12, w: w500, c: SM.inkSub),
                    ),
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 39),
                      child: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: st(14, w: w600, h: 1.4),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${p.registeredAt ?? ''} 등록', style: st(11.5, c: SM.inkFaint)),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final k in keys) Pill(k, bg: SM.slate100, fg: SM.ink700)],
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
}
