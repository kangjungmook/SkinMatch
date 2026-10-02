import 'product.dart';

/// 루틴의 한 단계. 제품을 골랐거나(product), 성분을 직접 입력했어요(manual + text).
class RoutineStep {
  const RoutineStep({required this.id, required this.category, this.text = '', this.product, this.manual = false, this.quick = false});

  final String id;
  final String category;
  final String text;
  final Product? product;
  final bool manual;

  /// 전성분 대신 주요 성분만 골라 넣은 단계 (간단 분석)
  final bool quick;

  bool get isFilled => text.trim().isNotEmpty;

  RoutineStep copyWith({String? category, String? text, Product? product, bool clearProduct = false, bool? manual, bool? quick}) =>
      RoutineStep(
        id: id,
        category: category ?? this.category,
        text: text ?? this.text,
        product: clearProduct ? null : (product ?? this.product),
        manual: manual ?? this.manual,
        quick: quick ?? this.quick,
      );

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
    id: j['id'] as String,
    category: j['category'] as String,
    text: j['text'] as String? ?? '',
    product: j['product'] == null ? null : Product.fromJson(Map<String, dynamic>.from(j['product'] as Map)),
    manual: j['manual'] as bool? ?? false,
    quick: j['quick'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'text': text,
    if (product != null) 'product': product!.toJson(),
    'manual': manual,
    if (quick) 'quick': true,
  };
}
