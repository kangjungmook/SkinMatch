import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/vanity_provider.dart';
import '../../widgets/common.dart';
import '../auth/skin_options.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final v = ref.watch(vanityProvider);
    final user = session.user;
    final name = user?.name ?? '';
    final pad = MediaQuery.paddingOf(context);
    final method = switch (user?.method) {
      LoginMethod.kakao => '카카오 계정으로 로그인됨',
      LoginMethod.apple => 'Apple ID로 로그인됨',
      LoginMethod.google => 'Google 계정으로 로그인됨',
      _ => user?.email ?? '이메일 계정',
    };
    void soon() => ref.read(toastProvider.notifier).show('준비 중인 기능이에요');

    BoxDecoration card([double r = 26]) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: SM.border),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8 + pad.top, 20, 150 + pad.bottom),
      child: FadeIn(
        ms: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('마이페이지', style: st(26, w: w700, ls: -0.035)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: card(),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: SM.primaryBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      name.isEmpty ? '' : name.characters.first,
                      style: st(22, w: w700, c: SM.primaryTx),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name님', style: st(18, w: w700)),
                        const SizedBox(height: 3),
                        Text(method, style: st(13, c: SM.inkSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: '화장대 제품', value: v.products.length, onTap: () => context.go(Routes.vanity)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(label: '저장한 조합', value: v.combos.length, onTap: () => context.go(Routes.vanity)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('내 피부 프로필', style: st(15, w: w600)),
                      ),
                      const SizedBox(width: 8),
                      Pressable(
                        onTap: () => ref.read(sessionProvider.notifier).redoOnboarding(),
                        child: Pill('다시 진단하기', bg: SM.primaryBg, fg: SM.primaryTx, height: 32, hPad: 12, size: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('분석 시 자극도 보정에 사용돼요', style: st(12.5, c: SM.inkSub)),
                  const SizedBox(height: 6),
                  for (final r in profileRows(session.profile))
                    KvRow(r.$1, r.$2, keyColor: SM.inkSub, valueColor: SM.ink, divider: SM.border, vPad: 11, topBorder: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: card(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('임산부/수유부 주의 성분 알림', style: st(15, w: w600)),
                        const SizedBox(height: 3),
                        Text('레티노이드 등 감지 시 경고 표시', style: st(12.5, c: SM.inkSub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SmToggle(
                    value: session.profile.pregnancyAlert,
                    label: '임산부 알림',
                    onChanged: (on) => ref.read(sessionProvider.notifier).setProfile(session.profile.copyWith(pregnancyAlert: on)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: card(),
              child: Column(
                children: [
                  _MenuRow(label: '알림 설정', onTap: soon),
                  _MenuRow(label: '고객센터', onTap: soon),
                  _MenuRow(label: '로그아웃', danger: true, last: true, onTap: () => ref.read(sessionProvider.notifier).logout()),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'SkinMatch v1.0.0',
              textAlign: TextAlign.center,
              style: st(11.5, c: SM.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});
  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 1,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SM.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: st(12.5, c: SM.inkSub)),
          const SizedBox(height: 4),
          Text('$value', style: st(24, w: w700)),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.danger = false, this.last = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 1,
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: last ? null : const Border(bottom: BorderSide(color: SM.border)),
      ),
      child: danger
          ? Row(
              children: [
                const SmIcon(Ic.logout, size: 17, color: SM.dangerStrong, strokeWidth: 1.9),
                const SizedBox(width: 10),
                Text(label, style: st(15, c: SM.dangerStrong)),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(label, style: st(15))),
                const SmIcon(Ic.chevronRight, size: 16, color: SM.inkFaint),
              ],
            ),
    ),
  );
}
