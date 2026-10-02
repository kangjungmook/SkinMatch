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

## 사진으로 전성분 입력

루틴 단계의 검색칸 옆 **카메라 버튼**(또는 검색 결과가 없을 때 "사진으로 입력")을 누르면, 제품 뒷면 사진에서 전성분을 읽어요.

1. **글자 인식:** Google ML Kit 한국어 모델로 휴대폰 안에서 읽어요. 무료이고 사진을 서버로 보내지 않아요. **Android·iOS에서만 동작하고 웹은 지원하지 않아요.**
2. **정리:** "전성분" 뒤부터 "사용시의 주의사항" 같은 문구 앞까지 잘라요. 줄바꿈으로 끊긴 이름을 잇고, `1,2-헥산다이올`처럼 숫자 사이 쉼표는 나누지 않아요.
3. **교정:** 성분 사전과 자모 단위로 비교해서 오타를 고쳐요 (`lib/core/label_parser.dart`).
   - 회색: 사전과 일치 / 노란색: 자동으로 고침 / 빨간색: 사전에 없음
   - 레티놀·AHA처럼 충돌 분석에 중요한 성분이 고쳐졌거나 사전에 없으면, 사용자가 확인해야 루틴에 넣을 수 있어요.

### 성분 사전 바꾸기 (식약처 데이터)
앱에 들어 있는 `assets/data/ingredient_dictionary.json`은 90개 정도의 **임시 사전**이에요. 식약처 "화장품 원료성분정보"로 바꾸면 교정이 훨씬 정확해져요.

