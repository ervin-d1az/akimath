import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/features/home/policy/offline_notice.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which answers to a pack request mean the device has no signal.
///
/// **Every variant of both sealed types is passed in.** A `hasLength` over
/// `PackAsk.values` would be green with half the arms unreachable (PROC-11);
/// what makes this a test is that each result the client can build is named
/// here, so a tenth variant is both a compile error in the policy and a gap
/// visible in this list.

final IssuedPack _issued = IssuedPack(
  packId: 'p1',
  issuedAt: DateTime.utc(2026, 8, 1),
  expiresAt: DateTime.utc(2099),
  pack: const <String, dynamic>{},
);

void main() {
  group('POST /packs', () {
    final Map<String, IssueResult> answers = <String, IssueResult>{
      'a pack': IssueDone(_issued),
      'no player yet': const IssueNoPlayer(),
      'a refused session':
          const IssueRejected(tag: 'unauthorized', message: 'no'),
      'an unusable answer': const IssueFailed(status: 500, reason: 'boom'),
    };

    test('anything the server said is the server talking', () {
      for (final MapEntry<String, IssueResult> answer in answers.entries) {
        expect(
          issueAsk(answer.value),
          PackAsk.answered,
          reason: '${answer.key} was read as evidence of no signal',
        );
      }
      expect(answers, hasLength(4));
    });

    test('nothing at all is the one that means offline', () {
      expect(
        issueAsk(const IssueUnreachable('no route to host')),
        PackAsk.nothingAnswered,
      );
    });
  });

  group('GET /packs/{packId}', () {
    final Map<String, FetchPackResult> answers = <String, FetchPackResult>{
      'the pack again': FetchPackDone(_issued),
      // A 404 is the server saying there is no such pack for this player,
      // which is a fact rather than a silence — the route mints a new one.
      'no such pack': const FetchPackGone(),
      'a refused session':
          const FetchPackRejected(tag: 'unauthorized', message: 'no'),
      'an unusable answer':
          const FetchPackFailed(status: 503, reason: 'boom'),
    };

    test('anything the server said is the server talking', () {
      for (final MapEntry<String, FetchPackResult> answer in answers.entries) {
        expect(
          fetchAsk(answer.value),
          PackAsk.answered,
          reason: '${answer.key} was read as evidence of no signal',
        );
      }
      expect(answers, hasLength(4));
    });

    test('nothing at all is the one that means offline', () {
      expect(
        fetchAsk(const FetchPackUnreachable('timed out')),
        PackAsk.nothingAnswered,
      );
    });
  });

  test('the two halves agree about what silence means', () {
    // They are separate functions over separate sealed types, which is exactly
    // how they could drift. `AccountState` makes the same call for `GET /me`.
    expect(
      issueAsk(const IssueUnreachable('x')),
      fetchAsk(const FetchPackUnreachable('x')),
    );
  });
}
