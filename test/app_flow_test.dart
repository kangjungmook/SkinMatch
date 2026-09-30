import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/app/app.dart';
import 'package:skinmatch/data/auth_repository.dart';
import 'package:skinmatch/data/local_store.dart';
import 'package:skinmatch/data/product_repository.dart';
import 'package:skinmatch/models/skin_profile.dart';
import 'package:skinmatch/providers/core_providers.dart';

/// 실제 폰트(Pretendard)로 레이아웃을 검사해야 넘침(overflow)을 정확히 잡을 수 있어요.
Future<void> loadFonts() async {
  final loader = FontLoader('Pretendard');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
  }
  await loader.load();
}

void main() {
  late LocalStore store;

  setUpAll(loadFonts);

  setUp(() async {
    store = await LocalStore.openInMemory();
  });

  Future<void> pumpApp(WidgetTester tester, {double width = 440}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          productRepositoryProvider.overrideWithValue(const MockProductRepository()),
        ],
        child: const SkinMatchApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300)); // 로그인 상태 확인
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).first;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pump();
  }

  testWidgets('로그인 → 진단 건너뛰기 → 샘플 루틴 분석 → 결과 → 화장대 저장', (tester) async {
    await pumpApp(tester);
    expect(find.text('카카오로 3초 만에 시작하기'), findsOneWidget);

    await tapText(tester, '카카오로 3초 만에 시작하기');
    await tester.pumpAndSettle();
    expect(find.text('평소 피부 타입을 알려주세요'), findsOneWidget);

    await tapText(tester, '나중에 설정할게요');
    await tester.pumpAndSettle();
    expect(find.text('제품을 2개 이상 입력해 주세요'), findsOneWidget);

    await tapText(tester, '+ 샘플 5단계 루틴');
    await tester.pumpAndSettle();
    expect(find.text('5개 제품 성분 충돌 & 자극 분석하기'), findsOneWidget);

    await tapText(tester, '5개 제품 성분 충돌 & 자극 분석하기');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('성분 조합을 분석하고 있어요…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('루틴 분석 결과'), findsOneWidget);
    expect(find.text('89'), findsOneWidget); // 게이지 카운트업이 끝난 값
    expect(find.text('동시 사용 비추천 (자극 및 각질 손상 위험)'), findsOneWidget);
    expect(find.text('격일(하루 걸러 하루) 사용을 권장합니다.'), findsOneWidget);

    await tapText(tester, '내 화장대에 이 루틴 저장하기');
    await tester.pumpAndSettle();
    expect(find.text('내 화장대에 저장됨'), findsOneWidget);
    expect(store.combos('demo'), hasLength(1));
    expect(store.recent('demo'), hasLength(1));

    await tapText(tester, '내 화장대');
    await tester.pumpAndSettle();
    expect(find.text('저장한 조합'), findsOneWidget);
    expect(find.text('등록된 제품 8개'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // 토스트 타이머 정리
  });

  testWidgets('피부 진단을 마치면 프로필이 저장되고 홈 요약에 보여요', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Apple로 계속하기');
    await tester.pumpAndSettle();

    await tapText(tester, '지성');
    await tapText(tester, '다음');
    await tester.pumpAndSettle();
    await tapText(tester, '모공·피지');
    await tapText(tester, '2');
    await tapText(tester, '다음');
    await tester.pumpAndSettle();
    await tapText(tester, '피부 프로필 저장하고 시작하기');
    await tester.pumpAndSettle();

    expect(find.text('내 피부 · 지성 · 모공·피지 · 민감도 2'), findsOneWidget);
    expect(store.onboarded('demo'), isTrue);
    final p = store.profile('demo');
    expect(p.baseType, '지성');
    expect(p.concerns, ['모공·피지']);
    expect(p.sensitivity, 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('360px 좁은 화면에서도 입력·결과·화장대·마이페이지가 넘치지 않아요', (tester) async {
    await pumpApp(tester, width: 360);
    await tapText(tester, '카카오로 3초 만에 시작하기');
    await tester.pumpAndSettle();
    await tapText(tester, '나중에 설정할게요');
    await tester.pumpAndSettle();
    await tapText(tester, '+ 샘플 5단계 루틴');
    await tester.pumpAndSettle();
    await tapText(tester, '5개 제품 성분 충돌 & 자극 분석하기');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('루틴 분석 결과'), findsOneWidget);
    await tapText(tester, '내 화장대');
    await tester.pumpAndSettle();
    await tapText(tester, '마이페이지');
    await tester.pumpAndSettle();
    expect(find.text('카카오 계정으로 로그인됨'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  test('LocalStore는 사용자별로 저장해요', () async {
    await store.saveProfile('a', const SkinProfile(baseType: '건성', sensitivity: 3));
    expect(store.profile('a').baseType, '건성');
    expect(store.profile('b').baseType, isNull);
    expect(store.vanity('b'), hasLength(8)); // 처음엔 예시 제품
  });
}
