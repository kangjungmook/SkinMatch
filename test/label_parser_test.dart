import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/core/label_parser.dart';

/// OCR에서 흔한 실수(줄바꿈으로 끊긴 이름, 비슷한 글자 오인식, 빠진 쉼표)를 흉내 낸 예시로 확인해요.
/// 실제 사진 인식 결과는 기기에서 따로 확인해야 해요.
void main() {
  final dict = IngredientDictionary.fromJson(
    jsonDecode(File('assets/data/ingredient_dictionary.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final parser = LabelParser(dict);

  test('전성분 부분만 잘라내고 주의사항 앞에서 멈춰요', () {
    const ocr = '''
라운드 테스트 토너 200ml
[전성분] 정제수, 부틸렌글라이콜, 글리세린,
1,2-헥산다이올, 판테놀, 알란토인
사용시의 주의사항 1. 화장품 사용 시 이상이 있는 경우''';
    final r = parser.parse(ocr);
    expect(r.foundHeader, isTrue);
    expect(r.items.map((e) => e.name), ['정제수', '부틸렌글라이콜', '글리세린', '1,2-헥산다이올', '판테놀', '알란토인']);
    expect(r.reviewCount, 0);
  });

  test('줄바꿈으로 끊긴 이름을 이어 붙여요', () {
    final r = parser.parse('전성분: 정제수, 부틸렌글라이\n콜, 나이아신아마\n이드');
    expect(r.items.map((e) => e.name), ['정제수', '부틸렌글라이콜', '나이아신아마이드']);
  });

  test('비슷한 글자로 잘못 읽은 성분은 가장 가까운 이름으로 고치고 확인 표시를 해요', () {
    final r = parser.parse('전성분: 글리세란, 부틸렌글라이골, 나이아신아마이트');
    expect(r.items.map((e) => e.name), ['글리세린', '부틸렌글라이콜', '나이아신아마이드']);
    expect(r.items.every((e) => e.status == MatchStatus.corrected), isTrue);
    expect(r.items.first.raw, '글리세란');
  });

  test('농도 표기는 떼고, 이명은 표준명으로 바꿔요', () {
    final r = parser.parse('전성분: 정제수, 레티놀 0.1%, 세라마이드NP, 히알루론산(0.5%)');
    expect(r.items.map((e) => e.name), ['정제수', '레티놀', '세라마이드엔피', '하이알루로닉애씨드']);
    expect(r.items[1].keyActive, isTrue);
  });

  test('쉼표가 빠져 붙은 두 성분을 나눠요', () {
    final r = parser.parse('전성분: 정제수, 글리세린부틸렌글라이콜, 판테놀');
    expect(r.items.map((e) => e.name), ['정제수', '글리세린', '부틸렌글라이콜', '판테놀']);
  });

  test('사전에 없는 성분은 그대로 두고 확인이 필요하다고 표시해요', () {
    final r = parser.parse('전성분: 정제수, 가나다라마바사추출물');
    expect(r.items.last.status, MatchStatus.unknown);
    expect(r.items.last.name, '가나다라마바사추출물');
    expect(r.reviewCount, 1);
  });

  test('레티놀을 잘못 읽어도 중요 성분으로 표시해요', () {
    final r = parser.parse('전성분: 정제수, 레티놑');
    expect(r.items.last.name, '레티놀');
    expect(r.items.last.keyActive, isTrue);
    expect(r.items.last.needsReview, isTrue);
  });

  test('"전성분" 제목이 없으면 전체 글자에서 찾아요', () {
    final r = parser.parse('정제수, 글리세린, 판테놀');
    expect(r.foundHeader, isFalse);
    expect(r.items.map((e) => e.name), ['정제수', '글리세린', '판테놀']);
  });
}
