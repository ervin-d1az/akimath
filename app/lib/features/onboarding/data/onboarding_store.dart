import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the first run has happened.
///
/// One boolean under one key, on the `shared_preferences` the day log already
/// uses — no new dependency, and the audit for that one is recorded in
/// `dependency_allowlist_test.dart`.
///
/// **A flag, not a version.** Storing a version number would let a later
/// onboarding be re-shown to existing players, and nobody has asked for that —
/// a version whose semantics nobody has decided is a decision taken by default.
/// Renaming the key does the same job on the day it is actually wanted.
class OnboardingStore {
  const OnboardingStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  static const String key = 'akimath.onboarding_complete.v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ?? SharedPreferencesAsync();

  /// Whether the onboarding has been completed.
  ///
  /// **Anything unreadable reports `false`**, so the welcome screen is shown.
  /// The alternative — assuming completion — skips the only screen that teaches
  /// the answer format, for a player who may never have seen it. Showing it
  /// twice costs a few seconds; skipping it costs the explanation.
  ///
  /// Failures are reported rather than swallowed: a tolerant adapter must still
  /// be a loud one, which is the lesson a silent day-log store already cost.
  Future<bool> isComplete() async {
    try {
      return await _prefs.getBool(key) ?? false;
    } catch (error) {
      // **Deliberately broad.** A key holding the wrong type throws a
      // `TypeError`, which is an `Error` and not an `Exception` — so
      // `on Exception` misses it and a launch dies on a corrupt preference. The
      // rule here is that *nothing* about the stored value may prevent a
      // launch, and that is wider than the exception hierarchy.
      debugPrint('onboarding: could not read ($error)');
      return false;
    }
  }

  Future<void> markComplete() async {
    try {
      await _prefs.setBool(key, true);
    } catch (error) {
      // The onboarding will be shown again next launch. Mildly annoying, and
      // strictly better than a launch that fails. Broad for the same reason as
      // the read.
      debugPrint('onboarding: could not write ($error)');
    }
  }
}
