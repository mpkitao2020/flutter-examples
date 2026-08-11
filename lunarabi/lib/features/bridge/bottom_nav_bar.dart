import 'package:flutter/material.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';

class LunarabiBottomNavBar extends StatelessWidget {
  const LunarabiBottomNavBar({
    super.key,
    required this.controller,
    required this.onSelect,
  });

  final BottomNavController controller;
  final ValueChanged<NavTabId> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.visible) {
          return const SizedBox.shrink();
        }

        return NavigationBar(
          selectedIndex: controller.active.index,
          onDestinationSelected: (index) {
            final id = NavTabId.values[index];
            controller.setActive(id);
            onSelect(id);
          },
          destinations: [
            for (final id in NavTabId.values)
              NavigationDestination(
                icon: _BadgeIcon(
                  icon: _iconFor(id),
                  count: controller.badgeOf(id),
                ),
                selectedIcon: _BadgeIcon(
                  icon: _selectedIconFor(id),
                  count: controller.badgeOf(id),
                ),
                label: _labelFor(id),
              ),
          ],
        );
      },
    );
  }

  static IconData _iconFor(NavTabId id) {
    return switch (id) {
      NavTabId.home => Icons.home_outlined,
      NavTabId.search => Icons.search,
      NavTabId.notify => Icons.notifications_outlined,
      NavTabId.account => Icons.person_outline,
    };
  }

  static IconData _selectedIconFor(NavTabId id) {
    return switch (id) {
      NavTabId.home => Icons.home,
      NavTabId.search => Icons.search,
      NavTabId.notify => Icons.notifications,
      NavTabId.account => Icons.person,
    };
  }

  static String _labelFor(NavTabId id) {
    return switch (id) {
      NavTabId.home => 'ホーム',
      NavTabId.search => '検索',
      NavTabId.notify => '通知',
      NavTabId.account => 'アカウント',
    };
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }
    final label = count > 99 ? '99+' : '$count';
    return Badge(
      label: Text(label),
      child: Icon(icon),
    );
  }
}
