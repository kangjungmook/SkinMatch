# SkinMatch (스킨매치) — Flutter 개발 가이드

> **구현 완료 (2026-09-30)** — 이 가이드대로 `lib/`에 Flutter 앱을 만들었어요. 맨 아래 **10. 실제 구현에서 바뀐 점**을 먼저 보세요.

## 1. 현재 프로토타입
- 파일: `design/SkinMatch.dc.html` (최신)
- 만든 방식: HTML + CSS(인라인 스타일) + JavaScript(React 방식 상태관리)
- 용도: 디자인·흐름 확인용 **목업**이에요. 실제 앱 코드가 아니니, 아래 스펙대로 Flutter에서 새로 구현하세요.

## 2. 실제 앱 기술 스택
| 구분 | 선택 |
|---|---|
| 언어 | **Dart 3.x** |
| 프레임워크 | **Flutter 3.24+** (iOS / Android / Web 동시 빌드) |
| 상태관리 | `flutter_riverpod` |
| 라우팅 | `go_router` (하단 탭 = `StatefulShellRoute`) |
| 폰트 | Pretendard (`assets/fonts`에 포함) |
| 아이콘 | `lucide_icons` |
| 애니메이션 | `AnimatedContainer`, `TweenAnimationBuilder`, `flutter_animate` |
| 게이지 | `CustomPainter`로 반원 게이지 |
| 로컬 저장 | `shared_preferences` (설정), `hive` (화장대·루틴·최근 분석) |
| 네트워크 | `dio` |
| 바코드 | `mobile_scanner` |
| 공유 | `share_plus` |
| 로그인 | `kakao_flutter_sdk_user`, `sign_in_with_apple`, `google_sign_in`, `firebase_auth` |

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  lucide_icons: ^0.257.0
  flutter_animate: ^4.5.0
  shared_preferences: ^2.3.2
  hive_flutter: ^1.1.0
  dio: ^5.7.0
  mobile_scanner: ^5.2.3
  share_plus: ^10.0.2
  kakao_flutter_sdk_user: ^1.9.5
  sign_in_with_apple: ^6.1.2
  google_sign_in: ^6.2.1
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
```

## 3. 폴더 구조
```
lib/
  main.dart
  app/            router.dart, theme.dart
  core/           colors.dart, analyzer_engine.dart, ingredient_db.dart
  data/           product_repository.dart (API), local_store.dart (Hive)
  models/         product.dart, routine_step.dart, skin_profile.dart, routine_result.dart, saved_routine.dart
  providers/      auth_provider.dart, profile_provider.dart, routine_provider.dart, vanity_provider.dart, recent_provider.dart
  features/
    auth/         login_screen.dart, onboarding_screen.dart (3단계)
    analyzer/     analyzer_screen.dart, result_screen.dart, ingredient_sheet.dart, scan_sheet.dart
                  widgets/ routine_step_card.dart, product_search_field.dart, risk_gauge.dart, clash_matrix.dart, alt_suggest_card.dart
    vanity/       vanity_screen.dart, product_sheet.dart, add_product_sheet.dart
    profile/      profile_screen.dart
  widgets/        floating_nav.dart, sm_card.dart, sm_chip.dart, toast.dart
```

## 4. 디자인 토큰 (`core/colors.dart`)
```dart
import 'package:flutter/material.dart';

class SM {
  static const bg        = Color(0xFFF8FAFC);
  static const surface   = Color(0xFFFFFFFF);
  static const border    = Color(0xFFF1F5F9);
  static const ink       = Color(0xFF0F172A);
  static const inkSub    = Color(0xFF64748B);
  static const primary   = Color(0xFF10B981);
  static const primaryTx = Color(0xFF047857);
  static const primaryBg = Color(0xFFECFDF5);
  static const warn      = Color(0xFFF59E0B);
  static const warnTx    = Color(0xFFB45309);
  static const warnBg    = Color(0xFFFFFBEB);
  static const danger    = Color(0xFFEF4444);
  static const dangerTx  = Color(0xFFB91C1C);
  static const dangerBg  = Color(0xFFFEF2F2);
  static const kakao     = Color(0xFFFEE500);
  static const kakaoTx   = Color(0xFF3C1E1E);

