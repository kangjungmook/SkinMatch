import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/core/analyzer_engine.dart';
import 'package:skinmatch/core/sample_data.dart';
import 'package:skinmatch/models/routine_result.dart';
import 'package:skinmatch/models/routine_step.dart';
import 'package:skinmatch/models/skin_profile.dart';

/// 기대값은 프로토타입(SkinMatch.dc.html)의 JS compute()/altVals()를 Node로 실행해 얻은 값이에요.
void main() {
  const engine = AnalyzerEngine();
  var uid = 0;

  List<RoutineStep> fromCatalog(List<String> ids) => [
    for (final id in ids)
      () {
        final p = kSampleCatalog.firstWhere((x) => x.id == id);
        return RoutineStep(id: 's${++uid}', category: p.category, text: p.routineText, product: p);
      }(),
  ];

  String summarize(RoutineResult r) {
    final alt = engine.suggestAlternatives(r, kSampleCatalog);
    return [
      'risk=${r.risk}',
      'band=${r.band.name}',
      'tags=${r.tags.map((t) => '${t.text}:${t.kind.name}').join(',')}',
      'adjust=${r.adjustments.join(',')}',
      'split=${r.split}',
      'tip=${r.tip}',
      'warn=${r.warning}',
      'reordered=${r.reordered}',
      'am=${r.morning.map((p) => p.label).join('|')}',
      'pm=${r.night.map((g) => '${g.title}=${g.items.map((p) => p.n).join(',')}').join('|')}',
      'pairs=${r.pairs.map((p) => '${p.i}-${p.j}:${p.risk}').join(',')}',
      'alt=${alt == null ? '' : '${alt.title} | ${alt.items.map((a) => '${a.product.name}:교체 시 최대 충돌 ${a.worst}%').join(' / ')}'}',
    ].join('\n');
  }

  String expected({
    required int risk,
    required String band,
    required List<String> tags,
    List<String> adjust = const [],
    required bool split,
    required String tip,
    String warn = '',
    required bool reordered,
    required List<String> am,
    required List<String> pm,
    required List<String> pairs,
    String alt = '',
  }) => [
    'risk=$risk',
    'band=$band',
    'tags=${tags.join(',')}',
    'adjust=${adjust.join(',')}',
    'split=$split',
    'tip=$tip',
    'warn=$warn',
    'reordered=$reordered',
    'am=${am.join('|')}',
    'pm=${pm.join('|')}',
    'pairs=${pairs.join(',')}',
    'alt=$alt',
  ].join('\n');

  const sampleTags = [
    '#레티놀_AHA_산성충돌:clash',
    '#각질박리_과다:clash',
    '#피부장벽_손상위험:clash',
    '#레티놀_비타민C_pH충돌:clash',
    '#저pH_중첩자극:clash',
    '#고농도시_홍조가능:caution',
    '#액티브_과다_레이어링:caution',
    '#보습_시너지:good',
    '#피부장벽_강화:good',
  ];
  const sampleAm = ['라보에센 퓨어 비타민C 15 앰플', '그린노트 시카 배리어 리페어 크림', '선리 마일드 무기자차 선크림 SPF50+'];
  const samplePairs = ['0-1:37', '0-2:74', '0-3:2', '0-4:10', '1-2:45', '1-3:2', '1-4:22', '2-3:2', '2-4:10', '3-4:2'];
  const sampleAlt = '1번 클리어데이 AHA 7% 브라이트닝 토너 대신 쓰면 가장 큰 충돌(74%)을 줄일 수 있어요. | 병풀 진정 토너:교체 시 최대 충돌 4% / 히알루론 딥 수분 토너:교체 시 최대 충돌 4%';

  test('샘플 5단계 루틴', () {
    final r = engine.analyze(fromCatalog(kSampleRoutineIds), const SkinProfile());
    expect(
      summarize(r),
      expected(
        risk: 89,
        band: 'high',
        tags: sampleTags,
        split: true,
        tip: '격일(하루 걸러 하루) 사용을 권장합니다.',
        reordered: false,
        am: sampleAm,
        pm: ['Day A · 첫째 날=1,4', 'Day B · 둘째 날=3,4'],
        pairs: samplePairs,
        alt: sampleAlt,
      ),
    );
    expect(r.level, 5);
  });

  test('샘플 5단계 루틴 + 민감·건성·주의 이력 프로필', () {
    final r = engine.analyze(
      fromCatalog(kSampleRoutineIds),
      const SkinProfile(baseType: '건성', concerns: ['민감성/홍조'], history: ['acid', 'noRetinol', 'procedure', 'rx'], pregnancyAlert: true),
    );
    expect(
      summarize(r),
      expected(
        risk: 97,
        band: 'high',
        tags: sampleTags,
        adjust: ['민감 피부 +8', '건성 +2', '산성분 자극 이력 +5', '레티놀 첫 사용 +5', '시술 후 회복기 +6'],
        split: true,
        tip: '격일(하루 걸러 하루) 사용을 권장합니다.',
        warn: '임산부/수유부 주의 성분이 포함되어 있어요. 처방약과 겹칠 수 있는 액티브 성분이 있어요. 사용 전 전문의와 상담하세요.',
        reordered: false,
        am: sampleAm,
        pm: ['Day A · 첫째 날=1,4', 'Day B · 둘째 날=3,4'],
        pairs: samplePairs,
        alt: sampleAlt,
      ),
    );
  });

  test('레티놀 세럼 + AHA 토너', () {
    final r = engine.analyze(fromCatalog(['p1', 'p3']), const SkinProfile());
    expect(
      summarize(r),
      expected(
        risk: 74,
        band: 'high',
        tags: ['#레티놀_AHA_산성충돌:clash', '#각질박리_과다:clash', '#피부장벽_손상위험:clash', '#선크림_누락_광민감:caution', '#보습_시너지:good', '#피부장벽_강화:good'],
        split: true,
        tip: '격일(하루 걸러 하루) 사용을 권장합니다.',
        reordered: true,
        am: ['선크림 SPF50+ 추가 권장'],
        pm: ['Day A · 첫째 날=2', 'Day B · 둘째 날=1'],
        pairs: ['0-1:74'],
        alt: '2번 클리어데이 AHA 7% 브라이트닝 토너 대신 쓰면 가장 큰 충돌(74%)을 줄일 수 있어요. | 병풀 진정 토너:교체 시 최대 충돌 2% / 히알루론 딥 수분 토너:교체 시 최대 충돌 2%',
      ),
    );
  });

  test('순한 보습 루틴 (지성)', () {
    final r = engine.analyze(fromCatalog(['p11', 'p13', 'p15']), const SkinProfile(baseType: '지성'));
    expect(
      summarize(r),
      expected(
        risk: 6,
        band: 'low',
        tags: ['#보습_시너지:good', '#피부장벽_강화:good'],
        split: false,
        tip: '매일 사용해도 좋은 안심 루틴입니다.',
        reordered: false,
        am: ['워터풀 히알루론 딥 수분 토너', '바리에 세라마이드 장벽 수분크림', '선리 마일드 무기자차 선크림 SPF50+'],
        pm: ['매일 저녁=1,2'],
        pairs: ['0-1:2', '0-2:4', '1-2:6'],
      ),
    );
    expect(r.level, 1);
  });

  test('벤조일 + 레티놀 + 비타민C + 구리펩타이드 (민감도 4)', () {
    final r = engine.analyze(fromCatalog(['p18', 'p1', 'p6', 'p19']), const SkinProfile(sensitivity: 4));
    expect(
      summarize(r),
      expected(
        risk: 97,
        band: 'high',
        tags: [
          '#레티놀_벤조일_산화불활성:clash',
          '#건조_자극:clash',
          '#비타민C_산화:clash',
          '#레티놀_비타민C_pH충돌:clash',
          '#비타민C_구리펩타이드_불활성:clash',
          '#액티브_과다_레이어링:caution',
          '#선크림_누락_광민감:caution',
          '#보습_시너지:good',
          '#피부장벽_강화:good',
        ],
        adjust: ['민감 피부 +8'],
        split: true,
        tip: '격일(하루 걸러 하루) 사용을 권장합니다.',
        reordered: true,
        am: ['라보에센 퓨어 비타민C 15 앰플', '유스랩 구리펩타이드 탄력 세럼', '선크림 SPF50+ 추가 권장'],
        pm: ['Day A · 첫째 날=2,4', 'Day B · 둘째 날=4,1'],
        pairs: ['0-1:73', '0-2:46', '0-3:10', '1-2:45', '1-3:8', '2-3:33'],
        alt: '2번 무드랩 레티놀 0.1% 나이트 세럼 대신 쓰면 가장 큰 충돌(73%)을 줄일 수 있어요. | 판테놀 5% 리페어 세럼:교체 시 최대 충돌 4% / 나이아신아마이드 10 세럼:교체 시 최대 충돌 22%',
      ),
    );
  });

  test('성분 직접 입력', () {
    final steps = [
      const RoutineStep(id: 'm1', category: '토너', text: '글리콜릭애씨드, 판테놀, 살리실산', manual: true),
      const RoutineStep(id: 'm2', category: '세럼', text: '레티놀 0.5%', manual: true),
      const RoutineStep(id: 'm3', category: '크림', text: '판테놀', manual: true),
    ];
    final r = engine.analyze(steps, const SkinProfile());
    expect(
      summarize(r),
      expected(
        risk: 95,
        band: 'high',
        tags: ['#레티놀_AHA_산성충돌:clash', '#각질박리_과다:clash', '#피부장벽_손상위험:clash', '#레티놀_BHA_과자극:clash', '#선크림_누락_광민감:caution', '#보습_시너지:good'],
        split: true,
        tip: '격일(하루 걸러 하루) 사용을 권장합니다.',
        reordered: false,
        am: ['판테놀', '선크림 SPF50+ 추가 권장'],
        pm: ['Day A · 첫째 날=1,3', 'Day B · 둘째 날=2,3'],
        pairs: ['0-1:95', '0-2:10', '1-2:6'],
        alt: '1번 토너 대신 쓰면 가장 큰 충돌(95%)을 줄일 수 있어요. | 병풀 진정 토너:교체 시 최대 충돌 4% / 히알루론 딥 수분 토너:교체 시 최대 충돌 4%',
      ),
    );
  });

  test('라벨: 전성분만 붙여넣으면 카테고리 이름, 22자 초과는 말줄임', () {
    expect(AnalyzerEngine.labelOf('정제수, 글리세린, 판테놀', '토너'), '토너');
    expect(AnalyzerEngine.labelOf('가나다라마바사아자차카타파하가나다라마바사아자', '기타'), '가나다라마바사아자차카타파하가나다라마바사…');
  });
}
