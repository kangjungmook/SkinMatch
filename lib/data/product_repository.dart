import 'package:dio/dio.dart';

import '../core/sample_data.dart';
import '../models/product.dart';

/// 제품 DB. 실제 서버를 붙일 때는 [ApiProductRepository]만 쓰면 돼요.
abstract class ProductRepository {
  /// GET /products/search?q=&cat=&limit=5
  Future<List<Product>> search(String query, {String? category});

  /// GET /products/barcode/{barcode}
  Future<Product?> byBarcode(String barcode);

  /// 대체 추천 후보 (같은 카테고리). GET /products?cat=
  Future<List<Product>> byCategory(String category);

  /// 샘플 루틴·데모에 쓰는 id 조회
  Future<Product?> byId(String id);
}

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(String baseUrl)
    : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)));

  final Dio _dio;

  List<Product> _list(dynamic data) => (data as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  @override
  Future<List<Product>> search(String query, {String? category}) async {
    final res = await _dio.get<dynamic>('/products/search', queryParameters: {'q': query, 'cat': ?category, 'limit': 5});
    return _list(res.data);
  }

  @override
  Future<Product?> byBarcode(String barcode) async {
    try {
      final res = await _dio.get<dynamic>('/products/barcode/$barcode');
      return Product.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<Product>> byCategory(String category) async {
    final res = await _dio.get<dynamic>('/products', queryParameters: {'cat': category, 'limit': 50});
    return _list(res.data);
  }

  @override
  Future<Product?> byId(String id) async {
    try {
      final res = await _dio.get<dynamic>('/products/$id');
      return Product.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// 샘플 제품 20개로 동작하는 목업 DB (프로토타입의 searchCatalog와 같은 규칙)
class MockProductRepository implements ProductRepository {
  const MockProductRepository({this.catalog = kSampleCatalog});

  final List<Product> catalog;

  static String _norm(String s) => s.replaceAll(RegExp(r'\s'), '').toLowerCase();

  List<Product> searchSync(String q) {
    final toks = q.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (toks.isEmpty) return const [];
    final hits = <({Product p, int score})>[];
    for (final p in catalog) {
      final nm = _norm(p.brand + p.name);
      final hay = nm + _norm(p.category + p.ingredients.join());
      if (!toks.every((t) => hay.contains(_norm(t)))) continue;
      hits.add((p: p, score: toks.where((t) => nm.contains(_norm(t))).length));
    }
    // 안정 정렬 (점수 내림차순, 동률은 카탈로그 순서)
    final indexed = hits.indexed.toList()
      ..sort((a, b) {
        final c = b.$2.score - a.$2.score;
        return c != 0 ? c : a.$1 - b.$1;
      });
    return indexed.take(5).map((e) => e.$2.p).toList();
  }

  @override
  Future<List<Product>> search(String query, {String? category}) async => searchSync(query);

  @override
  Future<Product?> byBarcode(String barcode) async {
    for (final p in catalog) {
      if (p.barcode == barcode) return p;
    }
    return null;
  }

  @override
  Future<List<Product>> byCategory(String category) async => catalog.where((p) => p.category == category).toList();

  @override
  Future<Product?> byId(String id) async {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }
}
