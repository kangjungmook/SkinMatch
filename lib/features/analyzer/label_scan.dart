import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/icons.dart';
import '../../core/ingredient_db.dart';
import '../../core/label_parser.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../providers/routine_provider.dart';
import '../../providers/vanity_provider.dart';
import '../../widgets/common.dart';
import 'sheets.dart';

/// 사진 속 글자 읽기. 테스트에서는 가짜로 바꿔 끼울 수 있어요.
abstract class LabelReader {
  bool get supported;
  Future<String> read(String imagePath);
}

/// Google ML Kit 한국어 글자 인식 (휴대폰 안에서 동작, 무료·오프라인)
class MlKitLabelReader implements LabelReader {
  @override
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final r = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return r.text;
    } finally {
      await recognizer.close();
    }
  }
}

final labelReaderProvider = Provider<LabelReader>((ref) => MlKitLabelReader());

/// 성분 사전 (앱에 들어 있는 JSON)
final ingredientDictionaryProvider = FutureProvider<IngredientDictionary>((ref) async {
  final raw = await rootBundle.loadString('assets/data/ingredient_dictionary.json');
  return IngredientDictionary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// 루틴 단계에 사진으로 전성분을 넣어요: 촬영/앨범 선택 → 글자 인식 → 확인 화면
/// [base]는 검색으로 고른 제품(전성분 없음)이에요. 있으면 브랜드·제품명을 미리 채워요.
Future<void> startLabelScan(BuildContext context, WidgetRef ref, {required String stepId, required String category, Product? base}) async {
  final reader = ref.read(labelReaderProvider);
  if (!reader.supported) {
    ref.read(toastProvider.notifier).show('사진으로 입력하기는 휴대폰 앱에서 쓸 수 있어요');
    return;
  }
  final source = await showSmSheet<ImageSource>(context, (ctx) => const _SourcePicker());
  if (source == null || !context.mounted) return;
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: source, imageQuality: 95);
  } on PlatformException {
    ref.read(toastProvider.notifier).show('카메라나 사진 접근이 꺼져 있어요. 설정에서 허용해 주세요');
    return;
  }
  if (file == null || !context.mounted) return;
  final path = file.path;
  await showSmSheet<void>(
    context,
    (ctx) => LabelReviewSheet(
      imagePath: path,
      stepId: stepId,
      category: category,
      base: base,
      onRetake: () => startLabelScan(context, ref, stepId: stepId, category: category, base: base),
    ),
  );
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker();

  @override
  Widget build(BuildContext context) {
    Widget option(String icon, String title, String sub, ImageSource s) => Pressable(
      onTap: () => Navigator.of(context).pop(s),
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
                  Text(title, style: st(15, w: w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: st(12.5, c: SM.inkSub)),
                ],
              ),
            ),
            const SmIcon(Ic.chevronRight, size: 16, color: SM.inkFaint),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle('사진으로 전성분 입력하기'),
        Text('제품 뒷면의 전성분 부분이 잘 보이게 찍어 주세요', style: st(13, c: SM.inkSub)),
        const SizedBox(height: 14),
        option(Ic.camera, '카메라로 찍기', '글씨가 흐리지 않게, 빛 반사 없이 찍어 주세요', ImageSource.camera),
        const SizedBox(height: 8),
        option(Ic.image, '앨범에서 고르기', '판매 페이지의 전성분 캡처도 괜찮아요', ImageSource.gallery),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: SM.slate100, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SmIcon(Ic.info, size: 14, color: SM.ink600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('글자는 휴대폰 안에서만 읽고, 사진은 서버로 보내지 않아요.', style: st(12.5, c: SM.ink600, h: 1.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 읽은 전성분 확인 화면
class LabelReviewSheet extends ConsumerStatefulWidget {
  const LabelReviewSheet({super.key, required this.imagePath, required this.stepId, required this.category, this.base, this.onRetake});

  final String imagePath;
  final String stepId;
  final String category;
  final Product? base;
  final VoidCallback? onRetake;

  @override
  ConsumerState<LabelReviewSheet> createState() => _LabelReviewSheetState();
}

class _LabelReviewSheetState extends ConsumerState<LabelReviewSheet> {
  late final _brand = TextEditingController(text: widget.base?.brand ?? '');
  late final _name = TextEditingController(text: widget.base?.name ?? '');
  late String _cat = widget.base?.category ?? widget.category;
  bool _saveToVanity = true;
  ParsedLabel? _label;
  List<ParsedIngredient> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _brand.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final dict = await ref.read(ingredientDictionaryProvider.future);
      final text = await ref.read(labelReaderProvider).read(widget.imagePath);
      if (!mounted) return;
      final label = LabelParser(dict).parse(text);
      setState(() {
        _label = label;
        _items = [...label.items];
        if (label.items.isEmpty) _error = '전성분 글자를 찾지 못했어요. 전성분 부분이 크게 나오게 다시 찍어 주세요.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '글자를 읽지 못했어요. 다시 찍어 주세요.');
    }
  }

  int get _keyUnresolved => _items.where((i) => i.keyActive && i.needsReview).length;

  Future<void> _edit(int index) async {
    final item = _items[index];
    final result = await showSmSheet<_EditResult>(context, (ctx) => _EditIngredient(item: item));
    if (result == null || !mounted) return;
    if (!result.delete && result.name.isEmpty) return;
    setState(() {
      if (result.delete) {
        _items.removeAt(index);
      } else {
        _items[index] = item.copyWith(name: result.name, status: MatchStatus.exact);
      }
    });
  }

  Future<void> _add() async {
    final result = await showSmSheet<_EditResult>(
      context,
      (ctx) => const _EditIngredient(
        item: ParsedIngredient(raw: '', name: '', status: MatchStatus.unknown),
      ),
    );
    if (result == null || result.delete || result.name.trim().isEmpty || !mounted) return;
    setState(() => _items.add(ParsedIngredient(raw: '', name: result.name.trim(), status: MatchStatus.exact, keyActive: false)));
  }

  void _confirm() {
    if (_items.isEmpty) return;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final p = Product(
      id: 'l${now.microsecondsSinceEpoch}',
      brand: _brand.text.trim().isEmpty ? '브랜드 미입력' : _brand.text.trim(),
      name: _name.text.trim().isEmpty ? '사진으로 등록한 $_cat' : _name.text.trim(),
      category: _cat,
      registeredAt: '${now.year}.${two(now.month)}.${two(now.day)}',
      ingredients: [for (final i in _items) i.name],
      imageUrl: widget.base?.imageUrl,
      source: widget.base?.source,
    );
    ref.read(routineProvider.notifier).pickProduct(widget.stepId, p);
    if (_saveToVanity) ref.read(vanityProvider.notifier).addProduct(p);
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show(_saveToVanity ? '전성분을 루틴과 내 화장대에 넣었어요' : '전성분을 루틴에 넣었어요');
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          smSheetTitle('전성분 확인하기'),
          const SizedBox(height: 8),
          Text(_error!, style: st(14, c: SM.ink600, h: 1.55)),
          const SizedBox(height: 16),
          smButton('다시 찍기', () {
            Navigator.of(context).pop();
            widget.onRetake?.call();
          }),
          const SizedBox(height: 6),
          Pressable(
            scale: 1,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(routineProvider.notifier).manualMode(widget.stepId);
            },
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  '성분 직접 입력하기',
                  style: st(14, w: w500, c: SM.inkSub),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (label == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          smSheetTitle('전성분 확인하기'),
          const SizedBox(height: 12),
          const Shimmer(height: 24, radius: 8),
          const SizedBox(height: 8),
          const FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: .7, child: Shimmer(height: 24, radius: 8)),
          const SizedBox(height: 16),
          Text(
            '사진에서 전성분을 읽고 있어요…',
            textAlign: TextAlign.center,
            style: st(13, c: SM.inkSub),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    final review = _items.where((i) => i.needsReview).length;
    final key = _keyUnresolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle('전성분 확인하기'),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '성분 ${_items.length}개를 읽었어요'),
              if (review > 0)
                TextSpan(
                  text: ' · 확인할 성분 $review개',
                  style: st(13, w: w600, c: SM.warnTx),
                ),
            ],
          ),
          style: st(13, c: SM.inkSub),
        ),
        if (!label.foundHeader) ...[
          const SizedBox(height: 10),
          _Notice(text: "'전성분' 글자를 찾지 못해서 사진 전체를 읽었어요. 성분이 아닌 글자가 섞였으면 눌러서 지워 주세요.", warn: true),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _items.length; i++) _IngredientChip(item: _items[i], onTap: () => _edit(i)),
            Pressable(
              scale: 1,
              onTap: _add,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SM.line),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '+ 성분 추가',
                    style: st(12.5, w: w600, c: SM.ink600),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Legend(),
        const SizedBox(height: 20),
        Text('제품 정보 (선택)', style: st(14, w: w600)),
        const SizedBox(height: 8),
        _Field(controller: _brand, hint: '브랜드명'),
        const SizedBox(height: 8),
        _Field(controller: _name, hint: '제품명'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in kStepCategories)
              Pressable(
                scale: 1,
                onTap: () => setState(() => _cat = c),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _cat == c ? SM.primaryBg : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cat == c ? SM.primary : SM.line, width: 1.5),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      c,
                      style: st(13, w: w600, c: _cat == c ? SM.primaryTx : SM.ink700),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Pressable(
          scale: 1,
          onTap: () => setState(() => _saveToVanity = !_saveToVanity),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _saveToVanity ? SM.primary : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _saveToVanity ? SM.primary : SM.slate300, width: 1.5),
                ),
                child: const SmIcon(Ic.check, size: 12, color: Colors.white, strokeWidth: 3),
              ),
              const SizedBox(width: 10),
              Text('내 화장대에도 저장하기', style: st(14, w: w500)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        smButton(
          key > 0 ? '중요 성분 $key개를 먼저 확인해 주세요' : '이 전성분으로 루틴에 넣기',
          key > 0 || _items.isEmpty ? null : _confirm,
          height: 56,
          bg: key > 0 || _items.isEmpty ? SM.line : SM.ink,
          fg: key > 0 || _items.isEmpty ? SM.inkSub : Colors.white,
          size: 16,
          weight: w700,
        ),
        const SizedBox(height: 6),
        Pressable(
          scale: 1,
          onTap: () {
            Navigator.of(context).pop();
            widget.onRetake?.call();
          },
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                '다시 찍기',
                style: st(14, w: w500, c: SM.inkSub),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.item, required this.onTap});
  final ParsedIngredient item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (item.status) {
      MatchStatus.exact => (SM.slate100, SM.ink700, SM.slate100),
      MatchStatus.corrected => (SM.warnBg, SM.warnTx, item.keyActive ? SM.warn : SM.warnLine),
      MatchStatus.unknown => (SM.dangerBg, SM.dangerTx, item.keyActive ? SM.danger : SM.dangerLine),
    };
    return Pressable(
      scale: 1,
      semanticLabel: '${item.name} 성분 고치기',
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: item.keyActive && item.needsReview ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: st(12.5, w: w600, c: fg),
            ),
            if (item.needsReview) ...[const SizedBox(width: 4), SmIcon(Ic.alertCircle, size: 12, color: fg, strokeWidth: 2.4)],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(
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
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [dot(SM.slate300, '확인됨'), dot(SM.warnLine, '자동으로 고침 · 눌러서 확인'), dot(SM.dangerLine, '사전에 없음 · 눌러서 고치기')],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.warn = false});
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: warn ? SM.warnBg : SM.slate100, borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SmIcon(Ic.info, size: 14, color: warn ? SM.warnTx : SM.ink600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: st(12.5, c: warn ? SM.warnInk2 : SM.ink600, h: 1.5)),
        ),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: TextField(
      controller: controller,
      style: st(15),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
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
  );
}

