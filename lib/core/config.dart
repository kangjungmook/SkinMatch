import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// 빌드 시 `--dart-define-from-file=config/env.json`으로 넣는 설정값.
/// 키가 비어 있으면 해당 기능은 데모 모드로 동작해요 (README 참고).
abstract final class AppConfig {
  // Firebase
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseAppIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const firebaseAppIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const firebaseAppIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const firebaseIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  // Kakao (developers.kakao.com → 내 애플리케이션 → 앱 키)
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  static const kakaoJsAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY');

  /// Firebase Authentication에 등록한 카카오 OIDC 제공업체 ID
  static const kakaoOidcProviderId = String.fromEnvironment('KAKAO_OIDC_PROVIDER_ID', defaultValue: 'oidc.kakao');

  // Google Sign-In
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// 제품 DB API (예: https://api.skinmatch.app). 비어 있으면 샘플 제품 20개로 검색해요.
  static const productApiBaseUrl = String.fromEnvironment('PRODUCT_API_BASE_URL');

  static String get _firebaseAppId {
    if (kIsWeb) return firebaseAppIdWeb;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => firebaseAppIdIos,
      TargetPlatform.android => firebaseAppIdAndroid,
      _ => '',
    };
  }

  static bool get hasFirebase => firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty && _firebaseAppId.isNotEmpty;
  static bool get hasKakao => kIsWeb ? kakaoJsAppKey.isNotEmpty : kakaoNativeAppKey.isNotEmpty;
  static bool get hasProductApi => productApiBaseUrl.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: _firebaseAppId,
    messagingSenderId: firebaseSenderId,
    projectId: firebaseProjectId,
    authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
    storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    iosBundleId: firebaseIosBundleId.isEmpty ? null : firebaseIosBundleId,
    iosClientId: googleIosClientId.isEmpty ? null : googleIosClientId,
  );
}
