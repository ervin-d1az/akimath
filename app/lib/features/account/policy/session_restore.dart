import 'package:meta/meta.dart';

import '../../../api/auth_result.dart';
import 'session.dart';

/// What a launch does with the credential it found on disk.
///
/// **PURE** — a stored session and one provider answer in, one of three
/// outcomes out. No socket, no storage, no clock.
///
/// It exists because the decision has three branches and one of them is easy to
/// get wrong inside a `Future` chain where nobody can see it: a device that
/// treats *"the provider did not answer"* as *"the credential is dead"* signs a
/// player out for being on a plane, and there is nothing on screen to say why.
/// The same split `packRefresh` makes — a 404 is the one answer that means
/// issue a new one, while refused, broken and unreachable mint nothing — and
/// the same split the attempt journal makes between a batch to drop and a batch
/// to keep.
///
/// **A sealed union rather than an enum**, so the one outcome that produces a
/// session carries it. An enum would leave the caller casting the answer back
/// to `AuthOk` to reach the token, which is the decision made twice in two
/// places that can disagree.
@immutable
sealed class SessionRestore {
  const SessionRestore();
}

/// A token came back. Hold [session], and keep the credential where it is.
@immutable
final class SessionRestored extends SessionRestore {
  const SessionRestored(this.session);
  final LinkedSession session;
}

/// The provider refused the stored credential. **Delete it.**
///
/// Asking again next launch gets the same refusal, and a device that keeps
/// rubbish tries for ever. The player lands on the app signed out, which is
/// `AccountState.rejected`'s territory: the account is real and this device's
/// credential is not, and `4.1`'s door reads *"Volver a entrar"*.
@immutable
final class SessionForgotten extends SessionRestore {
  const SessionForgotten();
}

/// Nothing usable came back. **Keep it** and come up signed out for this
/// launch only.
///
/// Offline, or a provider having a bad minute. Neither is evidence about the
/// credential, and deleting on either is the failure this union exists to
/// prevent.
@immutable
final class SessionKept extends SessionRestore {
  const SessionKept();
}

/// The decision.
///
/// [providerAnswer] is what `AuthApi.accessToken` said when [stored]'s
/// credential was handed to it. There is deliberately no outcome for *nothing
/// was stored*: that is the absence of a decision rather than one of its
/// results, and the caller has already returned.
SessionRestore sessionRestore({
  required StoredSession stored,
  required AuthResult<String> providerAnswer,
}) =>
    switch (providerAnswer) {
      AuthOk<String>(value: final String accessToken) =>
        SessionRestored(stored.linkedWith(accessToken)),
      AuthRefused<String>() => const SessionForgotten(),
      // Grouped with each other and **not** with the refusal: a 500, or a 200
      // whose body carried no token, says the provider is unwell and says
      // nothing about the cookie.
      AuthFailed<String>() || AuthUnreachable<String>() => const SessionKept(),
    };
