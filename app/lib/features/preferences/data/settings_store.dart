/// Where one screen's settings are kept between launches.
///
/// **A seam with two sides**, the same shape `DayLogStore` and
/// `StreakNoticeStore` have: the interface so a widget test can hand in memory,
/// and a `shared_preferences` implementation the app runs on. Generic over the
/// value because `4.4`, `4.5` and `4.6` differ only in what they hold — three
/// copies of `read`/`write` would be three chances to swallow an error in a
/// different way.
abstract interface class SettingsStore<T> {
  /// What is stored, or the defaults when nothing is or what is there cannot be
  /// read. Never throws: a settings screen that cannot open is worse than one
  /// showing the defaults.
  Future<T> read();

  /// Records [settings]. Never throws for the same reason — a preference that
  /// could not be written is a preference lost, not a screen lost.
  Future<void> write(T settings);
}

/// A store that forgets when the app closes.
///
/// Not a stub: it is the correct implementation of "remember within a session",
/// and it is what a widget test hands in so no test touches the platform.
class InMemorySettingsStore<T> implements SettingsStore<T> {
  InMemorySettingsStore(this._settings);

  T _settings;

  @override
  Future<T> read() async => _settings;

  @override
  Future<void> write(T settings) async {
    _settings = settings;
  }
}
