import 'dart:math' as math;

import 'ingredient_db.dart';

/// 인식 결과 한 성분의 상태
enum MatchStatus {
  /// 사전과 정확히 일치
  exact,

  /// 오타로 보여서 가장 가까운 성분으로 고침 (사용자 확인 권장)
  corrected,

  /// 사전에 없음 (사용자 확인 필요)
  unknown,
}

class ParsedIngredient {
  const ParsedIngredient({required this.raw, required this.name, required this.status, this.candidates = const [], this.keyActive = false});

  /// 사진에서 읽은 그대로의 글자
  final String raw;

  /// 확정(또는 교정)된 성분명
  final String name;
  final MatchStatus status;

  /// 교정 후보 (가까운 순)
  final List<String> candidates;

  /// 레티놀·AHA처럼 충돌 분석에 중요한 성분인지. 교정된 경우엔 꼭 확인받아요.
  final bool keyActive;

  bool get needsReview => status != MatchStatus.exact;

  ParsedIngredient copyWith({String? name, MatchStatus? status}) => ParsedIngredient(
    raw: raw,
    name: name ?? this.name,
    status: status ?? this.status,
    candidates: candidates,
    keyActive: detectIngredients(name ?? this.name).isNotEmpty,
  );
}

class ParsedLabel {
  const ParsedLabel({required this.section, required this.items, required this.foundHeader});

  /// 전성분 부분으로 잘라낸 원문
  final String section;
  final List<ParsedIngredient> items;

  /// "전성분" 제목을 찾았는지 (못 찾으면 전체 글자를 썼어요)
  final bool foundHeader;

  int get reviewCount => items.where((i) => i.needsReview).length;
}

/// 성분 사전. 표준명과 이명(다른 이름)을 담아요.
///
/// 지금은 앱에 들어 있는 기본 사전(assets/data/ingredient_dictionary.json)을 쓰고,
/// 식약처 원료성분정보를 내려받으면 그 사전으로 바꿔요 (tool/fetch_mfds_ingredients.dart).
class IngredientDictionary {
  IngredientDictionary({required Iterable<String> names, Map<String, String> synonyms = const {}}) {
    for (final n in names) {
      _add(n, n);
    }
    synonyms.forEach(_add);
  }

  /// 정규화된 글자 → 표준명
  final Map<String, String> _lookup = {};

  /// 두 글자 조각 → 정규화된 글자들 (비슷한 후보를 빨리 찾기 위한 색인)
  final Map<String, Set<String>> _bigrams = {};

  int get size => _lookup.length;

  void _add(String alias, String standard) {
    final k = normalize(alias);
    if (k.isEmpty) return;
    _lookup.putIfAbsent(k, () => standard);
    for (final g in _grams(k)) {
      (_bigrams[g] ??= {}).add(k);
    }
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> j) => IngredientDictionary(
    names: List<String>.from(j['names'] as List),
    synonyms: Map<String, String>.from((j['synonyms'] as Map?) ?? const {}),
  );