1. data.go.kr에서 [식품의약품안전처_화장품 원료성분정보](https://www.data.go.kr/data/15111774/openapi.do) 활용신청 (개발용은 자동 승인)
2. 마이페이지에서 인증키(Decoding) 복사
3. 프로젝트 폴더에서 실행:
   ```bash
   MFDS_SERVICE_KEY=발급받은키 dart run tool/fetch_mfds_ingredients.dart
   ```
4. 바뀐 `assets/data/ingredient_dictionary.json`을 커밋해요.

> 이 스크립트는 응답 명세(Models)대로 만들고 가짜 서버로 시험했어요. 실제 API로는 아직 실행해 보지 못했어요. 특히 이명(`INGR_SYNONYM`) 칸의 구분 방식은 실제 데이터를 보고 확인해 주세요.

### 플랫폼 설정 (처음 한 번)
- **Android:** `android/app/build.gradle.kts`에 ML Kit 한국어 모델이 추가돼 있어요. 추가 작업은 없어요.
- **iOS:** 최소 버전을 15.5로 올려 두었어요. `flutter build ios`를 한 번 실행하면 `ios/Podfile`이 생겨요. 그 파일을 아래처럼 고친 뒤 `cd ios && pod install`을 실행하세요.
  ```ruby
  platform :ios, '15.5'
  # target 'Runner' do 안에 추가
  pod 'GoogleMLKit/TextRecognitionKorean', '~> 9.0.0'
  ```
  Xcode → Runner → Build Settings → Excluded Architectures → Any SDK에 `armv7`도 넣어 주세요 (ML Kit 요구 사항).

## 네이버 쇼핑 검색 연결 (`functions/`)

제품 검색은 네이버 쇼핑 검색 API를 씁니다. 키가 앱에 들어가면 안 되기 때문에 **서버(Firebase Cloud Functions)가 대신 불러요.**

- 네이버 응답에는 **제품명·브랜드·카테고리·사진만 있고 전성분과 바코드는 없어요.**
- 그래서 검색해서 고른 제품은 카드에 "전성분 정보가 아직 없어요"가 뜨고, **사진으로 / 주요 성분 / 직접 입력** 중 하나로 채워야 분석에 들어가요.
- "주요 성분"을 고르면 제품 이름(예: "레티놀 세럼" → 레티놀)과 종류(선크림 → 자외선 차단)를 보고 미리 골라 둬요. 사용자가 확인해야 들어가요.
- 전성분을 넣지 않은 제품은 분석에서 빠지고, 결과 화면에 그 사실을 알려 줘요.

### 1. 네이버 키 발급 (직접 해야 해요)
1. [네이버 개발자센터](https://developers.naver.com/apps/#/register) → 애플리케이션 등록
2. 사용 API: **검색** 선택, 환경: WEB 설정 → `http://localhost` 입력
3. 발급된 **Client ID**와 **Client Secret**을 복사해 둬요. (코드나 저장소에 넣지 마세요)

### 2. 내 컴퓨터에서 바로 써 보기 (Firebase 없이)
```bash
cd functions
npm install
NAVER_CLIENT_ID=발급받은_ID NAVER_CLIENT_SECRET=발급받은_Secret npm run dev
# → http://localhost:8787 에서 서버가 떠요
# 확인: http://localhost:8787/products/search?q=토너

# 다른 터미널에서 (프로젝트 폴더)
flutter run -d chrome --dart-define=PRODUCT_API_BASE_URL=http://localhost:8787
```
> Windows PowerShell이라면 `$env:NAVER_CLIENT_ID="..."; $env:NAVER_CLIENT_SECRET="..."; npm run dev` 처럼 넣어요.
> 휴대폰에서는 `localhost`가 휴대폰 자신을 가리켜서 안 돼요. 휴대폰은 아래 3번(배포)을 한 뒤 그 주소를 쓰세요.

### 3. Firebase에 배포 (휴대폰에서 쓰려면)
Cloud Functions 배포는 Firebase **Blaze(종량제) 요금제**가 필요해요.
```bash
npm install -g firebase-tools
firebase login
cp .firebaserc.example .firebaserc     # 안의 프로젝트 ID를 내 것으로 바꾸기
firebase functions:secrets:set NAVER_CLIENT_ID
firebase functions:secrets:set NAVER_CLIENT_SECRET
firebase deploy --only functions
```
배포가 끝나면 나오는 주소(`https://asia-northeast3-<프로젝트ID>.cloudfunctions.net/api`)를 `config/env.json`의 `PRODUCT_API_BASE_URL`에 넣어요.

### 서버 테스트
```bash
cd functions && npm test
```
네이버 공식 문서의 응답 형식대로 만든 가짜 응답으로 시험해요. **실제 네이버 키로는 아직 실행해 보지 못했어요.** 처음 연결할 때 아래를 확인해 주세요.
- 화장품만 남기는 기준이 `category1 == "화장품/미용"`이에요. 실제 분류 이름이 다르면 `functions/src/naver.js`의 `toProduct`를 고쳐요.
- 단계 종류(토너·세럼…)는 제품명과 네이버 카테고리 단어로 정해요 (`mapCategory`). 틀리면 사용자가 카드에서 바꿀 수 있어요.

## 제품 DB API 형식

`PRODUCT_API_BASE_URL`을 넣으면 `ApiProductRepository`로 바뀌어요. 서버는 아래 형식만 맞추면 돼요. (`functions/`의 네이버 서버도 이 형식이에요. 바코드·대체 추천은 네이버에 정보가 없어서 404·빈 목록을 돌려줘요.)

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
`ingredients`가 빈 배열이면 "전성분 없는 제품"으로 보고 사용자에게 입력하게 해요. `source: "naver"`는 출처 표시용이에요.

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
functions/                  제품 검색 서버 (Firebase Cloud Functions, 네이버 쇼핑 검색)
design/                     원본 프로토타입과 로고 (참고용)
docs/Flutter 개발 가이드.md   화면 명세 · 분석 규칙 · 이번 구현에서 바뀐 점
```

## 테스트

```bash
flutter analyze
flutter test
```

- `test/analyzer_engine_test.dart`: 프로토타입의 JS 분석 로직을 Node로 실행해 얻은 결과와 **숫자·태그·순서가 똑같은지** 6가지 루틴으로 확인해요.
- `test/naver_search_test.dart`: 전성분 없는 검색 결과 → 주요 성분(이름 추정) → 분석 → "간단 분석 / 빠진 제품" 안내까지, 440px·360px에서 확인해요.
- `functions/test/api.test.js`: 서버가 네이버 응답을 화장품만 남기고, 중복을 합치고, 앱 형식으로 바꾸는지 확인해요.
- `test/app_flow_test.dart`: 실제 Pretendard 폰트로 로그인 → 진단 → 샘플 루틴 분석 → 저장 흐름을 돌리고, 360px 좁은 화면에서 넘침이 없는지 확인해요.

> 성분 사전 문구와 충돌 가중치는 목업용 일반 정보예요. 출시 전에 피부과 전문의나 화장품 전문가의 검수를 받으세요.
