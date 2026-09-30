import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 누르면 살짝 작아지는 탭 영역 (CSS :active transform:scale(.98)).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .98, this.semanticLabel, this.hoverColor});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  /// 마우스를 올렸을 때 덮을 색 (웹)
  final Color? hoverColor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.hoverColor != null && _hover) {
      child = ColorFiltered(colorFilter: ColorFilter.mode(widget.hoverColor!, BlendMode.srcATop), child: child);
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        label: widget.semanticLabel,
        child: MouseRegion(
          cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            onTap: widget.onTap,
            child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 150), child: child),
          ),
        ),
      ),
    );
  }
}

/// smFade: opacity 0→1, translateY 12px→0
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.ms = 450, this.dy = 12});

  final Widget child;
  final int ms;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: SM.ease,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, dy * (1 - t)), child: child),
      ),
    );
  }
}

/// 흰 카드: 테두리 #F1F5F9, 그림자 0 14 36 -24
class SmCard extends StatelessWidget {
  const SmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
    this.radius = 26,
    this.shadow = true,
    this.color = SM.surface,
    this.border = SM.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
        boxShadow: shadow ? SM.cardShadow : null,
      ),
      child: child,
    );
  }
}

/// 제품 이미지 자리: repeating-linear-gradient(135deg, tint 0 p, #FFFFFF80 p 2p)
class StripeBox extends StatelessWidget {
  const StripeBox({
    super.key,
    required this.tint,
    this.stripe = 6,
    this.radius = 13,
    this.width,
    this.height,
    this.child,
    this.base = SM.surface,
  });

  final Color tint;
  final double stripe;
  final double radius;
  final double? width;
  final double? height;
  final Widget? child;

  /// 반투명 흰 줄 아래에 비치는 바탕색
  final Color base;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _StripePainter(tint, stripe, base),
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.tint, this.stripe, this.base);
  final Color tint;
  final double stripe;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Color.alphaBlend(const Color(0x80FFFFFF), base);
    final d = stripe * 2 / math.sqrt2;
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(d, d), [tint, tint, white, white], [0, .5, .5, 1], TileMode.repeated);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.tint != tint || old.stripe != stripe || old.base != base;
}

/// 로딩 스켈레톤 (smShimmer 1.1s)
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // background-size 200%, position 200% → -200%
        final shift = 2 - 4 * _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - shift, 0),
              end: Alignment(3 - shift, 0),
              colors: const [SM.muted, SM.muted, SM.bg, SM.muted, SM.muted],
              stops: const [0, .25, .5, .75, 1],
              tileMode: TileMode.repeated,
            ),
          ),
        );
      },
    );
  }
}

/// 켜고 끄는 스위치 (52×32, 스프링 이동)
class SmToggle extends StatelessWidget {
  const SmToggle({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: value ? SM.primary : SM.line, borderRadius: BorderRadius.circular(999)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: SM.spring,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x330F172A), offset: Offset(0, 2), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 알약 모양 라벨
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    required this.bg,
    required this.fg,
    this.height = 22,
    this.hPad = 8,
    this.size = 11,
    this.weight = w600,
  });

  final String text;
  final Color bg;
  final Color fg;
  final double height;
  final double hPad;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      // Wrap·Align 안에서도 글자 폭만큼만 차지하도록 widthFactor: 1
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: st(size, w: weight, c: fg),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// 가로 스크롤 줄 (margin 0 -20px, padding 0 20px)
class HScroll extends StatelessWidget {
  const HScroll({super.key, required this.children, this.gap = 10, this.bottomPad = 0});

  final List<Widget> children;
  final double gap;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
        ],
      ),
    );
  }
}

/// 키-값 한 줄 (피부 프로필 요약)
class KvRow extends StatelessWidget {
  const KvRow(
    this.k,
    this.v, {
    super.key,
    required this.keyColor,
    required this.valueColor,
    required this.divider,
    this.vPad = 10,
    this.topBorder = false,
  });

  final String k;
  final String v;
  final Color keyColor;
  final Color valueColor;
  final Color divider;
  final double vPad;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: divider);
    return Container(
      padding: EdgeInsets.symmetric(vertical: vPad),
      decoration: BoxDecoration(
        border: topBorder ? Border(top: side) : Border(bottom: side),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: st(13.5, c: keyColor)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: st(13.5, w: w600, c: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 좌우 20px 여백을 무시하고 화면 끝까지 펼쳐요 (CSS margin: 0 -20px).
class Bleed extends StatelessWidget {
  const Bleed({super.key, required this.height, required this.child, this.amount = 20});

  final double height;
  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, c) => OverflowBox(minWidth: c.maxWidth + amount * 2, maxWidth: c.maxWidth + amount * 2, child: child),
    ),
  );
}

/// CSS grid처럼 같은 줄의 칸 높이를 맞추는 격자
class EqualGrid extends StatelessWidget {
  const EqualGrid({super.key, required this.cols, required this.gap, required this.children});
  final int cols;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
