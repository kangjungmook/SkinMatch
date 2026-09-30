import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../core/icons.dart';
import '../core/theme.dart';

/// 화면 아래 떠 있는 알약 모양 탭 바 (유리 효과)
class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.location});

  final String location;

  static double bottomOf(BuildContext context) => 18 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOf(context),
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xC7FFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xE6E2E8F0)),
            ),
            child: Row(
              children: [
                _Tab(label: '분석', icon: Ic.zap, on: location == Routes.analyzer, onTap: () => context.go(Routes.analyzer)),
                const SizedBox(width: 4),
                _Tab(label: '내 화장대', icon: Ic.bottleNav, on: location == Routes.vanity, onTap: () => context.go(Routes.vanity)),
                const SizedBox(width: 4),
                _Tab(label: '마이페이지', icon: Ic.user, on: location == Routes.profile, onTap: () => context.go(Routes.profile)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.on, required this.onTap});

  final String label;
  final String icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.white : SM.inkSub;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: SM.ease,
              decoration: BoxDecoration(color: on ? SM.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SmIcon(icon, size: 21, color: color, strokeWidth: 1.8, fill: on ? color : null),
                  const SizedBox(height: 3),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: st(11.5, w: w600, c: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
