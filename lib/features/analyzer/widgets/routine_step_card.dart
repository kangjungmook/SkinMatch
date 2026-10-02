import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons.dart';
import '../../../core/ingredient_db.dart';
import '../../../core/theme.dart';
import '../../../models/product.dart';
import '../../../models/routine_step.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/common.dart';
import '../../../widgets/dashed_border.dart';
import '../label_scan.dart';
import '../quick_pick.dart';
import '../sheets.dart';

/// 루틴 한 단계 (왼쪽 번호 레일 + 카드)
class RoutineStepCard extends ConsumerStatefulWidget {
  const RoutineStepCard({super.key, required this.step, required this.index, required this.count});

  final RoutineStep step;
  final int index;
  final int count;

  @override
  ConsumerState<RoutineStepCard> createState() => _RoutineStepCardState();
}

class _RoutineStepCardState extends ConsumerState<RoutineStepCard> {
  final _query = TextEditingController();
  late final _text = TextEditingController(text: widget.step.text);
  final _queryFocus = FocusNode();
  Timer? _debounce;
  bool _searching = false;
  List<Product> _results = const [];
  int _searchSeq = 0;

  RoutineNotifier get _n => ref.read(routineProvider.notifier);
  RoutineStep get _s => widget.step;

  @override
  void didUpdateWidget(RoutineStepCard old) {
    super.didUpdateWidget(old);
    if (_s.text != _text.text && (_s.manual || _s.product == null)) {
      _text.value = TextEditingValue(
        text: _s.text,
        selection: TextSelection.collapsed(offset: _s.text.length),
      );
    }
    if (_s.product != null && old.step.product != _s.product) _resetSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _text.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _resetSearch() {
    _debounce?.cancel();
    _searchSeq++;
    _query.clear();
    _searching = false;
    _results = const [];
  }

  /// 입력이 멈추고 280ms 뒤에 검색해요.
  void _runSearch(String v, {bool setField = false}) {
    if (setField) {
      _query.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
    }
    _debounce?.cancel();
    final seq = ++_searchSeq;
    setState(() {
      _searching = v.trim().isNotEmpty;
      _results = const [];
    });
    if (v.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      List<Product> res;
      try {
        res = await ref.read(productRepositoryProvider).search(v, category: null);
      } catch (_) {
        res = const [];
        ref.read(toastProvider.notifier).show('제품 검색에 실패했어요. 네트워크를 확인해 주세요');
      }
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _results = res;
      });
    });
  }

  void _pick(Product p) {
    setState(_resetSearch);
    _n.pickProduct(_s.id, p);
  }

  void _otherMethods() {
    setState(_resetSearch);
    showInputMethodSheet(context, ref, stepId: _s.id, category: _s.category);
  }

  /// 주요 성분만 넣은 단계: 간단 입력 표시 + 사진으로 전성분 넣기 안내
  Widget _quickView() {
    final label = _s.text.split('\n').first;
    return FadeIn(
      ms: 300,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SM.warnBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SM.warnLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Pill('간단 입력', bg: Colors.white, fg: SM.warnTx),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: st(14, w: w700),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => _n.clearProduct(_s.id),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SM.line),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        '변경',
                        style: st(12, w: w600, c: SM.ink600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('주요 성분만 넣었어요. 전성분을 넣으면 분석이 더 정확해져요.', style: st(12, c: SM.warnInk2, h: 1.5)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                scale: 1,
                onTap: _photo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SmIcon(Ic.camera, size: 13, color: SM.warnTx, strokeWidth: 2),
                      const SizedBox(width: 5),
                      Text(
                        '사진으로 전성분 넣기',
                        style: st(12.5, w: w600, c: SM.warnTx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _photo() {
    setState(_resetSearch);
    // 간단 입력 단계에서 사진으로 바꿀 때는 적어 둔 제품 이름을 이어서 써요.
    final base = _s.quick
        ? Product(id: '', brand: '', name: _s.text.split('\n').first, category: _s.category, ingredients: const [])
        : null;
    startLabelScan(context, ref, stepId: _s.id, category: _s.category, base: base);
  }

  Future<void> _paste() async {
    final toast = ref.read(toastProvider.notifier);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final t = data?.text ?? '';
      if (t.isEmpty) return toast.show('클립보드가 비어 있어요');
      setState(_resetSearch);
      _n.pasteText(_s.id, t);
      toast.show('클립보드 내용을 붙여넣었어요');
    } catch (_) {
      toast.show('클립보드 접근이 차단되었어요. 직접 붙여넣어 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final has = s.isFilled;
    final keys = detectIngredients(s.text);
    final searchMode = s.product == null && !s.manual && !s.quick;
    final q = _query.text.trim();

    return FadeIn(
      ms: 350,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: has ? SM.ink : Colors.white,
                      border: Border.all(color: has ? SM.ink : SM.slate300, width: 1.5),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: st(12.5, w: w700, c: has ? Colors.white : SM.inkSub),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: Container(width: 2, color: SM.line)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SmCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(),
                      const SizedBox(height: 8),
                      if (s.product != null) _productView(s.product!),
                      if (searchMode) ..._searchView(q),
                      if (s.product == null && s.quick) _quickView(),
                      if (s.product == null && s.manual) ..._manualView(),
                      if (has) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final k in keys) _IngredientChip(k),
                            if (keys.isEmpty) Text('인식된 주요 성분 없음', style: st(12, c: SM.inkSub)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final i = widget.index, n = widget.count;
    return Row(
      children: [
        // 좁은 화면에서는 CSS flex처럼 이 알약이 먼저 줄어들어요.
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CategoryPicker(value: _s.category, onChanged: (c) => _n.setCategory(_s.id, c)),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          decoration: BoxDecoration(
            color: SM.bg,
            border: Border.all(color: SM.border),
            borderRadius: BorderRadius.circular(11),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              _ToolBtn(
                icon: Ic.chevronUp,
                label: '위로 이동',
                width: 28,
                stroke: 2.2,
                size: 14,
                enabled: i > 0,
                onTap: () => _n.move(_s.id, -1),
                bare: true,
              ),
              Container(width: 1, height: 32, color: SM.border),
              _ToolBtn(
                icon: Ic.chevronDown,
                label: '아래로 이동',
                width: 28,
                stroke: 2.2,
                size: 14,
                enabled: i < n - 1,
                onTap: () => _n.move(_s.id, 1),
                bare: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _ToolBtn(icon: Ic.clipboard, label: '클립보드 붙여넣기', stroke: 1.9, onTap: _paste),
        const SizedBox(width: 6),
        _ToolBtn(
          icon: Ic.bottle,
          label: '내 화장대에서 불러오기',
          stroke: 1.9,
          onTap: () => showPickerSheet(context, ref, targetId: _s.id),
        ),
        const SizedBox(width: 6),
        _ToolBtn(
          icon: Ic.close,
          label: '단계 삭제',
          size: 15,
          enabled: n > 1,
          disabledOpacity: .35,
          hoverColor: SM.dangerStrong,
          onTap: () => _n.remove(_s.id),
        ),
      ],
    );
  }

  Widget _productView(Product p) => p.hasIngredients ? _filledProductView(p) : _needsIngredientsView(p);

  /// 검색(네이버)으로 고른 제품: 전성분이 없어서 넣는 방법을 바로 보여 줘요.
  Widget _needsIngredientsView(Product p) {
    void run(String method) {
      setState(_resetSearch);
      runInputMethod(context, ref, method, stepId: _s.id, category: p.category, base: p);
    }

    Widget action(String method, String icon, String label, {bool primary = false}) => Expanded(
      child: Pressable(
        semanticLabel: label,
        onTap: () => run(method),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: primary ? SM.ink : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: primary ? null : Border.all(color: SM.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SmIcon(icon, size: 14, color: primary ? Colors.white : SM.ink700, strokeWidth: 2),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: st(12.5, w: w600, c: primary ? Colors.white : SM.ink700),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FadeIn(
      ms: 300,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SM.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SM.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumb(p, size: 46, radius: 13, base: SM.bg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.brand,
                        style: st(11.5, w: w500, c: SM.inkSub),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: st(14, w: w700, h: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _changeBtn(),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: SM.warnBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: SmIcon(Ic.info, size: 13, color: SM.warnTx, strokeWidth: 2.2),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text('전성분 정보가 아직 없어요. 전성분을 넣어야 분석할 수 있어요.', style: st(12.5, c: SM.warnInk2, h: 1.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                action('photo', Ic.camera, '사진으로', primary: true),
                const SizedBox(width: 6),
                action('quick', Ic.zap, '주요 성분'),
                const SizedBox(width: 6),
                action('manual', Ic.clipboard, '직접 입력'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _changeBtn() => Pressable(
    onTap: () => _n.clearProduct(_s.id),
    child: Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SM.line),
      ),
      child: Text(
        '변경',
        style: st(12, w: w600, c: SM.ink600),
      ),
    ),
  );

  Widget _filledProductView(Product p) => FadeIn(
    ms: 300,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SM.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SM.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumb(p, size: 46, radius: 13, base: SM.bg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.brand,
                  style: st(11.5, w: w500, c: SM.inkSub),
                ),
                const SizedBox(height: 1),
                Text(p.name, style: st(14, w: w700, h: 1.35)),
                const SizedBox(height: 4),
                Text(
                  '전성분 · ${p.ingredients.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: st(12, c: SM.inkSub, h: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: () => _n.clearProduct(_s.id),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: SM.line),
              ),
              child: Text(
                '변경',
                style: st(12, w: w600, c: SM.ink600),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _searchView(String q) => [
    AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: SM.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: q.isNotEmpty ? SM.primary : SM.border),
      ),
      child: Row(
        children: [
          const SmIcon(Ic.search, size: 17, color: SM.inkSub),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _queryFocus,
              onChanged: _runSearch,
              style: st(14.5),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '제품명으로 검색 (예: 레티놀 세럼)',
                hintStyle: st(14.5, c: SM.inkFaint),
              ),
            ),
          ),
          if (_searching) ...[const SizedBox(width: 8), Text('검색 중…', style: st(11.5, c: SM.inkSub))],
          const SizedBox(width: 8),
          _FieldIconBtn(icon: Ic.camera, label: '사진으로 전성분 입력', onTap: _photo),
          const SizedBox(width: 6),
          Pressable(
            semanticLabel: '바코드 스캔',
            onTap: () => showScanSheet(context, ref, targetId: _s.id),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Color(0x140F172A), offset: Offset(0, 1), blurRadius: 2)],
              ),
              child: const SmIcon(Ic.barcode, size: 17, strokeWidth: 1.9),
            ),
          ),
        ],
      ),
    ),
    if (q.isNotEmpty) ...[
      const SizedBox(height: 6),
      FadeIn(
        ms: 250,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SM.border),
            boxShadow: const [BoxShadow(color: Color(0x4D0F172A), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -18)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer(height: 34),
                      SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: .8, child: Shimmer(height: 34)),
                    ],
                  ),
                ),
              for (final p in _results) _ResultRow(p, onTap: () => _pick(p)),
              if (!_searching && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('검색 결과가 없어요', style: st(13, c: SM.inkSub)),
                      ),
                      const SizedBox(width: 8),
                      Pressable(
                        scale: 1,
                        onTap: _otherMethods,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text('다른 방법', style: st(12, c: SM.inkSub)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Pressable(
                        onTap: _photo,
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: SM.primaryBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: SM.primaryLine),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SmIcon(Ic.camera, size: 13, color: SM.primaryTx, strokeWidth: 2),
                              const SizedBox(width: 5),
                              Text(
                                '사진으로 입력',
                                style: st(12.5, w: w600, c: SM.primaryTx),
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
      ),
    ],
    if (q.isEmpty) ...[
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final t in kQuickSearch[_s.category] ?? const <String>[])
                  _HoverChip(label: t, onTap: () => _runSearch(t, setField: true)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            scale: 1,
            onTap: _otherMethods,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                '다른 방법으로 입력',
                style: st(12, c: SM.inkSub, deco: TextDecoration.underline).copyWith(decorationThickness: 1),
              ),
            ),
          ),
        ],
      ),
    ],
  ];

  List<Widget> _manualView() => [
    TextField(
      controller: _text,
      onChanged: (v) => _n.setText(_s.id, v),
      minLines: 3,
      maxLines: 3,
      style: st(14, h: 1.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: SM.bg,
        hintText: '전성분을 붙여넣어 주세요\n${kPlaceholder[_s.category] ?? kPlaceholder['기타']}',
        hintStyle: st(14, c: SM.inkFaint, h: 1.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SM.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SM.border),
        ),
      ),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        scale: 1,
        onTap: () => _n.searchMode(_s.id),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '← 제품명으로 검색하기',
            style: st(12.5, w: w600, c: SM.primaryTx),
          ),
        ),
      ),
    ),
  ];
}

