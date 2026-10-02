import '../models/routine_result.dart';

/// 성분 인식 규칙. 텍스트는 소문자로 바꾼 뒤 비교해요.
class IngredientPattern {
  const IngredientPattern(this.key, this.name, this.pattern);
  final String key;
  final String name;
  final RegExp pattern;
}

final List<IngredientPattern> kIngredients = [
  IngredientPattern('retinol', '레티놀', RegExp(r'레티놀|레티날|레티노이드|트레티노인|retinol|retinal|retinoid|tretinoin')),
  IngredientPattern('aha', 'AHA', RegExp(r'\baha\b|글리콜릭|글라이콜릭|락틱|만델릭|glycolic|lactic|mandelic')),
  IngredientPattern('bha', 'BHA', RegExp(r'\bbha\b|살리실|salicylic')),
  IngredientPattern('pha', 'PHA', RegExp(r'\bpha\b|글루코노락톤|락토바이오닉|gluconolactone')),
  IngredientPattern('vitc', '비타민C', RegExp(r'비타민\s?c|아스코빅|아스코르빅|ascorbic|vitamin\s?c')),
  IngredientPattern('bpo', '벤조일퍼옥사이드', RegExp(r'벤조일|benzoyl')),
  IngredientPattern('niacin', '나이아신아마이드', RegExp(r'나이아신|niacinamide')),
  IngredientPattern('copper', '구리펩타이드', RegExp(r'구리\s?펩타이드|copper\s?peptide')),
  IngredientPattern('ceramide', '세라마이드', RegExp(r'세라마이드|ceramide')),
  IngredientPattern('ha', '히알루론산', RegExp(r'히알루론|hyaluron')),
  IngredientPattern('panthenol', '판테놀', RegExp(r'판테놀|panthenol')),
  IngredientPattern('cica', '시카', RegExp(r'시카|병풀|센텔라|마데카|cica|centella')),
  IngredientPattern('uvf', '자외선 차단', RegExp(r'징크\s?옥사이드|티타늄\s?디옥사이드|zinc\s?oxide|titanium\s?dioxide|spf\s?\d|자외선\s?차단')),
];

const List<String> kActive = ['retinol', 'aha', 'bha', 'pha', 'vitc', 'bpo', 'niacin', 'copper'];
const List<String> kSoothe = ['ceramide', 'ha', 'panthenol', 'cica'];

const List<ClashRule> kClashRules = [
  ClashRule('retinol', 'aha', 72, ['#레티놀_AHA_산성충돌', '#각질박리_과다', '#피부장벽_손상위험']),
  ClashRule('retinol', 'bha', 62, ['#레티놀_BHA_과자극', '#피부장벽_손상위험']),
  ClashRule('retinol', 'bpo', 66, ['#레티놀_벤조일_산화불활성', '#건조_자극']),
  ClashRule('retinol', 'vitc', 38, ['#레티놀_비타민C_pH충돌']),
  ClashRule('retinol', 'pha', 34, ['#레티놀_PHA_각질자극']),
  ClashRule('aha', 'bha', 44, ['#이중산_각질박리_과다']),
  ClashRule('aha', 'vitc', 30, ['#저pH_중첩자극']),
  ClashRule('bha', 'vitc', 28, ['#저pH_중첩자극']),
  ClashRule('vitc', 'bpo', 34, ['#비타민C_산화']),
  ClashRule('vitc', 'copper', 26, ['#비타민C_구리펩타이드_불활성']),
  ClashRule('vitc', 'niacin', 10, ['#고농도시_홍조가능'], caution: true),
  ClashRule('retinol', 'retinol', 32, ['#레티노이드_중복']),
  ClashRule('aha', 'aha', 22, ['#산성분_중복']),
];

/// 권장 순서 정렬 기준 (묽은 제형 → 꾸덕한 제형 → 선크림 → 메이크업)
const Map<String, double> kCategoryOrder = {'토너': 1, '에센스·앰플': 2, '세럼': 3, '아이크림': 4, '기타': 4.5, '크림': 5, '선크림': 6, '메이크업': 7};

const List<String> kStepCategories = ['토너', '에센스·앰플', '세럼', '아이크림', '크림', '선크림', '메이크업', '기타'];

/// 단계 추가 시 다음 카테고리
const Map<String, String> kNextCategory = {'토너': '에센스·앰플', '에센스·앰플': '세럼', '세럼': '크림', '아이크림': '크림', '크림': '선크림'};

const Map<String, String> kPlaceholder = {
  '토너': '예) 글리콜릭애씨드 7%, 판테놀',
  '에센스·앰플': '예) 아스코빅애씨드 15%, 비타민E',
  '세럼': '예) 레티놀 0.1%, 세라마이드NP',
  '아이크림': '예) 펩타이드, 카페인',
  '크림': '예) 병풀추출물, 세라마이드NP',
  '선크림': '예) 징크옥사이드, 나이아신아마이드',
  '메이크업': '예) 쿠션, 톤업크림 성분',
  '기타': '제품명 또는 전성분을 붙여넣어 주세요',
};

