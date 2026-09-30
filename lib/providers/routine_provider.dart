import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analyzer_engine.dart';
import '../core/ingredient_db.dart';
import '../core/sample_data.dart';
import '../models/product.dart';
import '../models/routine_result.dart';
import '../models/routine_step.dart';
import 'core_providers.dart';
import 'session_provider.dart';
import 'vanity_provider.dart';

class RoutineState {
  const RoutineState({required this.steps, this.analyzing = false, this.result, this.saved = false, this.alternative, this.runId = 0});

  final List<RoutineStep> steps;
  final bool analyzing;
  final RoutineResult? result;
  final bool saved;
  final AlternativeSuggestion? alternative;

  /// 분석할 때마다 1씩 올라가요 (게이지 애니메이션 재시작용)
  final int runId;

  List<RoutineStep> get filled => steps.where((s) => s.isFilled).toList();

  RoutineState copyWith({
    List<RoutineStep>? steps,
    bool? analyzing,
    RoutineResult? result,
    bool clearResult = false,
    bool? saved,
    AlternativeSuggestion? alternative,
    bool clearAlternative = false,
    int? runId,
  }) => RoutineState(
    steps: steps ?? this.steps,
    analyzing: analyzing ?? this.analyzing,
    result: clearResult ? null : (result ?? this.result),
    saved: saved ?? this.saved,
    alternative: clearAlternative ? null : (alternative ?? this.alternative),
    runId: runId ?? this.runId,
  );
}

/// 분석 탭: 루틴 단계 쌓기 → 분석 → 결과
class RoutineNotifier extends Notifier<RoutineState> {
  static const maxSteps = 8;
  int _uid = 0;
  Timer? _timer;

  RoutineStep mk(String category, [String text = '', Product? product]) {
    _uid += 1;
    return RoutineStep(id: 's$_uid', category: category, text: text, product: product);
  }

  @override
  RoutineState build() {
    ref.onDispose(() => _timer?.cancel());
    // 로그아웃하면 루틴을 초기화해요.
    ref.listen(sessionProvider.select((s) => s.user?.uid), (prev, next) {
      if (prev != next) {
        _timer?.cancel();
        state = RoutineState(steps: [mk('토너'), mk('크림')]);
      }
    });
    return RoutineState(steps: [mk('토너'), mk('크림')]);
  }

  void _toast(String m) => ref.read(toastProvider.notifier).show(m);

  void _update(String id, RoutineStep Function(RoutineStep) f) {
    state = state.copyWith(steps: [for (final s in state.steps) s.id == id ? f(s) : s]);
  }

  void setCategory(String id, String cat) => _update(id, (s) => s.copyWith(category: cat));
  void setText(String id, String text) => _update(id, (s) => s.copyWith(text: text));

  void pickProduct(String id, Product p) =>
      _update(id, (s) => s.copyWith(product: p, category: p.category, text: p.routineText, manual: false));

  void clearProduct(String id) => _update(id, (s) => s.copyWith(clearProduct: true, text: '', manual: false));

  void manualMode(String id) => _update(id, (s) => s.copyWith(manual: true, clearProduct: true));

  void searchMode(String id) => _update(id, (s) => s.copyWith(manual: false, text: ''));

  void pasteText(String id, String text) => _update(id, (s) => s.copyWith(text: text, manual: true, clearProduct: true));

