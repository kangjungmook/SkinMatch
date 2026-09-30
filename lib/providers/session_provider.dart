import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../models/skin_profile.dart';
import 'core_providers.dart';

class SessionState {
  const SessionState({this.ready = false, this.user, this.onboarded = false, this.profile = const SkinProfile(), this.busy = false});

  /// 첫 로그인 상태 확인이 끝났는지
  final bool ready;
  final AppUser? user;
  final bool onboarded;
  final SkinProfile profile;

  /// 이메일 로그인 진행 중
  final bool busy;

  bool get loggedIn => user != null;

  SessionState copyWith({bool? ready, AppUser? user, bool clearUser = false, bool? onboarded, SkinProfile? profile, bool? busy}) =>
      SessionState(
        ready: ready ?? this.ready,
        user: clearUser ? null : (user ?? this.user),
        onboarded: onboarded ?? this.onboarded,
        profile: profile ?? this.profile,
        busy: busy ?? this.busy,
      );
}

/// 로그인 · 피부 진단 · 피부 프로필
class SessionNotifier extends Notifier<SessionState> {
  StreamSubscription<AppUser?>? _sub;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  @override
  SessionState build() {
    ref.onDispose(() => _sub?.cancel());
    _sub = _auth.changes().listen(_onUser);
    final current = _auth.currentUser;
    if (current != null) return _load(current);
    // Firebase는 저장된 로그인 상태를 비동기로 복원해요. 첫 이벤트가 늦으면 로그인 화면을 보여 줘요.
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!state.ready) state = state.copyWith(ready: true);
    });
    return const SessionState();
  }

  SessionState _load(AppUser u) {
    final store = ref.read(localStoreProvider);
    return SessionState(ready: true, user: u, onboarded: store.onboarded(u.uid), profile: store.profile(u.uid));
  }

  void _onUser(AppUser? u) {
    if (u == null) {
      state = const SessionState(ready: true);
    } else if (state.user?.uid != u.uid || !state.ready) {
      state = _load(u);
    } else {
      state = state.copyWith(user: u);
    }
  }

  void _signedIn(AppUser u) {
    if (state.user?.uid != u.uid) state = _load(u);
  }

  /// 소셜 로그인. 실패 문구를 돌려줘요 (취소는 null).
  Future<String?> social(LoginMethod m) async {
    try {
      final u = switch (m) {
        LoginMethod.kakao => await _auth.signInWithKakao(),
        LoginMethod.apple => await _auth.signInWithApple(),
        LoginMethod.google => await _auth.signInWithGoogle(),
        LoginMethod.email => throw ArgumentError(m),
      };
      _signedIn(u);
      return null;
    } on AuthCancelled {
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return '로그인에 실패했어요. 잠시 후 다시 시도해 주세요';
    }
  }

  Future<String?> email(String email, String pw, {required bool signup}) async {
    state = state.copyWith(busy: true);
    try {
      final u = signup ? await _auth.signUpWithEmail(email, pw) : await _auth.signInWithEmail(email, pw);
      state = state.copyWith(busy: false);
      _signedIn(u);
      return null;
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false);
      return e.message;
    } catch (_) {
      state = state.copyWith(busy: false);
      return '로그인에 실패했어요. 잠시 후 다시 시도해 주세요';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordReset(email);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = const SessionState(ready: true);
  }

  /// 진단 중 선택을 바로 반영해요 (진단 화면의 임시 상태)
  void setProfile(SkinProfile p) {
    state = state.copyWith(profile: p);
    final u = state.user;
    if (u != null) ref.read(localStoreProvider).saveProfile(u.uid, p);
  }

  void finishOnboarding() {
    state = state.copyWith(onboarded: true);
    final u = state.user;
    if (u != null) ref.read(localStoreProvider).setOnboarded(u.uid, true);
  }

  void redoOnboarding() {
    state = state.copyWith(onboarded: false);
    final u = state.user;
    if (u != null) ref.read(localStoreProvider).setOnboarded(u.uid, false);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