const Map<String, List<String>> kQuickSearch = {
  '토너': ['AHA 토너', '병풀 토너'],
  '에센스·앰플': ['비타민C 앰플', '히알루론 앰플'],
  '세럼': ['레티놀 세럼', '나이아신 세럼'],
  '아이크림': ['아이크림'],
  '크림': ['시카 크림', '세라마이드'],
  '선크림': ['무기자차', '선에센스'],
  '메이크업': ['쿠션'],
  '기타': ['스팟 젤'],
};

/// 성분 사전 항목
class IngredientInfo {
  const IngredientInfo(this.grade, this.effect, this.tip, this.goodWith, this.avoidWith);

  /// 안심 성분 | 대체로 안심 | 주의 필요
  final String grade;
  final String effect;
  final String tip;
  final List<String> goodWith;
  final List<String> avoidWith;
}

const Map<String, IngredientInfo> kIngredientInfo = {
  'retinol': IngredientInfo(
    '주의 필요',
    '피부 재생 촉진, 주름·모공 탄력 개선',
    '저녁에만, 주 2~3회 소량부터 시작하세요. 초기 건조·각질은 일시적일 수 있어요.',
    ['세라마이드', '판테놀', '히알루론산'],
    ['AHA · BHA', '벤조일퍼옥사이드', '고농도 비타민C'],
  ),
  'aha': IngredientInfo('주의 필요', '각질 제거, 피부결·톤 개선', '저녁 사용을 권장하고, 다음 날 선크림은 필수예요.', ['히알루론산', '판테놀'], ['레티놀', 'BHA 동시 사용', '비타민C']),
  'bha': IngredientInfo('주의 필요', '모공 속 피지·블랙헤드 케어, 트러블 완화', '건조해질 수 있어 보습을 충분히 해 주세요.', ['나이아신아마이드', '시카'], ['레티놀', 'AHA 동시 사용']),
  'pha': IngredientInfo('주의 필요', '순한 각질 케어, 민감 피부용 필링', '자극은 적지만 레티놀과는 시간차를 두세요.', ['히알루론산', '세라마이드'], ['레티놀']),
  'vitc': IngredientInfo(
    '주의 필요',
    '미백, 항산화, 칙칙함 개선',
    '아침에 바르고 선크림으로 마무리하세요. 갈색으로 변하면 산화된 거예요.',
    ['비타민E', '페룰릭애씨드', '선크림'],
    ['레티놀', 'AHA · BHA', '구리펩타이드'],
  ),
  'bpo': IngredientInfo('주의 필요', '여드름균 살균, 화농성 트러블 케어', '트러블 부위에만 국소 사용하세요. 섬유 탈색에 주의하세요.', ['보습 크림'], ['레티놀', '비타민C']),
  'niacin': IngredientInfo(
    '대체로 안심',
    '피지 조절, 미백, 장벽 강화',
    '대부분의 성분과 잘 맞아요. 고농도는 일시적 홍조가 생길 수 있어요.',
    ['히알루론산', '세라마이드', 'BHA'],
    ['고농도 비타민C (민감 시)'],
  ),
  'copper': IngredientInfo('주의 필요', '탄력 개선, 피부 재생', '산성 성분과 섞이면 효과가 떨어져요.', ['히알루론산', '펩타이드'], ['비타민C', 'AHA · BHA']),
  'ceramide': IngredientInfo('안심 성분', '피부 장벽 강화, 수분 유지', '모든 루틴에 안전하게 더할 수 있어요.', ['레티놀', 'AHA', '판테놀'], ['특별히 없음']),
  'ha': IngredientInfo('안심 성분', '즉각적인 수분 공급', '건조한 환경에선 크림으로 덮어 수분을 가둬 주세요.', ['세라마이드', '비타민C'], ['특별히 없음']),
  'panthenol': IngredientInfo('안심 성분', '진정, 장벽 회복', '자극 성분 사용 후 진정 단계로 좋아요.', ['레티놀', 'AHA · BHA'], ['특별히 없음']),
  'cica': IngredientInfo('안심 성분', '진정, 붉은기 완화', '예민해진 날 단독 사용해도 좋아요.', ['세라마이드', '판테놀'], ['특별히 없음']),
  'uvf': IngredientInfo('안심 성분', '자외선 차단', '2~3시간마다 덧바르고, 외출 15분 전에 발라 주세요.', ['비타민C', '나이아신아마이드'], ['특별히 없음']),
};

List<String> detectIngredients(String text) {
  final t = text.toLowerCase();
  return [
    for (final i in kIngredients)
      if (i.pattern.hasMatch(t)) i.key,
  ];
}

String ingredientName(String key) =>
    kIngredients.firstWhere((i) => i.key == key, orElse: () => IngredientPattern(key, key, RegExp(''))).name;
