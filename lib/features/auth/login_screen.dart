import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false;
  String _err = '';

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^\S+@\S+\.\S+$');

  Future<void> _submit() async {
    final email = _email.text.trim(), pw = _pw.text;
    if (!_emailRe.hasMatch(email)) return setState(() => _err = '올바른 이메일 주소를 입력해 주세요');
    if (pw.length < 8) return setState(() => _err = '비밀번호는 8자 이상이어야 해요');
    setState(() => _err = '');
    final msg = await ref.read(sessionProvider.notifier).email(email, pw, signup: _signup);
    if (msg != null && mounted) setState(() => _err = msg);
  }

  Future<void> _social(LoginMethod m) async {
    final msg = await ref.read(sessionProvider.notifier).social(m);
    if (msg != null) ref.read(toastProvider.notifier).show(msg);
  }

  Future<void> _findPw() async {
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) return setState(() => _err = '비밀번호를 재설정할 이메일 주소를 먼저 입력해 주세요');
    final msg = await ref.read(sessionProvider.notifier).resetPassword(email);
    if (!mounted) return;
    if (msg != null) return setState(() => _err = msg);
    setState(() => _err = '');
    ref.read(toastProvider.notifier).show('비밀번호 재설정 메일을 보냈어요');
  }

  void _mode(bool signup) => setState(() {
    _signup = signup;
    _err = '';
  });

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(sessionProvider.select((s) => s.busy));
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: SM.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, top + 20, 24, 32 + MediaQuery.paddingOf(context).bottom),
        child: FadeIn(
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0xB310B981), offset: Offset(0, 8), blurRadius: 20, spreadRadius: -8)],
                      ),
                      child: const SkinMatchLogo(size: 44, eye: 5),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SkinMatch', style: st(19, w: w700, ls: -0.03)),
                        const SizedBox(height: 1),
                        Text(
                          '스킨매치',
                          style: st(11.5, w: w500, c: SM.inkSub),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Text('3초 만에 시작하는\n안심 스킨케어', style: st(29, w: w700, ls: -0.035, h: 1.3)),
                const SizedBox(height: 10),
                Text('지금 바르는 제품과 새 제품의 성분 궁합,\nAI가 충돌 위험부터 루틴까지 알려드려요.', style: st(15, c: SM.inkSub, h: 1.55)),
                const SizedBox(height: 30),
                _SocialButton(
                  label: '카카오로 3초 만에 시작하기',
                  svg: BrandSvg.kakao,
                  iconSize: 20,
                  bg: SM.kakao,
                  fg: SM.kakaoTx,
                  onTap: () => _social(LoginMethod.kakao),
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Apple로 계속하기',
                  svg: BrandSvg.apple,
                  bg: SM.ink,
                  fg: Colors.white,
                  onTap: () => _social(LoginMethod.apple),
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Google로 계속하기',
                  svg: BrandSvg.google,
                  bg: Colors.white,
                  fg: SM.ink,
                  border: SM.line,
                  hover: SM.bg,
                  onTap: () => _social(LoginMethod.google),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider(height: 1, thickness: 1, color: SM.line)),
                    const SizedBox(width: 12),
                    Text('또는 이메일로 계속하기', style: st(13, c: SM.inkSub)),
                    const SizedBox(width: 12),
                    const Expanded(child: Divider(height: 1, thickness: 1, color: SM.line)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: SM.muted, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      _Seg(label: '로그인', on: !_signup, onTap: () => _mode(false)),
                      _Seg(label: '회원가입', on: _signup, onTap: () => _mode(true)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FloatingField(
                  label: '이메일',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email],
                  onChanged: (_) => _err.isEmpty ? null : setState(() => _err = ''),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 10),
                FloatingField(
                  label: _signup ? '비밀번호 (8자 이상)' : '비밀번호',
                  controller: _pw,
                  obscure: true,
                  autofill: [_signup ? AutofillHints.newPassword : AutofillHints.password],
                  onChanged: (_) => _err.isEmpty ? null : setState(() => _err = ''),
                  onSubmitted: (_) => _submit(),
                ),
                if (_err.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const SmIcon(Ic.alertCircle, size: 14, color: SM.dangerStrong),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_err, style: st(13, c: SM.dangerStrong)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Pressable(
                  onTap: busy ? null : _submit,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: busy ? .7 : 1,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: SM.ink, borderRadius: BorderRadius.circular(18)),
                      child: Text(
                        busy ? '확인 중…' : (_signup ? '가입하고 시작하기' : '로그인'),
                        style: st(16, w: w600, c: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TextLink(label: '비밀번호 찾기', color: SM.inkSub, onTap: _findPw),
                    const SizedBox(width: 14),
                    Container(width: 1, height: 12, color: SM.slate300),
                    const SizedBox(width: 14),
                    _TextLink(label: _signup ? '로그인' : '회원가입', color: SM.ink, weight: w600, onTap: () => _mode(!_signup)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '계속하면 이용약관 및 개인정보 처리방침에 동의하게 됩니다.',
                  textAlign: TextAlign.center,
                  style: st(11.5, c: SM.inkFaint, h: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.svg,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.border,
    this.hover,
    this.iconSize = 18,
  });

  final String label;
  final String svg;
  final Color bg;
  final Color fg;
  final Color? border;
  final Color? hover;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: _Hover(
        color: bg,
        hover: hover ?? bg,
        builder: (c) => Container(
          height: 56,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(18),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.string(svg, width: iconSize, height: iconSize),
              const SizedBox(width: 10),
              Text(
                label,
                style: st(16, w: w600, c: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 마우스를 올리면 배경색만 바꾸는 헬퍼
class _Hover extends StatefulWidget {
  const _Hover({required this.color, required this.hover, required this.builder});
  final Color color;
  final Color hover;
  final Widget Function(Color) builder;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _on = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _on = true),
    onExit: (_) => setState(() => _on = false),
    child: widget.builder(_on ? widget.hover : widget.color),
  );
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.white.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(12),
                boxShadow: on ? const [BoxShadow(color: Color(0x140F172A), offset: Offset(0, 2), blurRadius: 8)] : const [],
              ),
              child: Text(
                label,
                style: st(14, w: w600, c: on ? SM.ink : SM.inkSub),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.color, required this.onTap, this.weight = FontWeight.w400});
  final String label;
  final Color color;
  final FontWeight weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 1,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        style: st(13.5, w: weight, c: color),
      ),
    ),
  );
}

/// 플로팅 라벨 입력칸 (높이 60, 포커스 시 에메랄드 테두리 + 4px 링)
class FloatingField extends StatefulWidget {
  const FloatingField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<FloatingField> createState() => _FloatingFieldState();
}

class _FloatingFieldState extends State<FloatingField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foc = _focus.hasFocus;
    final up = foc || widget.controller.text.isNotEmpty;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: foc ? SM.primary : SM.line),
          boxShadow: foc ? const [BoxShadow(color: Color(0x1F10B981), spreadRadius: 4)] : const [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: SM.ease,
              left: 17,
              top: up ? 10 : 19,
              child: IgnorePointer(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: SM.ease,
                  style: st(up ? 11.5 : 15, w: w500, c: foc ? SM.primaryTx : SM.inkSub),
                  child: Text(widget.label),
                ),
              ),
            ),
            Positioned(
              left: 17,
              right: 17,
              top: 22,
              bottom: 0,
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  autofillHints: widget.autofill,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: st(15.5),
                  cursorHeight: 18,
                  decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
