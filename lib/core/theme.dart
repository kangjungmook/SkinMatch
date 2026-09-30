import 'package:flutter/material.dart';

import '../models/routine_result.dart';

/// 디자인 토큰. 값은 프로토타입(SkinMatch.dc.html)과 똑같아요.
abstract final class SM {
  // 배경 · 면
  static const frameBg = Color(0xFFE9EDF1);
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFF1F5F9);
  static const line = Color(0xFFE2E8F0);
  static const muted = Color(0xFFEEF2F6);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate300 = Color(0xFFCBD5E1);

  // 텍스트
  static const ink = Color(0xFF0F172A);
  static const inkSub = Color(0xFF64748B);
  static const ink600 = Color(0xFF475569);
  static const ink700 = Color(0xFF334155);
  static const inkFaint = Color(0xFF94A3B8);
  static const ink200 = Color(0xFFE2E8F0);

  // 브랜드
  static const primary = Color(0xFF10B981);
  static const primaryTx = Color(0xFF047857);
  static const primaryDeep = Color(0xFF065F46);
  static const primaryInk = Color(0xFF064E3B);
  static const primaryBg = Color(0xFFECFDF5);
  static const primaryLine = Color(0xFFD1FAE5);
  static const primarySoft = Color(0xFFA7F3D0);
  static const primaryGlow = Color(0xFF34D399);
  static const primaryMint = Color(0xFF6EE7B7);

  // 주의
  static const warn = Color(0xFFF59E0B);
  static const warnDeep = Color(0xFFD97706);
  static const warnTx = Color(0xFFB45309);
  static const warnBg = Color(0xFFFFFBEB);
  static const warnLine = Color(0xFFFDE68A);
  static const warnInk = Color(0xFF92400E);
  static const warnInk2 = Color(0xFF78350F);
  static const orangeBg = Color(0xFFFFF7ED);
  static const amber100 = Color(0xFFFEF3C7);

  // 위험
  static const danger = Color(0xFFEF4444);
  static const dangerStrong = Color(0xFFDC2626);
  static const dangerTx = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEF2F2);
  static const dangerLine = Color(0xFFFECACA);
  static const dangerInk = Color(0xFF7F1D1D);
  static const red100 = Color(0xFFFEE2E2);

  // 소셜
  static const kakao = Color(0xFFFEE500);
  static const kakaoTx = Color(0xFF3C1E1E);

  static const ease = Cubic(.22, 1, .36, 1);
  static const spring = Cubic(.34, 1.56, .64, 1);

  /// 카드 그림자: 0 14px 36px -24px rgba(15,23,42,.2)
  static const cardShadow = [BoxShadow(color: Color(0x330F172A), offset: Offset(0, 14), blurRadius: 36, spreadRadius: -24)];

  /// 카테고리별 제품 이미지 자리 색
  static Color tint(String category) => switch (category) {
    '토너' => const Color(0xFFDDF5EA),
    '세럼' => const Color(0xFFFDEBD6),
    '크림' => const Color(0xFFE0EEF8),
    '선크림' => const Color(0xFFFBF3C9),
    _ => const Color(0xFFE7ECF2),
  };

  /// 화장대 그리드/시트에서 쓰는 기본 틴트 (#EEF2F6)
  static Color vanityTint(String category) => const {'토너', '세럼', '크림', '선크림'}.contains(category) ? tint(category) : muted;
}

/// 위험 구간별 색 (게이지, 알약, 최근 분석 배지)
class BandStyle {
  const BandStyle(this.color, this.text, this.bg, this.label);
  final Color color;
  final Color text;
  final Color bg;
  final String label;

  static const low = BandStyle(SM.primary, SM.primaryTx, SM.primaryBg, '안심 조합 (보습 & 피부 장벽 시너지)');
  static const mid = BandStyle(SM.warn, SM.warnTx, SM.warnBg, '시간차 사용 권장 (민감성 피부 주의)');
  static const high = BandStyle(SM.danger, SM.dangerTx, SM.dangerBg, '동시 사용 비추천 (자극 및 각질 손상 위험)');

  static BandStyle of(RiskBand b) => switch (b) {
    RiskBand.low => low,
    RiskBand.mid => mid,
    RiskBand.high => high,
  };

  /// 충돌 맵 셀 · 조합 알약 색 [배경, 글자]
  static (Color, Color) cell(RiskBand b) => switch (b) {
    RiskBand.low => (SM.primaryLine, SM.primaryTx),
    RiskBand.mid => (SM.amber100, SM.warnTx),
    RiskBand.high => (SM.red100, SM.dangerTx),
  };
}

/// 텍스트 스타일. [ls]는 CSS처럼 em 단위 자간이에요 (기본 -0.01em).
TextStyle st(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = SM.ink,
  double ls = -0.01,
  double? h,
  bool tabular = false,
  TextDecoration? deco,
}) => TextStyle(
  fontFamily: 'Pretendard',
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls * size,
  height: h,
  decoration: deco,
  decorationColor: c,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

const w500 = FontWeight.w500;
const w600 = FontWeight.w600;
const w700 = FontWeight.w700;

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Pretendard',
  scaffoldBackgroundColor: SM.bg,
  colorScheme: ColorScheme.fromSeed(seedColor: SM.primary, surface: SM.bg),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
  textSelectionTheme: const TextSelectionThemeData(cursorColor: SM.primary, selectionColor: Color(0x3310B981)),
);