  static const rCard = 26.0;   // 카드
  static const rBtn  = 20.0;   // 주요 버튼
  static const rChip = 999.0;  // 칩/알약
  static const pad   = 20.0;   // 화면 좌우 여백
}
```
- 폰트: Pretendard, 제목 700 / 본문 400~600, 자간 -0.01 ~ -0.035em
- 카드 그림자: `BoxShadow(color: Color(0x2E0F172A), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -20)`
- 하단 탭 유리 효과: `BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22))`
- 성분 칩 색: 진정·보습 = 초록(`primaryBg/primaryTx`), 강한 액티브 = 주황(`#FFF7ED/#B45309`), 나이아신 = 회색

## 5. 화면 & 기능 명세
| 화면 | 기능 |
|---|---|
| **로그인** | 카카오·Apple·Google 로그인, 이메일 로그인/회원가입 탭, 플로팅 라벨 입력, 검증(이메일 형식, 비밀번호 8자 이상), 비밀번호 찾기 |
| **피부 진단 1/3 · 기본 타입** | 건성·지성·복합성·중성 **단일 선택**(설명 포함), "잘 모르겠어요" → 질문 1개로 타입 추정, Baumann 기준 배지, 정보가 필요한 이유 안내 |
| **피부 진단 2/3 · 고민·민감도** | 피부 고민 6개 **복수 선택**, 자극 민감도 1~5 |
| **피부 진단 3/3 · 주의 사항** | 산성분 따가움 / 레티놀 첫 사용 / 2주 내 시술 / 처방약 체크, 임산부 알림, 프로필 요약과 보정값 미리보기, 개인정보 안내 |
| **분석 (홈)** | 최근 분석(최대 3개, 탭하면 재분석) · **루틴 단계 쌓기(최대 8단계)** · 단계별 카테고리 · **제품명 검색 → 전성분 자동 입력** · 카테고리별 빠른 검색 칩 · 바코드 스캔 · 성분 직접 입력/클립보드 · 화장대에서 불러오기 · ▲▼ 순서 변경 · 삭제 · 비우기 · 샘플 5단계 루틴 |
| **결과** | 400ms 스켈레톤 → 반원 게이지 1.2초 카운트업 · 위험 구간 알약 · 피부 프로필 보정 내역 · 자극 지수 5단계 · **제품별 충돌 맵(N×N)** + 위험 조합 목록 · **대체 제품 추천 → 교체하기(즉시 재분석)** · 충돌 태그 · 아침 권장 순서(선크림 없으면 추가 권장) · 저녁 권장 순서(충돌 시 **Day A / Day B 격일 분리**) · Rule of Thumb · 공유 · 루틴 저장 |
| **성분 사전 (시트)** | 성분 칩 탭 → 안심/주의 등급, 효능, 사용 팁, 함께 쓰면 좋은 성분 / 동시 사용 주의 성분 |
| **바코드 스캔 (시트)** | 카메라 미리보기 + 스캔 라인 → 인식되면 해당 단계에 제품 입력 |
| **내 화장대** | 저장한 루틴(탭하면 불러와 재분석), 카테고리 필터, 2열 제품 그리드, 제품 상세(루틴에 추가/삭제), 제품 직접 등록 버튼 |
| **마이페이지** | 계정, 화장대·저장 루틴 개수, 피부 프로필 요약 + 다시 진단하기, 임산부 알림, 설정, 로그아웃 |

위험도 구간:
- 0~30% 🟢 안심 조합 (보습 & 피부 장벽 시너지)
- 31~70% 🟡 시간차 사용 권장 (민감성 피부 주의)
- 71~100% 🔴 동시 사용 비추천 (자극 및 각질 손상 위험)
- 자극 레벨 = `ceil(위험도 / 20)` (1~5)

