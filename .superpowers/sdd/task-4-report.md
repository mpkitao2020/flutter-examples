## Task 4 report

Status: Implemented Android system-back WebView history handling and removed the shell purchase AppBar action.

Changes:
- Added `decideWebViewSystemBack` and tests for both history and no-history paths.
- Wrapped `WebViewShell` in `PopScope` and refresh route-pop state from WebView history.
- Removed `onPurchasePressed` from `WebViewShell` and `main.dart`; payment coordinator code remains.
- Updated README for trusted bridge bootstrap limits, Android back behavior, and no AppBar purchase action.

TDD:
- Red: `fvm flutter test test/features/webview/webview_shell_navigation_test.dart` failed on missing `decideWebViewSystemBack` / `WebViewSystemBackDecision`.
- Green: focused WebView shell test passed after implementation.

Verification:
- `fvm flutter analyze lib test` passed with no issues.
- `fvm flutter test` passed, 104 tests.

Concern:
- `PopScope` needs a synchronous `canPop`, so the shell keeps route-pop state in sync with `controller.canGoBack()` around page navigation and back handling.

## Important review finding follow-up

Status: Fixed stale `PopScope.canPop` no-history back handling on `cursor/lunarabi-webview-guard-c3bc`.

Changes:
- Added `handleWebViewSystemBack`, which executes the route-pop path when WebView history is empty.
- Updated `WebViewShell._handleSystemBack` to refresh stale `_routeCanPop`, wait for the `PopScope` rebuild, then call `Navigator.maybePop()`.
- If the shell is the root route and `maybePop()` bubbles, the handler calls `SystemNavigator.pop()` so Android back can exit instead of being swallowed.
- Added a regression test proving the no-history system-back path executes route pop and does not call WebView `goBack()`.

TDD:
- Red: `fvm flutter test test/features/webview/webview_shell_navigation_test.dart` failed because `handleWebViewSystemBack` did not exist for the new no-history route-pop test.
- Green: focused WebView shell navigation test passed after wiring the route-pop callback.

Verification:
- `fvm flutter test test/features/webview/webview_shell_navigation_test.dart` passed, 14 tests.
- `fvm flutter test` passed, 105 tests.

Commit:
- `e62d4cd` Fix webview no-history back pop