  void move(String id, int dir) {
    final s = [...state.steps];
    final i = s.indexWhere((x) => x.id == id);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= s.length) return;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
    state = state.copyWith(steps: s);
  }

  void remove(String id) {
    if (state.steps.length <= 1) return;
    state = state.copyWith(steps: state.steps.where((x) => x.id != id).toList());
  }

  void addStep() {
    if (state.steps.length >= maxSteps) return _toast('루틴은 최대 8단계까지 추가할 수 있어요');
    final last = state.steps.isEmpty ? null : state.steps.last;
    final next = kNextCategory[last?.category] ?? '기타';
    state = state.copyWith(steps: [...state.steps, mk(next)]);
  }

  void sample() {
    state = state.copyWith(
      steps: [
        for (final id in kSampleRoutineIds)
          () {
            final p = kSampleCatalog.firstWhere((x) => x.id == id);
            return mk(p.category, p.routineText, p);
          }(),
      ],
    );
  }

  void clearAll() => state = state.copyWith(steps: [mk('토너'), mk('크림')]);

  /// 화장대 제품을 루틴에 넣어요. [targetId]가 없으면 첫 빈 단계, 없으면 새 단계.
  void addFromVanity(Product p, String? targetId) {
    final steps = [...state.steps];
    final idx = targetId != null ? steps.indexWhere((x) => x.id == targetId) : steps.indexWhere((x) => !x.isFilled);
    if (idx >= 0) {
      steps[idx] = steps[idx].copyWith(category: p.category, text: p.routineText, product: p, manual: false);
    } else if (steps.length < maxSteps) {
      steps.add(mk(p.category, p.routineText, p));
    }
    _timer?.cancel();
    state = state.copyWith(steps: steps, clearResult: true, analyzing: false, clearAlternative: true);
    _toast('루틴에 추가했어요');
  }

  void analyze() {
    if (state.filled.length < 2) return _toast('제품을 2개 이상 입력해 주세요');
    state = state.copyWith(analyzing: true, clearResult: true, saved: false, clearAlternative: true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), finish);
  }

  void finish() {
    final profile = ref.read(sessionProvider).profile;
    final engine = ref.read(analyzerEngineProvider);
    final r = engine.analyze(state.steps, profile);
    final snap = [for (final s in state.filled) s];
    final run = state.runId + 1;
    state = state.copyWith(analyzing: false, result: r, saved: false, clearAlternative: true, runId: run);
    ref
        .read(vanityProvider.notifier)
        .pushRecent(
          SavedRoutine(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            steps: snap,
            risk: r.risk,
            band: r.band,
            labels: r.products.map((p) => p.label).toList(),
            at: DateTime.now(),
          ),
        );
    unawaited(_loadAlternatives(r, run));
  }

  Future<void> _loadAlternatives(RoutineResult r, int run) async {
    if (r.sorted.isEmpty || r.sorted.first.risk <= 50) return;
    final repo = ref.read(productRepositoryProvider);
    final q = r.sorted.first;
    final cats = {r.products[q.i].category, r.products[q.j].category};
    try {
      final lists = await Future.wait(cats.map(repo.byCategory));
      final alt = ref.read(analyzerEngineProvider).suggestAlternatives(r, [for (final l in lists) ...l]);
      if (alt != null && state.runId == run) state = state.copyWith(alternative: alt);
    } catch (_) {
      // 추천은 부가 기능이라 실패해도 결과 화면은 그대로 보여 줘요.
    }
  }

  void swap(String stepId, Product p) {
    pickProduct(stepId, p);
    _toast('제품을 교체하고 다시 분석했어요');
    finish();
  }

  void loadSnapshot(List<RoutineStep> steps) {
    _timer?.cancel();
    state = state.copyWith(steps: [for (final s in steps) mk(s.category, s.text, s.product)]);
    finish();
  }

  void backToInput() {
    _timer?.cancel();
    state = state.copyWith(clearResult: true, analyzing: false, clearAlternative: true);
  }

  SavedRoutine? save() {
    final r = state.result;
    if (state.saved || r == null) return null;
    final saved = SavedRoutine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      steps: state.filled,
      risk: r.risk,
      band: r.band,
      labels: r.products.map((p) => p.label).toList(),
      at: DateTime.now(),
    );
    state = state.copyWith(saved: true);
    ref.read(vanityProvider.notifier).saveCombo(saved);
    _toast('내 화장대에 루틴을 저장했어요');
    return saved;
  }
}

final routineProvider = NotifierProvider<RoutineNotifier, RoutineState>(RoutineNotifier.new);