## 6. 모델 (`models/`)
```dart
class Product {
  final String id, brand, name, category; // 토너|에센스·앰플|세럼|아이크림|크림|선크림|메이크업|기타
  final List<String> ingredients;
  final String? imageUrl, barcode;
  const Product({required this.id, required this.brand, required this.name,
    required this.category, required this.ingredients, this.imageUrl, this.barcode});
  factory Product.fromJson(Map<String, dynamic> j) => Product(id: j['id'], brand: j['brand'],
    name: j['name'], category: j['category'], ingredients: List<String>.from(j['ingredients']),
    imageUrl: j['imageUrl'], barcode: j['barcode']);
}

class RoutineStep {
  final String id, category;
  final Product? product;     // 검색·스캔·화장대에서 고른 경우
  final String manualText;    // 성분을 직접 입력한 경우
  String get text => product != null
      ? '${product!.brand} ${product!.name}\n${product!.ingredients.join(', ')}'
      : manualText;
  const RoutineStep({required this.id, required this.category, this.product, this.manualText = ''});
}

class SkinProfile {
  final String? baseType;        // 건성|지성|복합성|중성
  final List<String> concerns;   // 민감성/홍조, 여드름·트러블, 장벽손상, 색소침착·잡티, 모공·피지, 주름·탄력
  final int sensitivity;         // 1~5
  final Set<String> history;     // acid, noRetinol, procedure, rx
  final bool pregnancyAlert;
  const SkinProfile({this.baseType, this.concerns = const [], this.sensitivity = 0,
    this.history = const {}, this.pregnancyAlert = false});
}

enum RiskBand { low, mid, high }
enum TagKind { clash, caution, good }
class Tag { final String text; final TagKind kind; const Tag(this.text, this.kind); }
class PairResult { final int i, j, risk; final List<Tag> tags; const PairResult(this.i, this.j, this.risk, this.tags); }

class RoutineResult {
  final int risk, level; final RiskBand band;
  final List<PairResult> pairs;          // 충돌 맵
  final List<Tag> tags;
  final List<RoutineStep> morning;
  final List<List<RoutineStep>> night;   // [매일] 또는 [Day A, Day B]
  final bool needsSunscreen, reordered;
  final List<String> adjustments;        // 예: "민감 피부 +8"
  final String tip, warning;
  const RoutineResult({required this.risk, required this.level, required this.band, required this.pairs,
    required this.tags, required this.morning, required this.night, required this.needsSunscreen,
    required this.reordered, required this.adjustments, required this.tip, required this.warning});
}

class SavedRoutine {  // 저장한 루틴 & 최근 분석(최대 5개)
  final String id; final List<RoutineStep> steps; final int risk; final RiskBand band; final DateTime at;
  const SavedRoutine(this.id, this.steps, this.risk, this.band, this.at);
}
```

## 7. 분석 엔진 규칙 (`core/analyzer_engine.dart`)
목업 로직과 같아요. 나중에 AI 서버로 바꿔도 입력(`List<RoutineStep>`, `SkinProfile`)과 출력(`RoutineResult`)은 그대로 두세요.

**① 성분 인식** (정규식, 대소문자 무시)
| 키 | 이름 | 감지 패턴 | 분류 |
|---|---|---|---|
| retinol | 레티놀 | 레티놀·레티날·레티노이드·트레티노인·retinol·retinal | 강한 액티브 |
| aha | AHA | aha·글리콜릭·락틱·만델릭 | 강한 액티브 |
| bha | BHA | bha·살리실 | 강한 액티브 |
| pha | PHA | pha·글루코노락톤·락토바이오닉 | 강한 액티브 |
| vitc | 비타민C | 비타민c·아스코빅·ascorbic | 액티브 |
| bpo | 벤조일퍼옥사이드 | 벤조일·benzoyl | 강한 액티브 |
| copper | 구리펩타이드 | 구리펩타이드·copper peptide | 액티브 |
| niacin | 나이아신아마이드 | 나이아신·niacinamide | 액티브(대체로 안심) |
| ceramide / ha / panthenol / cica | 세라마이드 / 히알루론산 / 판테놀 / 시카 | 세라마이드 / 히알루론 / 판테놀 / 시카·병풀·센텔라·마데카 | 진정·보습 |
| uvf | 자외선 차단 | 징크옥사이드·티타늄디옥사이드·SPF숫자 | 선크림 판정 |

**② 충돌 규칙**
| 조합 | 가중치 | 태그 |
|---|---|---|
| 레티놀 × AHA | 72 | #레티놀_AHA_산성충돌 #각질박리_과다 #피부장벽_손상위험 |
| 레티놀 × 벤조일 | 66 | #레티놀_벤조일_산화불활성 #건조_자극 |
| 레티놀 × BHA | 62 | #레티놀_BHA_과자극 #피부장벽_손상위험 |
| AHA × BHA | 44 | #이중산_각질박리_과다 |
| 레티놀 × 비타민C | 38 | #레티놀_비타민C_pH충돌 |
| 레티놀 × PHA | 34 | #레티놀_PHA_각질자극 |
| 비타민C × 벤조일 | 34 | #비타민C_산화 |
| 레티놀 × 레티놀 | 32 | #레티노이드_중복 |
| AHA × 비타민C | 30 | #저pH_중첩자극 |
| BHA × 비타민C | 28 | #저pH_중첩자극 |
| 비타민C × 구리펩타이드 | 26 | #비타민C_구리펩타이드_불활성 |
| AHA × AHA | 22 | #산성분_중복 |
| 비타민C × 나이아신 | 10 (주의) | #고농도시_홍조가능 |

