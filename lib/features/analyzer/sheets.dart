import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/router.dart';
import '../../core/icons.dart';
import '../../core/ingredient_db.dart';
import '../../core/theme.dart';
import '../../data/product_repository.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../providers/routine_provider.dart';
import '../../providers/vanity_provider.dart';
import '../../widgets/common.dart';

/// 프로토타입의 바텀 시트: 흐린 배경(3px) + 아래에서 올라오는 흰 시트 (최대 88%)
Future<T?> showSmSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '시트 닫기',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) {
      final dim = CurvedAnimation(
        parent: anim,
        curve: const Interval(0, .6, curve: Curves.ease),
      );
      final slide = CurvedAnimation(parent: anim, curve: const Cubic(.22, 1.1, .36, 1), reverseCurve: Curves.easeIn);
      final mq = MediaQuery.of(ctx);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).maybePop(),
              child: FadeTransition(
                opacity: dim,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: const ColoredBox(color: Color(0x5C0F172A)),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(slide),
              child: Padding(
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: (mq.size.height - mq.viewInsets.bottom) * .88),
                  child: Material(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 10, 20, 30 + mq.padding.bottom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(color: SM.line, borderRadius: BorderRadius.circular(5)),
                            ),
                          ),
                          Builder(builder: builder),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget smSheetTitle(String t, {double bottom = 4}) => Padding(
  padding: EdgeInsets.only(bottom: bottom),
  child: Text(t, style: st(18, w: w700)),
);

Widget smButton(
  String label,
  VoidCallback? onTap, {
  double height = 54,
  Color bg = SM.ink,
  Color fg = Colors.white,
  double size = 15,
  FontWeight weight = w600,
}) => Pressable(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
    child: Text(
      label,
      style: st(size, w: weight, c: fg),
    ),
  ),
);

// ───────────────────────── 내 화장대에서 불러오기

