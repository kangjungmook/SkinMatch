import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../models/product.dart';
import '../models/routine_result.dart';
import '../models/routine_step.dart';
import '../models/skin_profile.dart';
import 'ingredient_db.dart';

/// 루틴 성분 충돌 분석기.
///
/// 프로토타입(SkinMatch.dc.html)의 `compute()` 규칙을 그대로 옮겼어요.
/// 나중에 AI 서버로 바꿔도 입력(steps, profile)과 출력(RoutineResult)은 유지하세요.
class AnalyzerEngine {
  const AnalyzerEngine();

  static const _acids = ['aha', 'bha', 'pha'];
  static const _pmKeys = ['retinol', 'aha', 'bha', 'pha', 'bpo'];

  /// 첫 줄을 제품 라벨로 써요. 전성분만 붙여넣은 경우엔 카테고리 이름을 써요.
  static String labelOf(String text, String fallback) {
    final first = text.trim().split('\n').first.trim();
    if (first.isEmpty || (first.contains(',') && first.split(',').length > 2)) return fallback;
    return first.length > 22 ? '${first.substring(0, 21)}…' : first;
  }

  /// 두 제품 조합의 위험도 (2~95)
  static ({int risk, List<ClashRule> hits}) pairEval(List<String> a, List<String> b) {
    final hits = kClashRules.where((p) => (a.contains(p.x) && b.contains(p.y)) || (a.contains(p.y) && b.contains(p.x))).toList();
    final soothe = kSoothe.where((k) => a.contains(k) || b.contains(k)).length;
    double risk;
    if (hits.isNotEmpty) {
      final ws = hits.map((h) => h.weight).toList()..sort((x, y) => y - x);
      risk = 12 + ws.first + ws.skip(1).fold<double>(0, (s, w) => s + w * 0.3) - math.min(soothe * 5, 10);
    } else {
      risk = 4.0 + kActive.where((k) => a.contains(k) || b.contains(k)).length * 4 - soothe * 2;
    }
    return (risk: _round(risk.clamp(2, 95).toDouble()), hits: hits);
  }

