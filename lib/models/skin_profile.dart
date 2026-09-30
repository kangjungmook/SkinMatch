/// 피부 진단 3단계 결과.
class SkinProfile {
  const SkinProfile({this.baseType, this.concerns = const [], this.sensitivity = 0, this.history = const [], this.pregnancyAlert = false});

  /// 건성 | 지성 | 복합성 | 중성
  final String? baseType;

  /// 민감성/홍조, 여드름·트러블, 장벽손상, 색소침착·잡티, 모공·피지, 주름·탄력
  final List<String> concerns;

  /// 1~5, 0 = 미설정
  final int sensitivity;

  /// acid, noRetinol, procedure, rx
  final List<String> history;
  final bool pregnancyAlert;

  bool get isSensitive => concerns.contains('민감성/홍조') || concerns.contains('장벽손상') || sensitivity >= 4;

  SkinProfile copyWith({
    String? baseType,
    bool clearBaseType = false,
    List<String>? concerns,
    int? sensitivity,
    List<String>? history,
    bool? pregnancyAlert,
  }) => SkinProfile(
    baseType: clearBaseType ? null : (baseType ?? this.baseType),
    concerns: concerns ?? this.concerns,
    sensitivity: sensitivity ?? this.sensitivity,
    history: history ?? this.history,
    pregnancyAlert: pregnancyAlert ?? this.pregnancyAlert,
  );

  factory SkinProfile.fromJson(Map<String, dynamic> j) => SkinProfile(
    baseType: j['baseType'] as String?,
    concerns: List<String>.from(j['concerns'] as List? ?? const []),
    sensitivity: j['sensitivity'] as int? ?? 0,
    history: List<String>.from(j['history'] as List? ?? const []),
    pregnancyAlert: j['pregnancyAlert'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'baseType': baseType,
    'concerns': concerns,
    'sensitivity': sensitivity,
    'history': history,
    'pregnancyAlert': pregnancyAlert,
  };
}