/// 단계 종류 선택 알약 (토너, 세럼 …)
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '단계 종류 선택',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SM.border),
      ),
      itemBuilder: (_) => [
        for (final c in kStepCategories)
          PopupMenuItem(
            value: c,
            height: 44,
            child: Text(
              c,
              style: st(14, w: c == value ? w700 : w500, c: c == value ? SM.primaryTx : SM.ink),
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(
          color: SM.primaryBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SM.primaryLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: st(13, w: w600, c: SM.primaryTx),
              ),
            ),
            const SizedBox(width: 6),
            const SmIcon(Ic.chevronDown, size: 12, color: SM.primaryTx, strokeWidth: 2.4),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatefulWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.width = 32,
    this.size = 16,
    this.stroke = 2,
    this.enabled = true,
    this.disabledOpacity = .3,
    this.bare = false,
    this.hoverColor = SM.ink,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final double width;
  final double size;
  final double stroke;
  final bool enabled;
  final double disabledOpacity;
  final bool bare;
  final Color hoverColor;

  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onTap : null,
            child: Opacity(
              opacity: widget.enabled ? 1 : widget.disabledOpacity,
              child: Container(
                width: widget.width,
                height: 32,
                alignment: Alignment.center,
                decoration: widget.bare
                    ? null
                    : BoxDecoration(
                        color: SM.bg,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: SM.border),
                      ),
                child: SmIcon(
                  widget.icon,
                  size: widget.size,
                  strokeWidth: widget.stroke,
                  color: _hover && !widget.bare ? widget.hoverColor : SM.inkSub,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow(this.p, {required this.onTap});
  final Product p;
  final VoidCallback onTap;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final preview = p.hasIngredients ? p.ingredients.where((i) => i != '정제수').take(3).join(', ') : '전성분은 고른 뒤에 넣어요';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? SM.bg : Colors.white,
            border: const Border(bottom: BorderSide(color: SM.border)),
          ),
          child: Row(
            children: [
              ProductThumb(p, size: 36, radius: 10, stripe: 5),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: p.brand,
                            style: st(13.5, w: w500, c: SM.inkSub),
                          ),
                          TextSpan(
                            text: ' ${p.name}',
                            style: st(13.5, w: w600),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: st(11.5, c: SM.inkSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Pill(p.category, bg: SM.slate100, fg: SM.ink600),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverChip extends StatefulWidget {
  const _HoverChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _h ? SM.primaryLine : SM.border),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            widget.label,
            style: st(11.5, w: w500, c: _h ? SM.primaryTx : SM.ink600),
          ),
        ),
      ),
    ),
  );
}

