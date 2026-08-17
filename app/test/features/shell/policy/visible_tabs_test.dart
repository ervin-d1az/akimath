import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the nav renders only tabs that have roots', () {
    test('one root means no navigation at all', () {
      // D12. At F2 the map is unbuilt and profile is F7, so a four-tab bar
      // would be one live tab and three dead ones — worse than no bar.
      expect(
        visibleTabs(<AppTab>{AppTab.home}),
        isEmpty,
        reason: 'a bar with one tab is a bar with nothing to switch to',
      );
    });

    test('two roots is the first time a bar is worth drawing', () {
      expect(
        visibleTabs(<AppTab>{AppTab.home, AppTab.skills}),
        <AppTab>[AppTab.home, AppTab.skills],
      );
    });

    test('no roots means no navigation', () {
      expect(visibleTabs(<AppTab>{}), isEmpty);
    });

    test('the order is the declaration order, not the insertion order', () {
      // A tab that appears in a different place depending on which root
      // happened to register first is a bar that moves under the player.
      expect(
        visibleTabs(<AppTab>{AppTab.profile, AppTab.home, AppTab.skills}),
        <AppTab>[AppTab.home, AppTab.skills, AppTab.profile],
      );
    });

    test('a tab with no root never renders', () {
      expect(
        visibleTabs(<AppTab>{AppTab.home, AppTab.profile}),
        isNot(contains(AppTab.skills)),
      );
    });
  });

  group('what F2 actually has', () {
    test('the roots that exist today produce no bar', () {
      expect(visibleTabs(rootsPresentToday), isEmpty);
      expect(rootsPresentToday, <AppTab>{AppTab.home});
    });
  });
}
