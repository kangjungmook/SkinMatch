import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../core/config.dart';

enum LoginMethod { kakao, apple, google, email }

class AppUser {
  const AppUser({required this.uid, required this.name, required this.method, this.email});

  final String uid;
  final String name;
  final LoginMethod method;
  final String? email;
}

/// 사용자에게 보여 줄 수 있는 로그인 오류
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 로그인 창을 사용자가 닫았을 때 (메시지 없이 조용히 무시)
class AuthCancelled implements Exception {
  const AuthCancelled();
}

abstract class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> changes();
  Future<AppUser> signInWithKakao();
  Future<AppUser> signInWithApple();
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

/// Firebase Authentication 기반 실제 로그인.
///
/// - 카카오: Kakao SDK로 로그인 → ID 토큰(OIDC)으로 Firebase `oidc.kakao` 제공업체에 로그인
/// - Apple: Firebase AppleAuthProvider (iOS 네이티브 / 웹 팝업 / Android 웹 흐름)
/// - Google: google_sign_in으로 ID 토큰 → Firebase (웹은 Firebase 팝업)
/// - 이메일: Firebase 이메일/비밀번호
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;
  LoginMethod? _lastMethod;
  bool _googleReady = false;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> changes() => _auth.authStateChanges().map(_map);

  AppUser? _map(fb.User? u) {
    if (u == null) return null;
    final providers = u.providerData.map((p) => p.providerId).toList();
    final method =
        _lastMethod ??
        (providers.contains('apple.com')
            ? LoginMethod.apple
            : providers.contains('google.com')
            ? LoginMethod.google
            : providers.any((p) => p.startsWith('oidc.'))
            ? LoginMethod.kakao
            : LoginMethod.email);
    final email = u.email;
    final name = (u.displayName?.trim().isNotEmpty ?? false)
        ? u.displayName!.trim()
        : (email != null && email.contains('@') ? email.split('@').first : '회원');
    return AppUser(uid: u.uid, name: name, method: method, email: email);
  }

  Future<AppUser> _finish(Future<fb.UserCredential> Function() run, LoginMethod m) async {
    try {
      final cred = await run();
      _lastMethod = m;
      return _map(cred.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  @override
  Future<AppUser> signInWithKakao() async {
    if (!AppConfig.hasKakao) throw const AuthFailure('카카오 앱 키가 설정되지 않았어요');
    final kakao.OAuthToken token;
    try {
      token = (!kIsWeb && await kakao.isKakaoTalkInstalled())
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();
    } on kakao.KakaoAuthException catch (e) {
      if (e.error == kakao.AuthErrorCause.accessDenied) throw const AuthCancelled();
      throw const AuthFailure('카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요');
    } catch (e) {
      if (e.toString().contains('CANCELED')) throw const AuthCancelled();
      throw const AuthFailure('카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요');
    }
    if (token.idToken == null) {
      throw const AuthFailure('카카오 OpenID Connect가 꺼져 있어요. 카카오 개발자 콘솔에서 켜 주세요');
    }
    final provider = fb.OAuthProvider(AppConfig.kakaoOidcProviderId);
    final user = await _finish(
      () => _auth.signInWithCredential(provider.credential(idToken: token.idToken, accessToken: token.accessToken)),
      LoginMethod.kakao,
    );
    // Firebase 프로필에 이름이 없으면 카카오 닉네임을 채워요.
    if (_auth.currentUser?.displayName == null) {
      try {
        final me = await kakao.UserApi.instance.me();
        final nick = me.kakaoAccount?.profile?.nickname;
        if (nick != null && nick.isNotEmpty) {
          await _auth.currentUser?.updateDisplayName(nick);
          return AppUser(uid: user.uid, name: nick, method: LoginMethod.kakao, email: user.email);
        }
      } catch (_) {}
    }
    return user;
  }

  @override
  Future<AppUser> signInWithApple() {
    final provider = fb.AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _finish(() => kIsWeb ? _auth.signInWithPopup(provider) : _auth.signInWithProvider(provider), LoginMethod.apple);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      return _finish(() => _auth.signInWithPopup(fb.GoogleAuthProvider()), LoginMethod.google);
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        serverClientId: AppConfig.googleServerClientId.isEmpty ? null : AppConfig.googleServerClientId,
        clientId: AppConfig.googleIosClientId.isEmpty ? null : AppConfig.googleIosClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const AuthCancelled();
      throw const AuthFailure('Google 로그인에 실패했어요. 잠시 후 다시 시도해 주세요');
    }
    final idToken = account.authentication.idToken;
    return _finish(() => _auth.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: idToken)), LoginMethod.google);
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) =>
      _finish(() => _auth.signInWithEmailAndPassword(email: email, password: password), LoginMethod.email);

  @override
  Future<AppUser> signUpWithEmail(String email, String password) =>
      _finish(() => _auth.createUserWithEmailAndPassword(email: email, password: password), LoginMethod.email);

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    final m = _lastMethod ?? currentUser?.method;
    _lastMethod = null;
    if (m == LoginMethod.kakao && AppConfig.hasKakao) {
      try {
        await kakao.UserApi.instance.logout();
      } catch (_) {}
    }
    if (m == LoginMethod.google && !kIsWeb && _googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  static String _message(String code) => switch (code) {
    'invalid-email' => '올바른 이메일 주소를 입력해 주세요',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => '이메일 또는 비밀번호가 맞지 않아요',
    'email-already-in-use' => '이미 가입된 이메일이에요. 로그인해 주세요',
    'weak-password' => '비밀번호는 8자 이상이어야 해요',
    'too-many-requests' => '시도가 너무 많아요. 잠시 후 다시 시도해 주세요',
    'network-request-failed' => '네트워크 연결을 확인해 주세요',
    'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' || 'canceled' => '로그인을 취소했어요',
    'operation-not-allowed' => '이 로그인 방식이 아직 켜져 있지 않아요 (Firebase 콘솔 확인)',
    'account-exists-with-different-credential' => '같은 이메일로 다른 방식으로 가입된 계정이 있어요',
    _ => '로그인에 실패했어요. 잠시 후 다시 시도해 주세요',
  };
}

/// Firebase 설정이 없을 때 쓰는 데모 로그인. 프로토타입처럼 바로 로그인돼요.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({this.demoName = '정묵'});

  final String demoName;
  AppUser? _user;
  final _ctrl = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> changes() => _ctrl.stream;

  AppUser _set(LoginMethod m, [String? email]) {
    _user = AppUser(uid: 'demo', name: demoName, method: m, email: email);
    _ctrl.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signInWithKakao() async => _set(LoginMethod.kakao);
  @override
  Future<AppUser> signInWithApple() async => _set(LoginMethod.apple);
  @override
  Future<AppUser> signInWithGoogle() async => _set(LoginMethod.google);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return _set(LoginMethod.email, email);
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password) => signInWithEmail(email, password);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}
