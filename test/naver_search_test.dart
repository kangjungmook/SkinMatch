import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/app/app.dart';
import 'package:skinmatch/data/auth_repository.dart';
import 'package:skinmatch/data/local_store.dart';
import 'package:skinmatch/data/product_repository.dart';
import 'package:skinmatch/features/analyzer/quick_pick.dart';
import 'package:skinmatch/models/product.dart';
import 'package:skinmatch/providers/core_providers.dart';
import 'package:skinmatch/providers/routine_provider.dart';

/// 서버(functions/src/naver.js)가 돌려주는 모양 그대로예요. 전성분이 비어 있어요.
final _naverJson = <Map<String, dynamic>>[
  {
    'id': 'naver_1',
    'brand': '무드랩',
    'name': '레티놀 0.1% 나이트 세럼 30ml',
    'category': '세럼',
    'ingredients': <String>[],
    'imageUrl': 'https://shopping-phinf.pstatic.net/test.jpg',
    'source': 'naver',
    'naverCategory': '화장품/미용 > 스킨케어 > 에센스',
    'price': 21000,
    'link': 'https://search.shopping.naver.com/catalog/1',
  },
  {
    'id': 'naver_2',
    'brand': '수분랩',
    'name': '수분 장벽 크림 50ml',
    'category': '크림',
    'ingredients': <String>[],
    'imageUrl': null,
    'source': 'naver',
  },
  {'id': 'naver_3', 'brand': '선랩', 'name': '데일리 선크림 SPF50+', 'category': '선크림', 'ingredients': <String>[], 'source': 'naver'},
];

/// 전성분 없는 제품만 돌려주는 가짜 서버
class FakeNaverRepository implements ProductRepository {
  final products = [for (final j in _naverJson) Product.fromJson(j)];

  @override
  Future<List<Product>> search(String query, {String? category}) async =>
      products.where((p) => '${p.brand} ${p.name}'.contains(query.trim())).toList();
  @override
  Future<Product?> byBarcode(String barcode) async => null;
  @override
  Future<List<Product>> byCategory(String category) async => const [];
  @override
  Future<Product?> byId(String id) async => null;
}

Future<void> loadFonts() async {
  final loader = FontLoader('Pretendard');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
  }
  await loader.load();
}

void main() {
  setUpAll(loadFonts);

  test('이름으로 주요 성분을 추정해요', () {
    expect(guessQuickKeys('레티놀 0.1% 나이트 세럼', '세럼'), {'retinol'});
    expect(guessQuickKeys('데일리 선크림 SPF50+', '선크림'), {'uvf'});
    expect(guessQuickKeys('수분 크림', '크림'), isEmpty);
  });

  test('전성분이 없는 제품은 골라도 분석 대상(filled)이 아니에요', () async {
    final p = Product.fromJson(_naverJson[1]);
    expect(p.hasIngredients, isFalse);
    expect(p.source, 'naver');
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(await LocalStore.openInMemory()),
        authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    final n = container.read(routineProvider.notifier);
    final id = container.read(routineProvider).steps.first.id;
    n.pickProduct(id, p);
    final s = container.read(routineProvider).steps.first;
    expect(s.product, p);
    expect(s.category, '크림');
    expect(s.isFilled, isFalse);
    // 로그인 상태 확인 타이머가 끝난 뒤에 container를 정리해요.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  });

  for (final width in [440.0, 360.0]) {
    testWidgets('네이버 검색 → 제품 선택 → 주요 성분(이름 추정) → 분석 결과 안내 ($width)', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await LocalStore.openInMemory();
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          productRepositoryProvider.overrideWithValue(FakeNaverRepository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SkinMatchApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tap(find.text('카카오로 3초 만에 시작하기'));
      await tap(find.text('나중에 설정할게요'));

      Future<void> searchAndPick(int field, String q, String name) async {
        await tester.enterText(find.byType(TextField).at(field), q);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        await tap(find.textContaining(name, findRichText: true).last);
      }

      // 1단계: 레티놀 세럼 → 이름에서 레티놀을 추정
      await searchAndPick(0, '레티놀', '레티놀 0.1% 나이트 세럼 30ml');
      expect(find.text('전성분 정보가 아직 없어요. 전성분을 넣어야 분석할 수 있어요.'), findsOneWidget);
      expect(find.text('제품을 2개 이상 입력해 주세요'), findsOneWidget); // 아직 분석 대상이 아니에요
      await tap(find.text('주요 성분'));
      expect(find.text('제품 이름을 보고 1개를 미리 골라 두었어요. 맞는지 확인해 주세요.'), findsOneWidget);
      await tap(find.text('주요 성분 1개로 넣기'));

      var steps = container.read(routineProvider).steps;
      expect(steps[0].quick, isTrue);
      expect(steps[0].text, '무드랩 레티놀 0.1% 나이트 세럼 30ml\n레티놀');
      expect(find.text('간단 입력'), findsOneWidget);

      // 2단계: 크림 → 추정 없음, 직접 골라요
      await searchAndPick(0, '수분', '수분 장벽 크림 50ml');
      await tap(find.text('주요 성분'));
      expect(find.text('제품 이름이나 포장에 적힌 주요 성분을 골라 주세요.'), findsOneWidget);
      await tap(find.text('세라마이드'));
      await tap(find.text('주요 성분 1개로 넣기'));

      // 3단계: 선크림을 고르고 비워 둬요 → 분석에서 빠져요
      await tap(find.text('단계 추가'));
      await searchAndPick(0, '선크림', '데일리 선크림 SPF50+');
      steps = container.read(routineProvider).steps;
      expect(steps.map((s) => s.isFilled), [true, true, false]);

      await tap(find.text('2개 제품 성분 충돌 & 자극 분석하기'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('루틴 분석 결과'), findsOneWidget);
      expect(find.text('주요 성분만 넣은 제품 2개는 간단 분석이에요. 전성분을 넣으면 더 정확해져요.'), findsOneWidget);
      expect(find.text('전성분을 넣지 않은 제품 1개는 분석에서 빠졌어요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
