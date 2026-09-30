import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../core/sample_data.dart';
import '../models/product.dart';
import '../models/routine_result.dart';
import '../models/skin_profile.dart';

/// 기기에 저장하는 데이터 (Hive). 사용자별로 키를 나눠요.
/// 저장 항목: 화장대 제품, 저장한 루틴, 최근 분석 5개, 피부 프로필, 진단 완료 여부.
class LocalStore {
  LocalStore(this._box);

  static const boxName = 'skinmatch';
  final Box<String> _box;

  static Future<LocalStore> open() async {
    await Hive.initFlutter();
    return LocalStore(await Hive.openBox<String>(boxName));
  }

  /// 테스트용 메모리 저장소 (파일을 쓰지 않아요)
  static Future<LocalStore> openInMemory() async {
    return LocalStore(await Hive.openBox<String>('$boxName-${DateTime.now().microsecondsSinceEpoch}', bytes: Uint8List(0)));
  }

  String _k(String uid, String key) => '$uid/$key';

  T? _read<T>(String uid, String key, T Function(dynamic) decode) {
    final raw = _box.get(_k(uid, key));
    if (raw == null) return null;
    try {
      return decode(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String uid, String key, Object value) => _box.put(_k(uid, key), jsonEncode(value));

  List<Product> vanity(String uid) =>
      _read(uid, 'vanity', (j) => (j as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList()) ??
      List.of(kSampleVanity);
  Future<void> saveVanity(String uid, List<Product> v) => _write(uid, 'vanity', v.map((p) => p.toJson()).toList());

  List<SavedRoutine> _routines(String uid, String key) =>
      _read(uid, key, (j) => (j as List).map((e) => SavedRoutine.fromJson(Map<String, dynamic>.from(e as Map))).toList()) ?? [];

  List<SavedRoutine> combos(String uid) => _routines(uid, 'combos');
  Future<void> saveCombos(String uid, List<SavedRoutine> v) => _write(uid, 'combos', v.map((r) => r.toJson()).toList());

  List<SavedRoutine> recent(String uid) => _routines(uid, 'recent');
  Future<void> saveRecent(String uid, List<SavedRoutine> v) => _write(uid, 'recent', v.map((r) => r.toJson()).toList());

  SkinProfile profile(String uid) =>
      _read(uid, 'profile', (j) => SkinProfile.fromJson(Map<String, dynamic>.from(j as Map))) ?? const SkinProfile();
  Future<void> saveProfile(String uid, SkinProfile p) => _write(uid, 'profile', p.toJson());

  bool onboarded(String uid) => _read(uid, 'onboarded', (j) => j as bool) ?? false;
  Future<void> setOnboarded(String uid, bool v) => _write(uid, 'onboarded', v);
}