class _EditResult {
  const _EditResult(this.name, {this.delete = false});
  final String name;
  final bool delete;
}

/// 성분 하나 고치기: 후보 고르기 / 직접 고치기 / 지우기
class _EditIngredient extends StatefulWidget {
  const _EditIngredient({required this.item});
  final ParsedIngredient item;

  @override
  State<_EditIngredient> createState() => _EditIngredientState();
}

class _EditIngredientState extends State<_EditIngredient> {
  late final _ctrl = TextEditingController(text: widget.item.name);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final adding = it.raw.isEmpty && it.name.isEmpty;
    final options = <String>{if (it.status != MatchStatus.unknown) it.name, ...it.candidates}.where((s) => s.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        smSheetTitle(adding ? '성분 추가하기' : '이 성분이 맞나요?'),
        if (it.raw.isNotEmpty) Text('사진에서 읽은 글자: ${it.raw}', style: st(13, c: SM.inkSub)),
        if (it.keyActive && it.needsReview) ...[
          const SizedBox(height: 10),
          const _Notice(text: '충돌 분석에 중요한 성분이라 꼭 확인해 주세요. 제품 뒷면의 글자와 같은지 봐 주세요.', warn: true),
        ],
        if (options.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final o in options) ...[
            smButton(o, () => Navigator.of(context).pop(_EditResult(o)), height: 48, bg: SM.bg, fg: SM.ink, size: 15),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        Text(
          adding ? '성분 이름' : '직접 고치기',
          style: st(13, w: w600, c: SM.ink600),
        ),
        const SizedBox(height: 6),
        _Field(controller: _ctrl, hint: '예) 나이아신아마이드'),
        const SizedBox(height: 10),
        smButton(adding ? '이 성분 추가하기' : '이 이름으로 고치기', () => Navigator.of(context).pop(_EditResult(_ctrl.text.trim())), height: 52),
        if (!adding) ...[
          const SizedBox(height: 6),
          Pressable(
            scale: 1,
            onTap: () => Navigator.of(context).pop(const _EditResult('', delete: true)),
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  '성분이 아니라서 지우기',
                  style: st(14, w: w500, c: SM.dangerStrong),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
