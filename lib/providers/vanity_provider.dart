import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/routine_result.dart';
import 'core_providers.dart';
import 'session_provider.dart';

class VanityState {
  const VanityState({this.products = const [], this.combos = const [], this.recent = const []});

  final List<Product> products;

  /// 저장한 루틴
  final List<SavedRoutine> combos;

  /// 최근 분석 (최대 5개)
  final List<SavedRoutine> recent;

  VanityState copyWith({List<Product>? products, List<SavedRoutine>? combos, List<SavedRoutine>? recent}) =>
      VanityState(products: products ?? this.products, combos: combos ?? this.combos, recent: recent ?? this.recent);
}

/// 내 화장대 · 저장한 루틴 · 최근 분석 (로그인한 사용자별로 Hive에 저장)
class VanityNotifier extends Notifier<VanityState> {
  String? get _uid => ref.read(sessionProvider).user?.uid;

  @override
  VanityState build() {
    final uid = ref.watch(sessionProvider.select((s) => s.user?.uid));
    if (uid == null) return const VanityState();
    final store = ref.read(localStoreProvider);
    return VanityState(products: store.vanity(uid), combos: store.combos(uid), recent: store.recent(uid));
  }

  void _persist() {
    final uid = _uid;
    if (uid == null) return;
    final store = ref.read(localStoreProvider);
    store.saveVanity(uid, state.products);
    store.saveCombos(uid, state.combos);
    store.saveRecent(uid, state.recent);
  }

  void addProduct(Product p) {
    state = state.copyWith(products: [p, ...state.products]);
    _persist();
  }

  void removeProduct(String id) {
    state = state.copyWith(products: state.products.where((p) => p.id != id).toList());
    _persist();
  }

  void saveCombo(SavedRoutine r) {
    state = state.copyWith(combos: [r, ...state.combos]);
    _persist();
  }

  void pushRecent(SavedRoutine r) {
    state = state.copyWith(recent: [r, ...state.recent].take(5).toList());
    _persist();
  }
}

final vanityProvider = NotifierProvider<VanityNotifier, VanityState>(VanityNotifier.new);

/// 내 화장대 카테고리 필터 (탭을 옮겨도 유지)
class VanityFilterNotifier extends Notifier<String> {
  @override
  String build() => '전체';

  void set(String v) => state = v;
}

final vanityFilterProvider = NotifierProvider<VanityFilterNotifier, String>(VanityFilterNotifier.new);
