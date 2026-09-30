import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/data/auth_repository.dart';
import 'package:skinmatch/data/local_store.dart';
import 'package:skinmatch/features/analyzer/label_scan.dart';
import 'package:skinmatch/providers/core_providers.dart';
import 'package:skinmatch/providers/routine_provider.dart';
import 'package:skinmatch/providers/session_provider.dart';
import 'package:skinmatch/providers/vanity_provider.dart';

class FakeReader implements LabelReader {
  FakeReader(this.text);
  final String text;
  @override
  bool get supported => true;
  @override
  Future<String> read(String imagePath) async => text;
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

  testWidgets('잘못 읽은 레티놀을 확인해야 루틴에 넣을 수 있어요', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await LocalStore.openInMemory();
    final auth = DemoAuthRepository();
    await auth.signInWithKakao();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
        labelReaderProvider.overrideWithValue(FakeReader('무드랩 세럼 30ml\n[전성분] 정제수, 글리세란, 레티놑,\n세라마이드NP\n사용시의 주의사항 ...')),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(sessionProvider).loggedIn, isTrue);
    final stepId = container.read(routineProvider).steps.first.id;
    final vanityBefore = container.read(vanityProvider).products.length;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LabelReviewSheet(imagePath: 'fake.jpg', stepId: stepId, category: '세럼'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('성분 4개를 읽었어요', findRichText: true), findsOneWidget);
    expect(find.text('글리세린'), findsOneWidget); // 글리세란 → 자동 교정
    expect(find.text('세라마이드엔피'), findsOneWidget); // 이명 → 표준명
    expect(find.text('중요 성분 1개를 먼저 확인해 주세요'), findsOneWidget);

    // 레티놀 칩을 눌러 확인
    await tester.tap(find.text('레티놀'));
    await tester.pumpAndSettle();
    expect(find.text('사진에서 읽은 글자: 레티놑'), findsOneWidget);
    // 입력칸에도 '레티놀'이 있어서, 후보 버튼(Text)만 골라 눌러요.
    await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data == '레티놀').last);
    await tester.pumpAndSettle();

    expect(find.text('이 전성분으로 루틴에 넣기'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '레티놀 0.1% 나이트 세럼');
    await tester.tap(find.text('이 전성분으로 루틴에 넣기'));
    await tester.pumpAndSettle();

    final step = container.read(routineProvider).steps.firstWhere((s) => s.id == stepId);
    expect(step.product?.name, '레티놀 0.1% 나이트 세럼');
    expect(step.product?.category, '세럼');
    expect(step.product?.ingredients, ['정제수', '글리세린', '레티놀', '세라마이드엔피']);
    expect(container.read(vanityProvider).products.length, vanityBefore + 1);
    await tester.pump(const Duration(seconds: 3));
  });
}
