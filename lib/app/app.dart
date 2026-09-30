import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../providers/core_providers.dart';
import 'router.dart';

class SkinMatchApp extends ConsumerWidget {
  const SkinMatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SkinMatch',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: PhoneFrame(child: ToastHost(child: child!)),
        ),
      ),
    );
  }
}

/// 넓은 화면(웹·태블릿)에서는 가운데 440px 폰 프레임, 휴대폰에서는 전체 화면.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const maxWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final framed = mq.size.width >= 480;
    if (!framed) return ColoredBox(color: SM.bg, child: child);
    final h = math.min(mq.size.height, 948.0) - 48;
    return ColoredBox(
      color: SM.frameBg,
      child: Center(
        child: Container(
          width: maxWidth,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: SM.bg,
            borderRadius: BorderRadius.circular(44),
            boxShadow: const [
              BoxShadow(color: Color(0x0F0F172A), spreadRadius: 1),
              BoxShadow(color: Color(0x590F172A), offset: Offset(0, 40), blurRadius: 80, spreadRadius: -30),
            ],
          ),
          // 프레임 안에서는 위쪽 46px을 상태 표시줄 자리로 비워 둬요.
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(maxWidth, h),
              padding: const EdgeInsets.only(top: 46),
              viewPadding: const EdgeInsets.only(top: 46),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 위쪽 토스트 (top: 상태 표시줄 + 8px)
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = ref.watch(toastProvider);
    final top = MediaQuery.paddingOf(context).top + 8;
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (msg.isNotEmpty)
          Positioned(
            top: top,
            left: 20,
            right: 20,
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(msg),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: SM.ease,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(0, -10 * (1 - t)), child: child),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xEB0F172A),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [BoxShadow(color: Color(0x800F172A), offset: Offset(0, 12), blurRadius: 30, spreadRadius: -10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SmIcon(Ic.check, size: 15, color: SM.primaryGlow, strokeWidth: 2.6),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                msg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: st(13.5, w: w500, c: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