  RoutineResult analyze(List<RoutineStep> steps, SkinProfile profile) {
    final adjust = <String>[];
    final filled = steps.where((s) => s.isFilled).toList();
    final base = <AnalyzedProduct>[
      for (var i = 0; i < filled.length; i++)
        AnalyzedProduct(
          n: i + 1,
          category: filled[i].category,
          label: labelOf(filled[i].text, filled[i].category),
          keys: detectIngredients(filled[i].text),
          slot: 'BOTH',
          stepId: filled[i].id,
        ),
    ];
    final all = <String>{for (final p in base) ...p.keys}.toList();

    final pairs = <PairResult>[];
    for (var i = 0; i < base.length; i++) {
      for (var j = i + 1; j < base.length; j++) {
        final e = pairEval(base[i].keys, base[j].keys);
        pairs.add(PairResult(i, j, e.risk, e.hits));
      }
    }
    // JS Array.sort는 안정 정렬이라 동률일 때 입력 순서를 유지해요. Dart에서도 mergeSort로 맞춰요.
    final sorted = [...pairs];
    mergeSort<PairResult>(sorted, compare: (x, y) => y.risk - x.risk);
    final top = sorted.isEmpty ? 0 : sorted.first.risk;
    final anyHit = pairs.any((p) => p.hits.isNotEmpty);

    double risk = top + sorted.skip(1).where((p) => p.risk > 30).fold<double>(0, (s, p) => s + p.risk * 0.12);
    final activeProducts = base.where((p) => p.keys.any((k) => _pmKeys.contains(k) || k == 'vitc')).length;
    if (activeProducts >= 3) risk += 5;
    if (anyHit) {
      if (profile.isSensitive) {
        risk += 8;
        adjust.add('민감 피부 +8');
      }
      if (profile.baseType == '지성') {
        risk -= 3;
        adjust.add('지성 -3');
      }
      if (profile.baseType == '건성') {
        risk += 2;
        adjust.add('건성 +2');
      }
      final allHits = pairs.expand((p) => p.hits).toList();
      if (profile.history.contains('acid') && allHits.any((h) => _acids.contains(h.x) || _acids.contains(h.y))) {
        risk += 5;
        adjust.add('산성분 자극 이력 +5');
      }
      if (profile.history.contains('noRetinol') && allHits.any((h) => h.x == 'retinol')) {
        risk += 5;
        adjust.add('레티놀 첫 사용 +5');
      }
    }
    if (profile.history.contains('procedure') && all.any(kActive.contains)) {
      risk += 6;
      adjust.add('시술 후 회복기 +6');
    }
    final finalRisk = _round(risk.clamp(3, 97).toDouble());
    final band = bandOf(finalRisk);

    final tags = <Tag>[];
    final seen = <String>{};
    for (final p in sorted) {
      for (final h in p.hits) {
        for (final t in h.tags) {
          if (seen.add(t)) tags.add(Tag(t, h.caution ? TagKind.caution : TagKind.clash));
        }
      }
    }
    if (activeProducts >= 3) tags.add(const Tag('#액티브_과다_레이어링', TagKind.caution));
    final hasSun = base.any((p) => p.category == '선크림' || p.keys.contains('uvf'));
    if (!hasSun && all.any(['retinol', 'aha', 'bha', 'pha', 'vitc'].contains)) {
      tags.add(const Tag('#선크림_누락_광민감', TagKind.caution));
    }
    if (kSoothe.any(all.contains)) tags.add(const Tag('#보습_시너지', TagKind.good));
    if (all.contains('ceramide') || all.contains('cica')) tags.add(const Tag('#피부장벽_강화', TagKind.good));
    if (tags.isEmpty) tags.add(const Tag('#특이_충돌_없음', TagKind.good));

    final products = [
      for (final p in base)
        AnalyzedProduct(
          n: p.n,
          category: p.category,
          label: p.label,
          keys: p.keys,
          stepId: p.stepId,
          slot: (p.category == '선크림' || p.category == '메이크업')
              ? 'AM'
              : p.keys.any(_pmKeys.contains)
              ? 'PM'
              : p.keys.contains('vitc')
              ? 'AM'
              : 'BOTH',
        ),
    ];

    List<AnalyzedProduct> ord(List<AnalyzedProduct> list) {
      final out = [...list];
      mergeSort<AnalyzedProduct>(
        out,
        compare: (a, b) {
          final c = (kCategoryOrder[a.category] ?? 4.5).compareTo(kCategoryOrder[b.category] ?? 4.5);
          return c != 0 ? c : a.n - b.n;
        },
      );
      return out;
    }

    final ordered = ord(products);
    final reordered = ordered.indexed.any((e) => e.$2.n != e.$1 + 1);
    final am = ordered.where((p) => p.slot != 'PM').toList();
    if (!hasSun) {
      am.add(const AnalyzedProduct(n: 0, label: '선크림 SPF50+ 추가 권장', category: '선크림', keys: [], slot: 'AM', ghost: true));
    }
    final pm = ordered.where((p) => p.slot != 'AM').toList();
    int rb(AnalyzedProduct a, AnalyzedProduct b) {
      final q = pairs.firstWhereOrNull((x) => (x.i == a.n - 1 && x.j == b.n - 1) || (x.i == b.n - 1 && x.j == a.n - 1));
      return q?.risk ?? 0;
    }

    final dayA = <AnalyzedProduct>[], dayB = <AnalyzedProduct>[];
    for (final p in pm.where((p) => p.slot == 'PM')) {
      (dayA.any((q) => rb(p, q) > 50) ? dayB : dayA).add(p);
    }
    final basics = pm.where((p) => p.slot == 'BOTH').toList();
    final split = dayB.isNotEmpty;
    final night = split
        ? [
            NightGroup('Day A · 첫째 날', ord([...dayA, ...basics])),
            NightGroup('Day B · 둘째 날', ord([...dayB, ...basics])),
          ]
        : [NightGroup('매일 저녁', pm)];
    final tip = split
        ? '격일(하루 걸러 하루) 사용을 권장합니다.'
        : band == RiskBand.mid
        ? '강한 액티브는 흡수 후 15~20분 뒤 다음 단계를 바르세요.'
        : band == RiskBand.high
        ? '자극 성분은 한 번에 하나만, 보습으로 마무리하세요.'
        : '매일 사용해도 좋은 안심 루틴입니다.';

    final warns = <String>[];
    if (profile.pregnancyAlert && (all.contains('retinol') || all.contains('bha'))) {
      warns.add('임산부/수유부 주의 성분이 포함되어 있어요.');
    }
    if (profile.history.contains('rx') && all.any(['retinol', 'aha', 'bha', 'bpo'].contains)) {
      warns.add('처방약과 겹칠 수 있는 액티브 성분이 있어요.');
    }
    final warning = warns.isEmpty ? '' : '${warns.join(' ')} 사용 전 전문의와 상담하세요.';

    return RoutineResult(
      risk: finalRisk,
      band: band,
      tags: tags,
      products: products,
      pairs: pairs,
      sorted: sorted,
      morning: am,
      night: night,
      split: split,
      tip: tip,
      warning: warning,
      adjustments: adjust,
      reordered: reordered,
    );
  }

  /// 가장 큰 충돌이 50%를 넘으면, 그 조합의 두 제품 중 하나를 같은 카테고리의 더 순한 제품으로 바꿔 보는 추천.
  AlternativeSuggestion? suggestAlternatives(RoutineResult r, List<Product> candidates) {
    if (r.sorted.isEmpty || r.sorted.first.risk <= 50) return null;
    final q = r.sorted.first;
    AlternativeSuggestion? best;
    for (final k in [q.i, q.j]) {
      final target = r.products[k];
      final others = [
        for (var i = 0; i < r.products.length; i++)
          if (i != k) r.products[i],
      ];
      final cands = [
        for (final c in candidates.where((c) => c.category == target.category && !target.label.contains(c.name)))
          (product: c, worst: others.fold<int>(0, (m, o) => math.max(m, pairEval(detectIngredients(c.routineText), o.keys).risk))),
      ].where((x) => x.worst < q.risk - 15).toList();
      mergeSort<({Product product, int worst})>(cands, compare: (a, b) => a.worst - b.worst);
      final top2 = cands.take(2).toList();
      if (top2.isNotEmpty && (best == null || top2.first.worst < best.items.first.worst)) {
        best = AlternativeSuggestion(
          index: k,
          stepId: target.stepId!,
          title: '${k + 1}번 ${target.label} 대신 쓰면 가장 큰 충돌(${q.risk}%)을 줄일 수 있어요.',
          items: top2,
        );
      }
    }
    return best;
  }

  /// JS Math.round와 같은 반올림 (.5는 +방향)
  static int _round(double v) => (v + 0.5).floor();
}

class AlternativeSuggestion {
  const AlternativeSuggestion({required this.index, required this.stepId, required this.title, required this.items});
  final int index;
  final String stepId;
  final String title;
  final List<({Product product, int worst})> items;
}
