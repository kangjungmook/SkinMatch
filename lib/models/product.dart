/// 화장품 제품. 카탈로그 검색 결과와 내 화장대 항목이 같은 모델을 써요.
class Product {
  const Product({
    required this.id,
    required this.brand,
    required this.name,
    required this.category,
    required this.ingredients,
    this.registeredAt,
    this.imageUrl,
    this.barcode,
  });

  final String id;
  final String brand;
  final String name;

  /// 토너 | 에센스·앰플 | 세럼 | 아이크림 | 크림 | 선크림 | 메이크업 | 기타
  final String category;
  final List<String> ingredients;

  /// 내 화장대에 등록한 날짜 (예: 2026.09.21). 카탈로그 제품은 null.
  final String? registeredAt;
  final String? imageUrl;
  final String? barcode;

  /// 분석 엔진이 읽는 텍스트: 첫 줄은 제품 라벨, 둘째 줄은 전성분.
  String get routineText => '$brand $name\n${ingredients.join(', ')}';

  Product copyWith({String? registeredAt}) => Product(
    id: id,
    brand: brand,
    name: name,
    category: category,
    ingredients: ingredients,
    registeredAt: registeredAt ?? this.registeredAt,
    imageUrl: imageUrl,
    barcode: barcode,
  );

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'].toString(),
    brand: j['brand'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    ingredients: List<String>.from(j['ingredients'] as List),
    registeredAt: j['registeredAt'] as String?,
    imageUrl: j['imageUrl'] as String?,
    barcode: j['barcode'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'name': name,
    'category': category,
    'ingredients': ingredients,
    if (registeredAt != null) 'registeredAt': registeredAt,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (barcode != null) 'barcode': barcode,
  };
}
