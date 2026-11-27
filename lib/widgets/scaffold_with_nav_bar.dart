import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import '../theme/app_palette.dart';

/// Shell 5 tab dengan bottom navigation persisten (StatefulShellRoute).
class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.storefront_outlined, Icons.storefront, 'Beranda'),
    (Icons.add_box_outlined, Icons.add_box, 'Posting'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Pesan'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Aktivitas'),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  void _onTap(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _tabs[i].$1,
                    activeIcon: _tabs[i].$2,
                    label: _tabs[i].$3,
                    active: shell.currentIndex == i,
                    // Badge unread hanya untuk tab Pesan (index 2).
                    badge: i == 2 && unread > 0 ? unread : 0,
                    onTap: () => _onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = active ? p.primary : p.textMuted;
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? 'Tab $label, $badge pesan baru' : 'Tab $label',
      excludeSemantics: true,
      onTap: onTap,
      child: _content(color, p),
    );
  }

  Widget _content(Color color, AppPalette p) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 34,
                    decoration: BoxDecoration(
                      color: active ? p.surfaceAlt : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(active ? activeIcon : icon,
                        size: 22, color: color),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: p.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: p.onAccent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