/// 인식된 성분 칩. 누르면 성분 사전이 열려요.
class _IngredientChip extends ConsumerWidget {
  const _IngredientChip(this.k);
  final String k;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bg, fg) = kSoothe.contains(k) || k == 'uvf'
        ? (SM.primaryBg, SM.primaryTx)
        : k == 'niacin'
        ? (SM.slate100, SM.ink)
        : (SM.orangeBg, SM.warnTx);
    return Pressable(
      scale: 1,
      semanticLabel: '${ingredientName(k)} 성분 설명 보기',
      onTap: () => showIngredientSheet(context, k),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ingredientName(k),
              style: st(11.5, w: w600, c: fg),
            ),
            const SizedBox(width: 4),
            SmIcon(Ic.info, size: 10, color: fg, strokeWidth: 2.6),
          ],
        ),
      ),
    );
  }
}

/// "단계 추가 / 화장대에서 추가" 줄
class AddStepRow extends ConsumerWidget {
  const AddStepRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Center(
            child: DashedBorder(
              color: SM.slate300,
              radius: 14,
              dash: 3,
              gap: 3,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const SmIcon(Ic.plus, size: 14, color: SM.inkSub, strokeWidth: 2.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            onTap: () => ref.read(routineProvider.notifier).addStep(),
            child: DashedBorder(
              color: SM.slate300,
              radius: 16,
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    '단계 추가',
                    style: st(14, w: w600, c: SM.ink700),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            onTap: () => showPickerSheet(context, ref, targetId: null),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: SM.primaryBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SM.primaryLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SmIcon(Ic.bottle, size: 15, color: SM.primaryTx, strokeWidth: 1.9),
                  const SizedBox(width: 6),
                  Text(
                    '화장대에서 추가',
                    style: st(14, w: w600, c: SM.primaryTx),
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

/// 검색칸 오른쪽의 작은 흰 버튼 (사진 입력)
class _FieldIconBtn extends StatelessWidget {
  const _FieldIconBtn({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x140F172A), offset: Offset(0, 1), blurRadius: 2)],
        ),
        child: SmIcon(icon, size: 17, strokeWidth: 1.9),
      ),
    ),
  );
}

/// 제품 사진. 사진이 없거나 못 불러오면 프로토타입의 줄무늬 상자를 보여 줘요.
class ProductThumb extends StatelessWidget {
  const ProductThumb(this.p, {super.key, required this.size, required this.radius, this.stripe = 6, this.base});
  final Product p;
  final double size;
  final double radius;
  final double stripe;
  final Color? base;

  @override
  Widget build(BuildContext context) {
    final fallback = StripeBox(
      tint: SM.tint(p.category),
      stripe: stripe,
      width: size,
      height: size,
      radius: radius,
      base: base ?? SM.surface,
    );
    final url = p.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SM.border),
      ),
      child: Image.network(url, fit: BoxFit.cover, semanticLabel: '${p.brand} ${p.name} 사진', errorBuilder: (_, _, _) => fallback),
    );
  }
}
