import 'routine_step.dart';

enum RiskBand { low, mid, high }

RiskBand bandOf(num risk) => risk <= 30 ? RiskBand.low : (risk <= 70 ? RiskBand.mid : RiskBand.high);

enum TagKind { clash, caution, good }

class Tag {
  const Tag(this.text, this.kind);
  final String text;
  final TagKind kind;
}

/// 충돌 규칙 한 줄 (성분 x × 성분 y).
class ClashRule {
  const ClashRule(this.x, this.y, this.weight, this.tags, {this.caution = false});
  final String x;
  final String y;
  final int weight;
  final List<String> tags;
  final bool caution;
}

/// 분석에 들어간 제품 한 개 (입력 순서 n = 1부터).
class AnalyzedProduct {
  const AnalyzedProduct({
    required this.n,
    required this.category,
    required this.label,
    required this.keys,
    required this.slot,
    this.stepId,
    this.ghost = false,
  });

  final int n;
  final String category;
  final String label;
  final List<String> keys;

  /// AM | PM | BOTH
  final String slot;
  final String? stepId;

  /// "선크림 SPF50+ 추가 권장"처럼 실제 제품이 아닌 권장 항목
  final bool ghost;
}

class PairResult {
  const PairResult(this.i, this.j, this.risk, this.hits);
  final int i;
  final int j;
  final int risk;
  final List<ClashRule> hits;
}

class NightGroup {
  const NightGroup(this.title, this.items);
  final String title;
  final List<AnalyzedProduct> items;
}

class RoutineResult {
  const RoutineResult({
    required this.risk,
    required this.band,
    required this.tags,
    required this.products,
    required this.pairs,
    required this.sorted,
    required this.morning,
    required this.night,
    required this.split,
    required this.tip,
    required this.warning,
    required this.adjustments,
    required this.reordered,
  });

  final int risk;
  final RiskBand band;
  final List<Tag> tags;
  final List<AnalyzedProduct> products;

  /// 모든 i<j 조합 (입력 순서)
  final List<PairResult> pairs;

  /// 위험도 내림차순 (동률은 입력 순서 유지)
  final List<PairResult> sorted;
  final List<AnalyzedProduct> morning;
  final List<NightGroup> night;
  final bool split;
  final String tip;
  final String warning;
  final List<String> adjustments;
  final bool reordered;

  /// 자극 레벨 1~5
  int get level => (risk / 20).ceil().clamp(1, 5);

  PairResult pairOf(int a, int b) => pairs.firstWhere((p) => (p.i == a && p.j == b) || (p.i == b && p.j == a));
}

/// 저장한 루틴 & 최근 분석
class SavedRoutine {
  const SavedRoutine({
    required this.id,
    required this.steps,
    required this.risk,
    required this.band,
    required this.labels,
    required this.at,
  });

  final String id;
  final List<RoutineStep> steps;
  final int risk;
  final RiskBand band;
  final List<String> labels;
  final DateTime at;

  factory SavedRoutine.fromJson(Map<String, dynamic> j) => SavedRoutine(
    id: j['id'] as String,
    steps: (j['steps'] as List).map((e) => RoutineStep.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    risk: j['risk'] as int,
    band: RiskBand.values.byName(j['band'] as String),
    labels: List<String>.from(j['labels'] as List),
    at: DateTime.parse(j['at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'steps': steps.map((s) => s.toJson()).toList(),
    'risk': risk,
    'band': band.name,
    'labels': labels,
    'at': at.toIso8601String(),
  };
}
