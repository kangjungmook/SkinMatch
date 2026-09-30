# SkinMatch (스킨매치)

스킨케어 루틴(토너 → 앰플 → 세럼 → 크림 → 선크림 …)의 **성분 충돌과 자극 위험**을 분석해 주는 Flutter 앱이에요.
Claude Design 프로토타입(`design/SkinMatch.dc.html`)을 화면·색·여백까지 그대로 옮겼어요.

- 언어 / 프레임워크: **Dart 3 · Flutter 3.47** (Android · iOS · Web)
- 상태관리 `flutter_riverpod` · 라우팅 `go_router` · 로컬 저장 `hive_ce`
- 로그인 `firebase_auth` + `kakao_flutter_sdk_user` + `google_sign_in` (Apple은 Firebase `AppleAuthProvider`)
- 바코드 `mobile_scanner` · 공유 `share_plus` · 제품 API `dio`
- 폰트 Pretendard (`assets/fonts`, SIL OFL)

## 바로 실행해 보기 (설정 없이)

```bash
flutter pub get
flutter run -d chrome        # 또는 연결된 휴대폰
```

키를 넣지 않으면 **데모 모드**로 실행돼요.

| 기능 | 키가 없을 때 | 키를 넣으면 |
|---|---|---|
| 로그인 | 버튼을 누르면 바로 로그인돼요 (프로토타입과 같음) | Firebase로 실제 로그인 |
| 제품 검색 · 바코드 | 샘플 제품 20개로 검색, "샘플 바코드로 스캔해 보기" 버튼 표시 | `PRODUCT_API_BASE_URL` 서버에서 검색, 카메라로 실제 스캔 |

## 실제 로그인 연결

설정값은 모두 빌드할 때 넣어요. 저장소에는 예시 파일만 있고, 실제 키 파일은 `.gitignore`에 들어 있어요.

```bash
cp config/env.example.json config/env.json          # 값 채우기
cp ios/Flutter/Secrets.example.xcconfig ios/Flutter/Secrets.xcconfig
echo "kakao.nativeAppKey=네이티브_앱_키" >> android/local.properties

flutter run --dart-define-from-file=config/env.json
```

### 1. Firebase
1. Firebase 콘솔에서 프로젝트를 만들고 Android(`app.skinmatch.skinmatch`), iOS, Web 앱을 추가해요.
2. 각 앱의 `apiKey`, `appId`, `messagingSenderId`, `projectId`, `authDomain`을 `config/env.json`에 넣어요.
3. Authentication → 로그인 방법에서 **이메일/비밀번호, Google, Apple**을 켜요.

