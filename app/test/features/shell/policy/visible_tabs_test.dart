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

  group('what the app actually has', () {
    test('the roots that exist today produce a three-tab bar', () {
      // **This asserted none, then two, and now three**, and the change is the
      // whole mechanism each time: `visibleTabs` was not touched. A destination
      // was added to the set below and the rule returned one more.
      expect(rootsPresentToday, <AppTab>{AppTab.home, AppTab.progress, AppTab.profile});
      expect(visibleTabs(rootsPresentToday),
          <AppTab>[AppTab.home, AppTab.progress, AppTab.profile]);
    });

    test('and they come back in declaration order, not insertion order', () {
      // `progress` is declared before `profile` and was added after it. A bar
      // that shifted under the player depending on which root registered first
      // is what the ordering in `visibleTabs` prevents.
      expect(visibleTabs(<AppTab>{AppTab.profile, AppTab.progress, AppTab.home}),
          <AppTab>[AppTab.home, AppTab.progress, AppTab.profile]);
    });

    test('the one tab that has no root is not drawn', () {
      // `skills` at F5. Four tabs with one dead is the thing this policy exists
      // to prevent.
      expect(visibleTabs(rootsPresentToday), isNot(contains(AppTab.skills)));
    });
  });
}
