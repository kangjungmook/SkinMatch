import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analyzer_engine.dart';
import '../data/auth_repository.dart';
import '../data/local_store.dart';
import '../data/product_repository.dart';

/// main()에서 override 해요.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('override in main'));
final authRepositoryProvider = Provider<AuthRepository>((ref) => throw UnimplementedError('override in main'));
final productRepositoryProvider = Provider<ProductRepository>((ref) => const MockProductRepository());
final analyzerEngineProvider = Provider<AnalyzerEngine>((ref) => const AnalyzerEngine());

/// 화면 위쪽에 잠깐 떴다 사라지는 안내 문구
class ToastNotifier extends Notifier<String> {
  Timer? _t;

  @override
  String build() {
    ref.onDispose(() => _t?.cancel());
    return '';
  }

  void show(String msg) {
    _t?.cancel();
    state = msg;
    _t = Timer(const Duration(milliseconds: 2200), () => state = '');
  }
}

final toastProvider = NotifierProvider<ToastNotifier, String>(ToastNotifier.new);
