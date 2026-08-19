/// Where the app talks to, supplied at build time.
///
/// **`--dart-define`, not a constant in the tree.** These differ per
/// environment and one of them names the project's own Neon endpoint; baking
/// either into the repository makes the build the wrong place to change them
/// and puts a deployment detail in git.
///
/// Both empty is the ordinary state of a build nobody configured, and
/// [configured] is what a screen checks rather than discovering it as a failed
/// request.
abstract final class Endpoints {
  /// Neon Auth's base, e.g. `https://ep-….neon.tech/neondb/auth`.
  static const String authBaseUrl = String.fromEnvironment('NEON_AUTH_BASE_URL');

  /// The AkiMath server's base, including any version prefix.
  static const String apiBaseUrl = String.fromEnvironment('AKIMATH_API_BASE_URL');

  /// Where the provider is told to send a browser after verification.
  ///
  /// **The auth base URL itself, and it has to be something already trusted.**
  /// Two provider rules meet here. It must be absolute, or `sign-up/email`
  /// answers `MISSING_ORIGIN` — it wants an `Origin` header or an absolute
  /// destination, and a mobile app has neither. And it must sit inside a
  /// trusted origin, or it answers **403 `INVALID_CALLBACK_URL`**; with
  /// `trusted_origins` empty, the only trusted origin is the provider's own.
  ///
  /// Measured, not guessed: `akimath://verified`, `http://localhost`,
  /// `http://localhost/verified` and `http://localhost:8791/verified` are all
  /// 403, and the auth URL is the one that gets through.
  ///
  /// **Nothing ever follows this link.** Verification is a code typed into
  /// `1.3`, not a link tapped in a mail client, so the value only has to
  /// satisfy the provider. The alternative is adding a scheme to
  /// `trusted_origins` in the console, which is worth doing the day a link
  /// actually needs to reach the app — and not before, because an origin
  /// trusted for nothing is a trusted origin nobody is watching.
  static String get callbackUrl => authBaseUrl;

  static bool get configured => authBaseUrl.isNotEmpty && apiBaseUrl.isNotEmpty;
}