  /// 비교용 정규화: 공백·가운뎃점 제거, 소문자, 흔한 OCR 혼동 문자 통일
  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\s·ㆍ•∙\-‐–—_/\\|.]'), '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll(RegExp(r'[()\[\]{}]'), '');

  static Iterable<String> _grams(String s) sync* {
    if (s.length < 2) {
      yield s;
      return;
    }
    for (var i = 0; i < s.length - 1; i++) {
      yield s.substring(i, i + 2);
    }
  }

  String? exact(String s) => _lookup[normalize(s)];

  /// 가까운 표준명 후보 (자모 단위 편집 거리 비율이 낮은 순)
  List<({String name, double score})> nearest(String s, {int limit = 3}) {
    final k = normalize(s);
    if (k.isEmpty) return const [];
    final pool = <String>{};
    for (final g in _grams(k)) {
      pool.addAll(_bigrams[g] ?? const {});
    }
    final kj = _jamo(k);
    final scored = <({String name, double score})>[];
    final seen = <String>{};
    for (final cand in pool) {
      if ((cand.length - k.length).abs() > math.max(2, k.length * .4)) continue;
      final cj = _jamo(cand);
      final d = _levenshtein(kj, cj) / math.max(kj.length, cj.length);
      final std = _lookup[cand]!;
      if (seen.add(std)) scored.add((name: std, score: d));
    }
    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.take(limit).toList();
  }

  /// 한글 음절을 초성·중성·종성으로 풀어요. "트"와 "드"처럼 한 획 차이를 작은 오류로 보기 위해서예요.
  static List<int> _jamo(String s) {
    final out = <int>[];
    for (final r in s.runes) {
      if (r >= 0xAC00 && r <= 0xD7A3) {
        final x = r - 0xAC00;
        out
          ..add(0x1100 + x ~/ 588)
          ..add(0x1161 + (x % 588) ~/ 28);
        if (x % 28 != 0) out.add(0x11A7 + x % 28);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  static int _levenshtein(List<int> a, List<int> b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

/// 제품 뒷면 사진에서 읽은 글자를 전성분 목록으로 정리해요.
class LabelParser {
  const LabelParser(this.dict);

  final IngredientDictionary dict;

  /// 이 비율 이하의 차이면 오타로 보고 고쳐요 (자모 기준).
  static const correctThreshold = .34;

  static final _header = RegExp(r'(전\s*성\s*분|\[?\s*성\s*분\s*\]?|ingredients?)\s*[:：\]\)]?', caseSensitive: false);
  static final _stop = RegExp(
    r'(사용\s*(할\s*때|시)의?\s*주의\s*사항|주의\s*사항|사용\s*방법|사용법|내\s*용\s*량|용\s*량|제조\s*번호|사용\s*기한|개봉\s*후|'
    r'제조\s*업자|책임\s*판매\s*업자|제조\s*판매|보관\s*방법|원산지|made\s*in|유통\s*기한|소비자\s*상담|고객\s*센터)',
    caseSensitive: false,
  );

  ParsedLabel parse(String ocrText) {
    var text = ocrText.replaceAll('\r', '');
    var found = false;
    // "전성분"을 먼저 찾고, 없으면 "성분" / "Ingredients"를 찾아요.
    final full = RegExp(r'전\s*성\s*분\s*[:：\]\)]?').firstMatch(text);
    final m = full ?? _header.firstMatch(text);
    if (m != null) {
      text = text.substring(m.end);
      found = true;
    }
    final stop = _stop.firstMatch(text);
    if (stop != null) text = text.substring(0, stop.start);
    final section = text.trim();

    final tokens = splitIngredients(section);
    final items = <ParsedIngredient>[];
    for (final t in tokens) {
      items.addAll(_resolve(t));
    }
    return ParsedLabel(section: section, items: items, foundHeader: found);
  }

  /// 줄바꿈으로 끊긴 이름을 잇고 쉼표로 나눠요. "1,2-헥산다이올"처럼 숫자 사이 쉼표는 나누지 않아요.
  static List<String> splitIngredients(String section) {
    final joined = section
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n')
        // 쉼표로 끝난 줄은 그냥 붙이고, 아니면 단어가 끊긴 것으로 보고 붙여요.
        .replaceAll(RegExp(r',\s*\n'), ',')
        .replaceAll('\n', '');
    // 양쪽이 모두 숫자인 쉼표("1,2-헥산다이올")만 빼고 나눠요.
    final parts = joined.split(RegExp(r'[,，、;](?!\d)|(?<!\d)[,，、;]'));
    return parts.map(_clean).where((s) => s.isNotEmpty).toList();
  }

  /// 농도 표기·괄호 속 설명·끝의 마침표를 떼요.
  static String _clean(String s) => s
      .trim()
      .replaceAll(RegExp(r'\(\s*\d+(\.\d+)?\s*%?\s*\)'), '')
      .replaceAll(RegExp(r'\s*\d+(\.\d+)?\s*%'), '')
      .replaceAll(RegExp(r'^[\s\-•·*:]+|[\s.。*]+$'), '')
      .trim();

  List<ParsedIngredient> _resolve(String raw) {
    final hit = dict.exact(raw);
    if (hit != null) return [ParsedIngredient(raw: raw, name: hit, status: MatchStatus.exact, keyActive: _key(hit))];

    // 쉼표가 빠져 두 성분이 붙은 경우 ("글리세린부틸렌글라이콜")
    final n = IngredientDictionary.normalize(raw);
    for (var i = 2; i <= n.length - 2; i++) {
      final a = dict.exact(n.substring(0, i)), b = dict.exact(n.substring(i));
      if (a != null && b != null) {
        return [
          ParsedIngredient(raw: raw, name: a, status: MatchStatus.corrected, candidates: [a], keyActive: _key(a)),
          ParsedIngredient(raw: raw, name: b, status: MatchStatus.corrected, candidates: [b], keyActive: _key(b)),
        ];
      }
    }

    final near = dict.nearest(raw);
    final cands = near.map((e) => e.name).toList();
    if (near.isNotEmpty && near.first.score <= correctThreshold) {
      final best = near.first.name;
      return [ParsedIngredient(raw: raw, name: best, status: MatchStatus.corrected, candidates: cands, keyActive: _key(best) || _key(raw))];
    }
    return [ParsedIngredient(raw: raw, name: raw, status: MatchStatus.unknown, candidates: cands, keyActive: _key(raw) || cands.any(_key))];
  }

  static bool _key(String s) => detectIngredients(s).any(kActive.contains);
}
