# nav-icons-ios-caps report

Branch: `cursor/lunarabi-nav-icons-ios-caps-c3bc`

## Commits

1. `fdc7453` `feat(lunarabi): add placeholder bottom nav SVGs`
2. `a028b5d` `feat(lunarabi): render bottom nav with SVG assets`
3. `b186eb1` `fix(ios): attach entitlements and enable push background mode`
4. `docs(lunarabi): add production hardening checklist`

## Changes

- Added `branding/nav/home.svg`, `search.svg`, `notify.svg`, and `account.svg`.
- Added `flutter_svg`, registered the nav SVG assets in `pubspec.yaml`, and covered registration in `branding_assets_test.dart`.
- Reworked `LunarabiBottomNavBar` to render `SvgPicture.asset` from `bottomNavIconAssetPaths`.
- Covered `NavTabId` to path mapping, pubspec registration, and rendered SVG asset names in `bottom_nav_bar_test.dart`.
- Added iOS Runner entitlements wiring for Debug/Profile/Release through a pbxproj parser test.
- Kept associated domains, set Debug/Profile `aps-environment=development`, and added `Runner.Release.entitlements` with `aps-environment=production`.
- Enabled `UIBackgroundModes` / `remote-notification` in `ios/Runner/Info.plist`.
- Added README hardening checklist sections for Flutter code deliverables and external release gates with evidence, owner, date, and sign-off fields.

## Verification

- Red tests observed before implementation:
  - `fvm flutter test test/branding/branding_assets_test.dart`
  - `fvm flutter test test/features/bridge/bottom_nav_bar_test.dart`
  - `fvm flutter test test/ios/runner_push_configuration_test.dart`
- Focused green tests:
  - `fvm flutter test test/branding/branding_assets_test.dart`
  - `fvm flutter test test/features/bridge/bottom_nav_bar_test.dart`
  - `fvm flutter test test/ios/runner_push_configuration_test.dart`
- Full suite: `fvm flutter test` passed with 145 tests.

## Release honesty

- No push was performed.
- Production push delivery is not claimed. Real APNs key, Firebase project, provisioning profile, and device delivery evidence remain external release gates.
