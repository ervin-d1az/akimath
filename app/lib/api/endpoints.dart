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
  /// Absolute, or `sign-up/email` refuses with `MISSING_ORIGIN`: it wants an
  /// `Origin` header or an absolute destination, and a mobile app has neither
  /// to offer. Nothing follows this link — the code arrives by email — but it
  /// has to be well-formed.
  static const String callbackUrl = 'akimath://verified';

  static bool get configured => authBaseUrl.isNotEmpty && apiBaseUrl.isNotEmpty;
}
