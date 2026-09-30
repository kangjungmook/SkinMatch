import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'data/auth_repository.dart';
import 'data/local_store.dart';
import 'data/product_repository.dart';
import 'providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.open();

  if (AppConfig.hasKakao) {
    KakaoSdk.init(
      nativeAppKey: AppConfig.kakaoNativeAppKey.isEmpty ? null : AppConfig.kakaoNativeAppKey,
      javaScriptAppKey: AppConfig.kakaoJsAppKey.isEmpty ? null : AppConfig.kakaoJsAppKey,
    );
  }

  AuthRepository auth;
  if (AppConfig.hasFirebase) {
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    auth = FirebaseAuthRepository();
  } else {
    // Firebase 설정(config/env.json)이 없으면 프로토타입처럼 바로 로그인되는 데모 모드로 실행해요.
    debugPrint('[SkinMatch] Firebase 설정이 없어 데모 로그인으로 실행합니다. README의 "실제 로그인 연결"을 참고하세요.');
    auth = DemoAuthRepository();
  }

  final ProductRepository products = AppConfig.hasProductApi
      ? ApiProductRepository(AppConfig.productApiBaseUrl)
      : const MockProductRepository();
  if (!AppConfig.hasProductApi && kDebugMode) {
    debugPrint('[SkinMatch] PRODUCT_API_BASE_URL이 없어 샘플 제품 20개로 검색합니다.');
  }

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
        productRepositoryProvider.overrideWithValue(products),
      ],
      child: const SkinMatchApp(),
    ),
  );
}