**③ 두 제품 조합 위험도** (모든 i<j 쌍)
- 충돌 있음: `12 + 최대 가중치 + 나머지 가중치 × 0.3 − min(진정 성분 수 × 5, 10)`
- 충돌 없음: `4 + 액티브 수 × 4 − 진정 성분 수 × 2`
- 2~95로 제한

**④ 루틴 전체 위험도**
- `최고 조합 위험도 + (31% 이상인 나머지 조합 위험도 합 × 0.12)`
- 액티브 제품 3개 이상 +5 (#액티브_과다_레이어링)
- 피부 프로필 보정(충돌이 있을 때만): 민감(민감성/홍조·장벽손상·민감도 4 이상) +8, 지성 −3, 건성 +2, 산성분 따가움 이력 +5, 레티놀 첫 사용 +5
- 2주 내 시술: 액티브가 있으면 +6
- 3~97로 제한

**⑤ 권장 순서**
- 정렬: 토너 1 → 에센스·앰플 2 → 세럼 3 → 아이크림 4 → 기타 4.5 → 크림 5 → 선크림 6 → 메이크업 7
- 아침만: 선크림, 메이크업, 비타민C / 저녁만: 레티놀·AHA·BHA·PHA·벤조일 / 나머지: 아침·저녁 모두
- 선크림이 없는데 액티브가 있으면 아침에 "선크림 SPF50+ 추가 권장" + #선크림_누락_광민감
- 저녁 액티브끼리 50%를 넘게 충돌하면 Day A / Day B로 나누고, 공통 보습 단계는 두 날 모두에 넣어요. 팁: "격일(하루 걸러 하루) 사용을 권장합니다."

**⑥ 대체 제품 추천**
- 최고 조합이 50%를 넘으면, 그 조합의 두 제품 각각에 대해 같은 카테고리 후보를 찾아요.
- 후보로 바꿨을 때 나머지 제품과의 최대 위험도가 기존보다 15 이상 낮으면 추천해요(최대 2개).

**⑦ 경고 문구**
- 임산부 알림 ON + 레티놀/BHA → "임산부/수유부 주의 성분이 포함되어 있어요."
- 처방약 사용 + 레티놀/AHA/BHA/벤조일 → "처방약과 겹칠 수 있는 액티브 성분이 있어요."

## 8. 실데이터 API 연동 지점
목업은 샘플 제품 20개로 동작해요. 아래 API만 연결하면 돼요.
```
GET /products/search?q={검색어}&cat={카테고리}&limit=5    → Product[]        # 제품명 검색 (디바운스 280ms)
GET /products/barcode/{barcode}                            → Product          # 바코드 스캔
GET /products/alternatives?productId=&against=id1,id2      → Product[]        # 대체 추천 (선택)
GET /ingredients/{key}                                     → IngredientInfo   # 성분 사전
```
```dart
abstract class ProductRepository {
  Future<List<Product>> search(String query, {String? category});
  Future<Product?> byBarcode(String barcode);
}

class ApiProductRepository implements ProductRepository {
  final Dio dio;
  ApiProductRepository(this.dio);

  @override
  Future<List<Product>> search(String q, {String? category}) async {
    final res = await dio.get('/products/search',
        queryParameters: {'q': q, if (category != null) 'cat': category, 'limit': 5});
    return (res.data as List).map((e) => Product.fromJson(e)).toList();
  }

  @override
  Future<Product?> byBarcode(String code) async {
    final res = await dio.get('/products/barcode/$code');
    return res.statusCode == 200 ? Product.fromJson(res.data) : null;
  }
}

class IngredientInfo {
  final String key, name, grade, effect, tip;   // grade: 안심 성분 | 대체로 안심 | 주의 필요
  final List<String> goodWith, avoidWith;
  const IngredientInfo(this.key, this.name, this.grade, this.effect, this.tip, this.goodWith, this.avoidWith);
}
```
- 검색 결과가 없을 때 "성분 직접 입력"으로 넘어가는 경로는 꼭 남겨 두세요.
- Hive에 로컬로 저장할 것: 화장대 제품, 저장한 루틴, 최근 분석 5개, 피부 프로필

## 9. 개발 순서 추천
1. 테마·폰트·하단 탭 (`theme.dart`, `floating_nav.dart`)
2. 로그인 → 피부 진단 3단계 → `SkinProfile` 저장
3. 루틴 입력(단계 쌓기, 순서 변경) + 제품 검색 API
4. `AnalyzerEngine`(7장 규칙) + 결과 화면(게이지 `CustomPainter`, 충돌 맵, 아침·저녁 순서)
5. 성분 사전 · 대체 추천 · 공유 · 최근 분석
6. 내 화장대(Hive) + 바코드 스캔(`mobile_scanner`)
7. AI 서버를 붙일 때는 `AnalyzerEngine.analyze()`만 API 호출로 교체

> 성분 사전 문구와 충돌 가중치는 목업용 일반 정보예요. 출시 전에 피부과 전문의나 화장품 전문가의 검수를 받으세요.
> 결과 화면의 "참고용 가이드이며 의학적 진단을 대체하지 않습니다" 문구는 유지하세요.

## 10. 실제 구현에서 바뀐 점
가이드를 쓴 뒤 패키지 버전이 올라가서 아래처럼 바꿨어요. 화면과 분석 규칙은 가이드와 같아요.

| 가이드 | 실제 구현 | 이유 |
|---|---|---|
| `hive` / `hive_flutter` | `hive_ce` / `hive_ce_flutter` | 원래 hive는 유지보수가 멈췄어요. 같은 API를 쓰는 후속 패키지예요. JSON 문자열로 저장해서 코드 생성이 필요 없어요. |
| `lucide_icons` | 프로토타입의 SVG를 `flutter_svg`로 그대로 사용 (`core/icons.dart`) | 아이콘 모양과 선 굵기를 프로토타입과 똑같이 맞추려고요. |
| `flutter_animate` | 기본 `TweenAnimationBuilder` · `AnimatedContainer` | 쓰는 애니메이션(페이드 인, 게이지, 스위치)이 단순해서 의존성을 줄였어요. |
| `sign_in_with_apple` | Firebase `AppleAuthProvider` | Firebase가 iOS 네이티브·웹 팝업을 모두 처리해요. |
| `google_sign_in` 6.x | 7.x (`GoogleSignIn.instance.authenticate()`) | 최신 버전 API예요. 웹은 Firebase 팝업을 써요. |
| 카카오 로그인 | Kakao SDK v2 → ID 토큰 → Firebase OIDC(`oidc.kakao`) | Firebase에 카카오 제공업체가 없어서 OpenID Connect로 연결해요. README 참고. |
| `StatefulShellRoute` | `ShellRoute` | 탭을 옮길 때 프로토타입처럼 화면을 새로 그리고 맨 위에서 시작해요. 입력 중인 루틴은 Riverpod에 남아 있어요. |

### 프로토타입과 다르게 한 부분
- **성분 사전 시트 버튼**: "확인" 대신 "성분 설명 닫기"로 바꿨어요. 버튼이 무슨 일을 하는지 바로 알 수 있게요.
- **✦ 반짝임**: Pretendard에 이 글자가 없어서 기기마다 다른 폰트로 보여요. 같은 모양의 벡터로 그렸어요.
- **상태 표시줄**: 프로토타입의 가짜 "9:41" 줄은 그리지 않았어요. 휴대폰에서는 실제 상태 표시줄, 넓은 화면의 폰 프레임에서는 같은 높이(46px)를 비워 둬요.
- **좁은 화면(360px)**: 루틴 단계 종류 알약이 먼저 줄어들고 글자가 말줄임돼요. 프로토타입에서 CSS가 하던 동작과 같아요.
- **바코드 스캔**: 실제 카메라로 스캔해요. 샘플 DB에는 진짜 바코드가 없어서, 샘플 DB로 실행할 때만 "샘플 바코드로 스캔해 보기" 버튼이 보여요.
- **비밀번호 찾기**: 실제 재설정 메일을 보내요. 이메일을 먼저 입력하지 않았으면 입력해 달라고 안내해요.
- **"알림 설정", "고객센터"**: 프로토타입처럼 "준비 중인 기능이에요" 안내만 보여요.

### 분석 엔진 검증
`test/analyzer_engine_test.dart`는 프로토타입의 JS `compute()` · `altVals()`를 Node로 실행한 결과를 정답으로 써요.
6가지 루틴(샘플 5단계, 민감 프로필, 레티놀+AHA, 순한 루틴, 벤조일 조합, 성분 직접 입력)에서 위험도, 태그, 아침·저녁 순서, 격일 분리, 대체 추천이 모두 같아요.
