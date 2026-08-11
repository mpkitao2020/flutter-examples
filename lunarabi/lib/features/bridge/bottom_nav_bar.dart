import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';

const bottomNavIconAssetPaths = <NavTabId, String>{
  NavTabId.home: 'branding/nav/home.svg',
  NavTabId.search: 'branding/nav/search.svg',
  NavTabId.notify: 'branding/nav/notify.svg',
  NavTabId.account: 'branding/nav/account.svg',
};

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
                  assetPath: bottomNavIconAssetPaths[id]!,
                  count: controller.badgeOf(id),
                ),
                selectedIcon: _BadgeIcon(
                  assetPath: bottomNavIconAssetPaths[id]!,
                  count: controller.badgeOf(id),
                ),
                label: _labelFor(id),
              ),
          ],
        );
      },
    );
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
  const _BadgeIcon({required this.assetPath, required this.count});

  final String assetPath;
  final int count;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final color = iconTheme.color;
    final icon = SvgPicture.asset(
      assetPath,
      width: iconTheme.size ?? 24,
      height: iconTheme.size ?? 24,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (count <= 0) {
      return icon;
    }
    final label = count > 99 ? '99+' : '$count';
    return Badge(label: Text(label), child: icon);
  }
}
