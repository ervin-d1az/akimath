import 'package:flutter/widgets.dart';

import '../../../design/widgets/centered_state_view.dart';
import '../policy/adults_only_copy.dart';

/// Where a band below adulthood goes, and it is not the account form.
///
/// **A refusal, not a deferral, and the difference is the whole screen.** It
/// replaces `TutorConsentScreen`, which offered a way forward — a tutor's
/// permission — that ADR 0004 means the product will never honour. Leaving that
/// offer standing, or greying it out, is the failure DR-P2 names: a control that
/// cannot act reads as broken rather than as closed, and a player cannot tell
/// *not yet* from *not for you*.
///
/// **Two ways in, one screen.** The account door reaches it from the age gate,
/// and the sign-in door reaches it when `GET /me` answers with a band the server
/// already stored. What the copy may claim is bounded by that — see
/// `adults_only_copy.dart`, which is where every word on this screen lives.
///
/// **[CenteredStateView], which the screen it replaces should have used.** That
/// frame is *"something to look at, a headline, a line of explanation, and a way
/// out"*, which is this screen exactly; the hand-rolled column it replaces
/// overflowed by 42 px at `textScaler` 1.3 the moment the copy grew past two
/// lines, because `Spacer` cannot yield and a scroll view is the thing that can.
///
/// **It is the adapter.** No decision, no string of its own: the words are the
/// pure layer's and the one control is the caller's.
class AdultsOnlyScreen extends StatelessWidget {
  const AdultsOnlyScreen({super.key, required this.onBack});

  /// Leaves the flow entirely. There is nothing behind this screen to go back
  /// to — `auth_flow.dart` clears the trail on the way in, so
  /// `req-no-account-without-a-declaration`'s *no path from here reaches the
  /// form* is true by construction rather than by a guard somebody has to
  /// remember.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => CenteredStateView(
    // Resting, not `slip`. A refusal is not a wrong answer and she does not
    // look disappointed in the player.
    aki: true,
    headlineLines: const <String>[adultsOnlyHeadline],
    body: adultsOnlyDetail,
    primary: stateAction(adultsOnlyDoorLabel, onBack),
  );
}