void showPickerSheet(BuildContext context, WidgetRef ref, {required String? targetId}) {
  final router = GoRouter.of(context);
  showSmSheet<void>(context, (ctx) {
    return Consumer(
      builder: (ctx, ref, _) {
        final products = ref.watch(vanityProvider).products;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            smSheetTitle('내 화장대에서 불러오기'),
            Text(targetId != null ? '선택한 단계를 이 제품으로 채워요' : '루틴의 빈 단계에 추가하거나 새 단계로 넣어요', style: st(13, c: SM.inkSub)),
            const SizedBox(height: 14),
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '화장대에 등록된 제품이 없어요.\n내 화장대 탭에서 제품을 먼저 등록해 주세요.',
                  textAlign: TextAlign.center,
                  style: st(14, c: SM.inkSub, h: 1.6),
                ),
              ),
            for (final p in products) ...[
              _PickRow(
                p: p,
                onTap: () {
                  ref.read(routineProvider.notifier).addFromVanity(p, targetId);
                  Navigator.of(ctx).pop();
                  router.go(Routes.analyzer);
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  });
}

class _PickRow extends StatefulWidget {
  const _PickRow({required this.p, required this.onTap});
  final Product p;
  final VoidCallback onTap;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _h ? SM.bg : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SM.border),
          ),
          child: Row(
            children: [
              StripeBox(tint: SM.vanityTint(p.category), width: 48, height: 48, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.brand} · ${p.category}', style: st(12, c: SM.inkSub)),
                    const SizedBox(height: 2),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: st(14.5, w: w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SmIcon(Ic.chevronRight, size: 16, color: SM.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 성분 사전

void showIngredientSheet(BuildContext context, String key) {
  final info = kIngredientInfo[key];
  if (info == null) return;
  final (kindBg, kindFg) = info.grade == '안심 성분'
      ? (SM.primaryBg, SM.primaryTx)
      : info.grade == '대체로 안심'
      ? (SM.slate100, SM.ink700)
      : (SM.warnBg, SM.warnTx);
  showSmSheet<void>(context, (ctx) {
    Widget list(String title, List<String> items, Color bg, Color border, Color titleColor, Color itemColor) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: st(12, w: w700, c: titleColor),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Text(
              items[i],
              style: st(13, w: w500, c: itemColor),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Pill(info.grade, bg: kindBg, fg: kindFg, height: 24, hPad: 9, size: 11.5, weight: w700),
            const SizedBox(width: 8),
            Text('성분 사전', style: st(12, c: SM.inkSub)),
          ],
        ),
        const SizedBox(height: 6),
        Text(ingredientName(key), style: st(22, w: w700, ls: -0.03)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: SM.bg, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주요 효능',
                style: st(12, w: w700, c: SM.inkSub),
              ),
              const SizedBox(height: 4),
              Text(info.effect, style: st(14.5, h: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: SM.warnBg, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '사용 팁 · 주의',
                style: st(12, w: w700, c: SM.warnTx),
              ),
              const SizedBox(height: 4),
              Text(info.tip, style: st(14, c: SM.warnInk2, h: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list('함께 쓰면 좋아요', info.goodWith, SM.primaryBg, SM.primaryLine, SM.primaryTx, SM.primaryInk)),
              const SizedBox(width: 10),
              Expanded(child: list('동시 사용 주의', info.avoidWith, SM.dangerBg, SM.dangerLine, SM.dangerTx, SM.dangerInk)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        smButton('성분 설명 닫기', () => Navigator.of(ctx).pop(), height: 52),
      ],
    );
  });
}

// ───────────────────────── 바코드 스캔

void showScanSheet(BuildContext context, WidgetRef ref, {required String targetId}) {
  showSmSheet<void>(context, (ctx) => _ScanSheet(targetId: targetId));
}

class _ScanSheet extends ConsumerStatefulWidget {
  const _ScanSheet({required this.targetId});
  final String targetId;

  @override
  ConsumerState<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends ConsumerState<_ScanSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128],
  );
  bool _busy = false;

  @override
  void dispose() {
    _line.dispose();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _found(Product? p, {String? code}) async {
    final toast = ref.read(toastProvider.notifier);
    if (p == null) {
      toast.show('등록되지 않은 바코드예요. 제품명으로 검색해 주세요');
      return;
    }
    ref.read(routineProvider.notifier).pickProduct(widget.targetId, p);
    if (mounted) Navigator.of(context).pop();
    toast.show('스캔 완료 · ${p.name}');
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    final code = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _found(await ref.read(productRepositoryProvider).byBarcode(code), code: code);
    } catch (_) {
      ref.read(toastProvider.notifier).show('제품 정보를 불러오지 못했어요. 네트워크를 확인해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sample() async {
    final repo = ref.read(productRepositoryProvider);
    if (repo is! MockProductRepository) return;
    final list = [...repo.catalog]..shuffle();
    await _found(list.first);
  }

  /// [mono]는 프로토타입의 "camera preview" 자리 표시용, 안내 문구는 Pretendard로 보여 줘요.
  Widget _placeholder(String text, {bool mono = false}) => ColoredBox(
    color: SM.ink,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 11, color: SM.inkSub) : st(12.5, c: SM.slate300, h: 1.5),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(productRepositoryProvider) is MockProductRepository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle('바코드로 제품 찾기'),
        Text('제품 뒷면의 바코드를 네모 안에 맞춰 주세요', style: st(13, c: SM.inkSub)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 230,
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight, w = c.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: MobileScanner(
                        controller: _camera,
                        onDetect: _onDetect,
                        placeholderBuilder: (_) => _placeholder('camera preview', mono: true),
                        errorBuilder: (_, e) => _placeholder(
                          e.errorCode == MobileScannerErrorCode.permissionDenied
                              ? '카메라 권한이 꺼져 있어요\n설정에서 카메라 접근을 허용해 주세요'
                              : '이 기기에서는 카메라를 사용할 수 없어요',
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * .16,
                      right: w * .16,
                      top: h * .14,
                      bottom: h * .14,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x2EFFFFFF), width: 2),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _line,
                      builder: (_, _) {
                        final t = Curves.easeInOut.transform(_line.value < .5 ? _line.value * 2 : (1 - _line.value) * 2);
                        return Positioned(
                          left: w * .16,
                          right: w * .16,
                          top: h * (.14 + .68 * t),
                          height: 2,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: SM.primaryGlow,
                                boxShadow: [BoxShadow(color: SM.primaryGlow, blurRadius: 12)],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (isMock) ...[
          const SizedBox(height: 14),
          smButton('샘플 바코드로 스캔해 보기', _sample),
          const SizedBox(height: 10),
          Text(
            '목업 · 샘플 제품 DB에는 실제 바코드가 없어서, 이 버튼으로 스캔을 체험할 수 있어요',
            textAlign: TextAlign.center,
            style: st(11.5, c: SM.inkFaint),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            _busy ? '제품 정보를 찾는 중…' : '바코드가 인식되면 자동으로 제품을 불러와요',
            textAlign: TextAlign.center,
            style: st(11.5, c: SM.inkFaint),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── 화장대 제품 상세

void showProductDetailSheet(BuildContext context, WidgetRef ref, Product p) {
  final router = GoRouter.of(context);
  showSmSheet<void>(context, (ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StripeBox(
          tint: SM.vanityTint(p.category),
          stripe: 10,
          height: 170,
          radius: 22,
          child: Center(
            child: Text(
              'product image',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: SM.inkSub),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${p.brand} · ${p.category}', style: st(13, c: SM.inkSub)),
        const SizedBox(height: 4),
        Text(p.name, style: st(20, w: w700, ls: -0.03)),
        const SizedBox(height: 4),
        Text('${p.registeredAt ?? ''} 등록', style: st(12.5, c: SM.inkFaint)),
        const SizedBox(height: 16),
        Text('주요 핵심 성분', style: st(14, w: w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final k in p.ingredients) Pill(k, bg: SM.slate100, fg: SM.ink700, height: 28, hPad: 11, size: 12.5)],
        ),
        const SizedBox(height: 20),
        smButton('분석 루틴에 추가하기', () {
          ref.read(routineProvider.notifier).addFromVanity(p, null);
          Navigator.of(ctx).pop();
          router.go(Routes.analyzer);
        }),
        const SizedBox(height: 6),
        Pressable(
          scale: 1,
          onTap: () {
            ref.read(vanityProvider.notifier).removeProduct(p.id);
            Navigator.of(ctx).pop();
            ref.read(toastProvider.notifier).show('화장대에서 삭제했어요');
          },
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                '화장대에서 삭제',
                style: st(14, w: w500, c: SM.dangerStrong),
              ),
            ),
          ),
        ),
      ],
    );
  });
}

// ───────────────────────── 제품 직접 등록

void showAddProductSheet(BuildContext context, WidgetRef ref, {required String initialCategory}) {
  showSmSheet<void>(context, (ctx) => _AddProductSheet(initialCategory: initialCategory));
}

class _AddProductSheet extends ConsumerStatefulWidget {
  const _AddProductSheet({required this.initialCategory});
  final String initialCategory;

  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  final _brand = TextEditingController(), _name = TextEditingController(), _ing = TextEditingController();
  late String _cat = widget.initialCategory;

  static const cats = ['토너', '세럼', '크림', '선크림'];

  @override
  void initState() {
    super.initState();
    for (final c in [_brand, _name, _ing]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _brand.dispose();
    _name.dispose();
    _ing.dispose();
    super.dispose();
  }

  bool get _can => _name.text.trim().isNotEmpty && _ing.text.trim().isNotEmpty;

  void _submit() {
    final toast = ref.read(toastProvider.notifier);
    if (!_can) return toast.show('제품명과 주요 성분을 입력해 주세요');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    ref
        .read(vanityProvider.notifier)
        .addProduct(
          Product(
            id: 'u${now.microsecondsSinceEpoch}',
            brand: _brand.text.trim().isEmpty ? '브랜드 미입력' : _brand.text.trim(),
            name: _name.text.trim(),
            category: _cat,
            registeredAt: '${now.year}.${two(now.month)}.${two(now.day)}',
            ingredients: _ing.text.split(RegExp(r'[,\n]')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
          ),
        );
    ref.read(vanityFilterProvider.notifier).set('전체');
    Navigator.of(context).pop();
    toast.show('화장대에 등록했어요');
  }

  InputDecoration _deco(String hint, {EdgeInsets? pad}) => InputDecoration(
    hintText: hint,
    hintStyle: st(15, c: SM.inkFaint, h: pad == null ? null : 1.5),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: pad ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: SM.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: SM.line),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle('제품 직접 등록하기', bottom: 16),
        SizedBox(
          height: 52,
          child: TextField(controller: _brand, style: st(15), decoration: _deco('브랜드명'), textInputAction: TextInputAction.next),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: TextField(controller: _name, style: st(15), decoration: _deco('제품명 (필수)'), textInputAction: TextInputAction.next),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              Pressable(
                scale: 1,
                onTap: () => setState(() => _cat = c),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _cat == c ? SM.primaryBg : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cat == c ? SM.primary : SM.line, width: 1.5),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      c,
                      style: st(13.5, w: w600, c: _cat == c ? SM.primaryTx : SM.ink700),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ing,
          minLines: 3,
          maxLines: 3,
          style: st(15, h: 1.5),
          decoration: _deco('주요 성분을 쉼표로 구분해 입력 (필수)\n예) 나이아신아마이드, 판테놀', pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
        const SizedBox(height: 16),
        smButton('화장대에 등록', _submit, height: 56, bg: _can ? SM.ink : SM.line, fg: _can ? Colors.white : SM.inkSub, size: 16, weight: w700),
      ],
    );
  }
}