### 2. 카카오 (Firebase OpenID Connect)
Firebase에는 카카오 제공업체가 없어서 **OIDC**로 연결해요. Firebase에서 OIDC를 쓰려면 Identity Platform으로 업그레이드해야 해요.
1. [Kakao Developers](https://developers.kakao.com) → 내 애플리케이션 → 앱 키에서 **네이티브 앱 키**와 **JavaScript 키**를 복사해요.
2. 카카오 로그인 → **OpenID Connect 활성화**를 켜요. (꺼져 있으면 앱에서 안내 문구가 떠요)
3. 플랫폼에 Android 패키지명·키 해시, iOS 번들 ID, Web 도메인을 등록해요.
4. Firebase Authentication → 새 제공업체 → OpenID Connect
   - 제공업체 ID: `oidc.kakao` (다르게 정했다면 `KAKAO_OIDC_PROVIDER_ID`도 같게)
   - 발급자: `https://kauth.kakao.com`
   - 클라이언트 ID: 카카오 ID 토큰의 `aud` 값과 같아야 해요. 어떤 앱 키가 `aud`로 들어오는지 확실하지 않아서,
     처음 연결할 때 로그인 후 받은 ID 토큰을 [jwt.io](https://jwt.io)에서 열어 `aud`를 확인하고 그 값을 넣어 주세요.
5. 네이티브 앱 키는 세 곳에 들어가요.
   - `config/env.json`의 `KAKAO_NATIVE_APP_KEY` (앱 코드)
   - `android/local.properties`의 `kakao.nativeAppKey` 또는 환경 변수 `KAKAO_NATIVE_APP_KEY` (Android 리다이렉트 스킴)
   - `ios/Flutter/Secrets.xcconfig`의 `KAKAO_NATIVE_APP_KEY` (iOS URL 스킴)

### 3. Google
- Android: Firebase에 SHA-1을 등록하고, **웹 클라이언트 ID**를 `GOOGLE_SERVER_CLIENT_ID`에 넣어요.
- iOS: `GoogleService-Info.plist`의 `CLIENT_ID` / `REVERSED_CLIENT_ID`를 `GOOGLE_IOS_CLIENT_ID`와 `Secrets.xcconfig`에 넣어요.
- Web: Firebase 팝업으로 로그인해요. 추가 설정은 없어요.

### 4. Apple
- Apple Developer에서 App ID에 **Sign in with Apple**을 켜요.
- Xcode → Runner → Signing & Capabilities → `+ Capability` → Sign in with Apple을 추가해요.
  (`ios/Runner/Runner.entitlements`에 필요한 값이 이미 들어 있어요. Xcode가 이 파일을 연결하면 돼요.)
- Android·Web에서 Apple 로그인을 쓰려면 Firebase 문서대로 Services ID와 키를 Firebase에 등록해야 해요.

## 제품 DB API 연결

`PRODUCT_API_BASE_URL`을 넣으면 `ApiProductRepository`로 바뀌어요. 서버는 아래 형식만 맞추면 돼요.

```
GET /products/search?q={검색어}&limit=5   → Product[]
GET /products/barcode/{barcode}           → Product (없으면 404)
GET /products?cat={카테고리}&limit=50      → Product[]   (대체 추천 후보)
GET /products/{id}                        → Product
```

```json
{ "id": "p1", "brand": "무드랩", "name": "레티놀 0.1% 나이트 세럼", "category": "세럼",
  "ingredients": ["정제수", "레티놀 0.1%", "세라마이드NP"], "barcode": "880...", "imageUrl": null }
```

## 폴더 구조

```
lib/
  main.dart                 설정에 따라 Firebase/데모 로그인, API/샘플 DB 선택
  app/                      앱 · 라우터 · 폰 프레임(넓은 화면) · 토스트
  core/                     디자인 토큰(theme), 아이콘 SVG, 분석 엔진, 성분 DB, 샘플 데이터, 설정
  data/                     로그인 · 제품 API · 로컬 저장소(Hive)
  models/                   Product, RoutineStep, SkinProfile, RoutineResult, SavedRoutine
  providers/                세션 · 루틴 · 화장대 · 토스트 (Riverpod)
  features/auth/            로그인, 피부 진단 3단계
  features/analyzer/        루틴 입력, 분석 결과, 바텀 시트(화장대·성분 사전·스캔·상세·등록)
  features/vanity/          내 화장대
  features/profile/         마이페이지
design/                     원본 프로토타입과 로고 (참고용)
docs/Flutter 개발 가이드.md   화면 명세 · 분석 규칙 · 이번 구현에서 바뀐 점
```

## 테스트

```bash
flutter analyze
flutter test
```

- `test/analyzer_engine_test.dart`: 프로토타입의 JS 분석 로직을 Node로 실행해 얻은 결과와 **숫자·태그·순서가 똑같은지** 6가지 루틴으로 확인해요.
- `test/app_flow_test.dart`: 실제 Pretendard 폰트로 로그인 → 진단 → 샘플 루틴 분석 → 저장 흐름을 돌리고, 360px 좁은 화면에서 넘침이 없는지 확인해요.

> 성분 사전 문구와 충돌 가중치는 목업용 일반 정보예요. 출시 전에 피부과 전문의나 화장품 전문가의 검수를 받으세요.
