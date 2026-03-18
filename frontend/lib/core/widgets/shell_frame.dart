import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;
}

class ShellFrame extends StatelessWidget {
  const ShellFrame({super.key, required this.child});

  final Widget child;

  static const items = <_NavItem>[
    _NavItem(label: '통합관제', icon: Icons.space_dashboard_rounded, path: '/'),
    _NavItem(label: '오더', icon: Icons.inventory_2_rounded, path: '/orders'),
    _NavItem(
      label: '출하',
      icon: Icons.local_shipping_rounded,
      path: '/shipments',
    ),
    _NavItem(label: '배차', icon: Icons.alt_route_rounded, path: '/dispatch'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        return Scaffold(
          bottomNavigationBar: desktop ? null : _MobileNav(location: location),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF1F5F8), Color(0xFFE7EEF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x221AB7B4), Color(0x001AB7B4)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -60,
                  bottom: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x25FFC857), Color(0x00FFC857)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 140,
                  left: 120,
                  right: 120,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      if (desktop)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: _DesktopRail(location: location),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 0 : 18,
                            18,
                            desktop ? 18 : 18,
                            desktop ? 18 : 96,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!desktop)
                  const Positioned(
                    top: 18,
                    right: 18,
                    child: _CompactSessionTools(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2032),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(
            markSize: 60,
            onDark: true,
            subtitle: '오더부터 배송까지 한 흐름으로',
          ),
          const SizedBox(height: 28),
          for (final item in ShellFrame.items)
            _NavButton(item: item, active: location == item.path),
          const Spacer(),
          const _SessionCard(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '운영 스택',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                ),
                const SizedBox(height: 12),
                const _StackTag('Flutter 웹'),
                const SizedBox(height: 8),
                const _StackTag('FastAPI'),
                const SizedBox(height: 8),
                const _StackTag('PostgreSQL + Redis'),
                const SizedBox(height: 16),
                Text(
                  '수진 TMS 전용 운영 화면',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.74),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionController.instance,
      builder: (context, child) {
        final session = SessionController.instance.session;
        if (session == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '접속 계정',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                session.user.fullName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                session.user.roleLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.72),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                session.user.email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '작업 위치',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 10),
              const _ActorLocationSelector(),
              const SizedBox(height: 14),
              const _SessionAction(),
            ],
          ),
        );
      },
    );
  }
}

class _CompactSessionTools extends StatelessWidget {
  const _CompactSessionTools();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const [
        _ActorLocationSelector(compact: true),
        SizedBox(height: 10),
        _SessionAction(compact: true),
      ],
    );
  }
}

class _ActorLocationSelector extends StatelessWidget {
  const _ActorLocationSelector({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionController.instance,
      builder: (context, child) {
        final controller = SessionController.instance;
        final locations = controller.actorLocations;
        final selected = controller.selectedActorLocation;
        final loading = controller.isLoadingActorLocations;

        if (!loading && locations.isEmpty && !compact) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '작업 위치를 불러오지 못했습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: controller.refreshActorLocations,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('다시 불러오기'),
                ),
              ],
            ),
          );
        }

        final shortLabel = loading
            ? '위치 조회중'
            : selected?.code?.trim().isNotEmpty == true
                ? selected!.code!.trim()
                : selected?.name ?? '위치';
        final longLabel = loading
            ? '작업 위치를 불러오는 중입니다.'
            : selected?.label ??
                (locations.isEmpty ? '선택 가능한 작업 위치가 없습니다.' : '작업 위치를 선택하세요.');

        return PopupMenuButton<String>(
          enabled: locations.isNotEmpty,
          tooltip: '작업 위치 선택',
          onSelected: (value) {
            SessionController.instance.selectActorLocation(value);
          },
          itemBuilder: (context) {
            return [
              for (final option in locations)
                PopupMenuItem<String>(
                  value: option.id,
                  child: Row(
                    children: [
                      Icon(
                        option.id == selected?.id
                            ? Icons.check_circle_rounded
                            : Icons.place_outlined,
                        size: 18,
                        color: option.id == selected?.id
                            ? AppTheme.pine
                            : AppTheme.shell,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ];
          },
          child: Container(
            constraints: compact ? const BoxConstraints(minWidth: 118) : null,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 11 : 13,
            ),
            decoration: BoxDecoration(
              color: compact
                  ? const Color(0xFF0F2032)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(compact ? 18 : 18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.72),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.place_rounded,
                    size: compact ? 18 : 20,
                    color: Colors.white70,
                  ),
                const SizedBox(width: 10),
                if (compact)
                  Text(
                    shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  )
                else
                  Expanded(
                    child: Text(
                      longLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_more_rounded,
                  color: locations.isEmpty ? Colors.white38 : Colors.white60,
                  size: compact ? 18 : 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SessionAction extends StatefulWidget {
  const _SessionAction({this.compact = false});

  final bool compact;

  @override
  State<_SessionAction> createState() => _SessionActionState();
}

class _SessionActionState extends State<_SessionAction> {
  bool _busy = false;

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
    });
    await SessionController.instance.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return FilledButton.icon(
        onPressed: _busy ? null : _signOut,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F2032),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(_busy ? '정리 중' : '로그아웃'),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.18)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(_busy ? '로그아웃 중...' : '로그아웃'),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active});

  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go(item.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF1A4F77), Color(0xFF108D8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active ? null : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.14)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackTag extends StatelessWidget {
  const _StackTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 74,
      backgroundColor: AppTheme.shell,
      selectedIndex: ShellFrame.items
          .indexWhere((item) => item.path == location)
          .clamp(0, 3) as int,
      destinations: [
        for (final item in ShellFrame.items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
      onDestinationSelected: (index) =>
          context.go(ShellFrame.items[index].path),
    );
  }
}
