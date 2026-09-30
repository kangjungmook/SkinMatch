import '../../models/skin_profile.dart';

typedef Option = ({String key, String desc});

const List<Option> kBaseTypes = [
  (key: '건성', desc: '세안 후 당기고, 오후에도 각질이 일어나요'),
  (key: '지성', desc: 'T존과 볼 모두 번들거리고 모공이 눈에 띄어요'),
  (key: '복합성', desc: 'T존은 번들거리고, 볼은 건조하거나 편안해요'),
  (key: '중성', desc: '유수분 균형이 좋아 특별한 불편이 적어요'),
];

const List<({String text, String type})> kQuiz = [
  (text: '전체적으로 당겨요', type: '건성'),
  (text: '전체가 번들거려요', type: '지성'),
  (text: 'T존만 번들거려요', type: '복합성'),
  (text: '편안하고 촉촉해요', type: '중성'),
];

const List<Option> kConcerns = [
  (key: '민감성/홍조', desc: '쉽게 붉어지고 화끈거려요'),
  (key: '여드름·트러블', desc: '좁쌀·화농성 트러블이 자주 나요'),
  (key: '장벽손상', desc: '평소 쓰던 제품도 따가울 때가 있어요'),
  (key: '색소침착·잡티', desc: '트러블 자국, 기미가 고민이에요'),
  (key: '모공·피지', desc: '피지가 많고 모공이 넓어 보여요'),
  (key: '주름·탄력', desc: '잔주름, 탄력 저하가 고민이에요'),
];

const List<({String label, String desc})> kSensitivity = [
  (label: '거의 없음', desc: '대부분의 제품을 문제없이 사용해요.'),
  (label: '가끔', desc: '고농도 액티브 성분에서만 가끔 반응이 있어요.'),
  (label: '보통', desc: '새 제품은 테스트 후 사용하는 편이에요.'),
  (label: '자주', desc: '새 제품에서 따가움·붉어짐을 자주 느껴요. 자극도를 높여 보정해요.'),
  (label: '거의 항상', desc: '대부분의 새 제품에 반응해요. 자극도를 높여 보정해요.'),
];

const List<({String key, String short, String text})> kHistory = [
  (key: 'acid', short: '산성분 따가움', text: 'AHA·BHA 등 산성분에 따가움을 느낀 적 있어요'),
  (key: 'noRetinol', short: '레티놀 첫 사용', text: '레티놀을 아직 써본 적 없어요'),
  (key: 'procedure', short: '최근 시술', text: '2주 이내 레이저·필링 시술을 받았어요'),
  (key: 'rx', short: '처방약 사용', text: '피부과 처방 연고·약을 사용 중이에요'),
];

/// 피부 프로필 요약 (진단 3단계 · 마이페이지)
List<(String, String)> profileRows(SkinProfile p) {
  final cautions = [
    for (final h in kHistory)
      if (p.history.contains(h.key)) h.short,
    if (p.pregnancyAlert) '임산부 알림',
  ];
  return [
    ('기본 타입', p.baseType ?? '미설정'),
    ('피부 고민', p.concerns.isEmpty ? '없음' : p.concerns.join(', ')),
    ('자극 민감도', p.sensitivity > 0 ? '${p.sensitivity} / 5 · ${kSensitivity[p.sensitivity - 1].label}' : '미설정'),
    ('주의 사항', cautions.isEmpty ? '없음' : cautions.join(', ')),
  ];
}

/// 분석 시 어떤 보정이 들어가는지 미리 보여 주는 문구
String adjustPreview(SkinProfile p) {
  final pv = [
    if (p.isSensitive) '민감 피부 +8',
    if (p.baseType == '지성') '지성 -3',
    if (p.baseType == '건성') '건성 +2',
    if (p.history.contains('acid')) '산성분 이력 +5',
    if (p.history.contains('noRetinol')) '레티놀 첫 사용 +5',
    if (p.history.contains('procedure')) '시술 후 +6',
  ];
  return pv.isEmpty ? '특별한 보정 없이 기본 기준으로 분석해요.' : '분석 시 반영: ${pv.join(' · ')}';
}

/// 홈 인사말 아래 한 줄 요약
String skinSummary(SkinProfile p) => p.baseType == null
    ? '피부 타입 미설정 · 설정하기'
    : '내 피부 · ${[p.baseType!, ...p.concerns].join(' · ')}${p.sensitivity > 0 ? ' · 민감도 ${p.sensitivity}' : ''}';
