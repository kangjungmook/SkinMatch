import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 프로토타입의 인라인 SVG 아이콘을 그대로 옮겼어요 (viewBox 0 0 24 24, stroke = currentColor).
abstract final class Ic {
  static const chevronLeft = '<path d="m15 18-6-6 6-6"/>';
  static const chevronRight = '<path d="m9 18 6-6-6-6"/>';
  static const chevronUp = '<path d="m18 15-6-6-6 6"/>';
  static const chevronDown = '<path d="m6 9 6 6 6-6"/>';
  static const alertCircle = '<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>';
  static const info = '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>';
  static const shieldCheck = '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>';
  static const check = '<path d="M20 6 9 17l-5-5"/>';
  static const lock = '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>';
  static const clipboard =
      '<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>';
  static const bottle = '<path d="M10 2h4v4l2 2v12a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V8l2-2z"/><path d="M8 13h8"/>';
  static const bottleNav = '<path d="M10 2h4v4l2 2v12a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V8l2-2z"/>';
  static const close = '<path d="M18 6 6 18M6 6l12 12"/>';
  static const search = '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>';
  static const barcode =
      '<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 8v8M10.5 8v8M14 8v8M17 8v8"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const share = '<path d="M4 12v7a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7M16 6l-4-4-4 4M12 2v13"/>';
  static const warning =
      '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>';
  static const sun =
      '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>';
  static const moon = '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z"/>';
  static const bulb =
      '<path d="M9 18h6M10 22h4"/><path d="M15.1 14c.2-1 .7-1.7 1.4-2.5A4.6 4.6 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/>';
  static const bookmark = '<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>';
  static const refresh = '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>';
  static const zap = '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>';
  static const user = '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>';
  static const camera =
      '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>';
  static const image =
      '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>';
  static const logout = '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>';
}

class SmIcon extends StatelessWidget {
  const SmIcon(
    this.body, {
    super.key,
    this.size = 16,
    this.color = const Color(0xFF0F172A),
    this.strokeWidth = 2,
    this.fill,
    this.stroke = true,
  });

  final String body;
  final double size;
  final Color color;
  final double strokeWidth;

  /// null = 채우지 않음, 그 외 = 채움 색
  final Color? fill;

  /// false면 선 없이 채우기만 해요 (번개 CTA 아이콘)
  final bool stroke;

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final fillAttr = fill == null ? 'none' : _hex(fill!);
    final fillOpacity = fill == null ? '' : ' fill-opacity="${(fill!.a).toStringAsFixed(3)}"';
    final strokeAttr = stroke ? 'stroke="currentColor" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round"' : '';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fillAttr"$fillOpacity $strokeAttr>$body</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// S 스플릿 "방울이" 로고. [eye]는 눈 크기, [smile]은 입 표시 여부.
class SkinMatchLogo extends StatelessWidget {
  const SkinMatchLogo({super.key, this.size = 44, this.eye = 5, this.smile = true, this.radius = 28});

  final double size;
  final double eye;
  final bool smile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final mouth = smile ? '<path d="M53 87q7 6 14 0" stroke="#0F172A" stroke-width="4.5" fill="none" stroke-linecap="round"/>' : '';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120"><defs><clipPath id="s"><path d="M0 0H60C38 45 82 75 60 120H0Z"/></clipPath></defs>'
      '<rect width="120" height="120" rx="$radius" fill="#10B981"/>'
      '<path d="M60 16C60 16 28 52 28 75a32 32 0 0 0 64 0C92 52 60 16 60 16Z" fill="#A7F3D0"/>'
      '<path d="M60 16C60 16 28 52 28 75a32 32 0 0 0 64 0C92 52 60 16 60 16Z" fill="#fff" clip-path="url(#s)"/>'
      '<circle cx="49" cy="76" r="$eye" fill="#0F172A"/><circle cx="71" cy="76" r="$eye" fill="#0F172A"/>$mouth</svg>',
      width: size,
      height: size,
    );
  }
}

/// 카카오 / Apple / Google 로고 (원본 색)
abstract final class BrandSvg {
  static const kakao =
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#3C1E1E" d="M12 3C6.5 3 2 6.6 2 11c0 2.8 1.9 5.3 4.7 6.7l-1 3.6c-.1.3.3.6.6.4l4.2-2.8c.5.1 1 .1 1.5.1 5.5 0 10-3.6 10-8S17.5 3 12 3z"/></svg>';
  static const apple =
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#fff"><path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.47.83-.72 0-1.82-.81-2.99-.79-1.54.02-2.96.9-3.75 2.27-1.6 2.78-.41 6.9 1.15 9.15.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.77-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.39-.92-2.41-3.67zM14.1 5.86c.63-.77 1.06-1.83.94-2.89-.91.04-2.01.61-2.66 1.37-.58.67-1.09 1.76-.96 2.79 1.02.08 2.05-.51 2.68-1.27z"/></svg>';
  static const google =
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23z"/><path fill="#FBBC05" d="M5.84 14.1A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.44.34-2.1V7.07H2.18A11 11 0 0 0 1 12c0 1.78.43 3.45 1.18 4.93l3.66-2.83z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1A11 11 0 0 0 2.18 7.07l3.66 2.84C6.71 7.31 9.14 5.38 12 5.38z"/></svg>';
}

/// 네 갈래 반짝임 (✦)
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, this.size = 18, this.color = const Color(0xFF10B981)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M12 1.5C12.9 8.6 15.4 11.1 22.5 12C15.4 12.9 12.9 15.4 12 22.5C11.1 15.4 8.6 12.9 1.5 12C8.6 11.1 11.1 8.6 12 1.5Z"/></svg>',
    width: size,
    height: size,
    theme: SvgTheme(currentColor: color),
  );
}
