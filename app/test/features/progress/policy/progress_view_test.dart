import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/progress/policy/progress_view.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry() => HistoryEntry(
  kind: HistoryKind.series,
  title: 'Restas',
  at: DateTime.utc(2026, 8, 19, 9, 15),
  score: '4/5',
  ratingDelta: null,
);

void main() {
  group('what a history lookup came back as', () {
    test('nothing yet is the request still in flight', () {
      expect(historyStateFor(null), HistoryState.loading);
    });

    test('sessions are a list, and no sessions is a different screen', () {
      // Not the same as an error and not the same as a list: a player who has
      // linked and not synced is told what will appear, not apologised to.
      expect(historyStateFor(HistoryFound(History(<HistoryEntry>[_entry()]))),
          HistoryState.ready);
      expect(historyStateFor(const HistoryFound(History(<HistoryEntry>[]))),
          HistoryState.empty);
    });

    test('an account with no player shows the same nothing', () {
      // There is no play to show either way, and "link a player first" is not a
      // sentence this screen can act on.
      expect(historyStateFor(const HistoryNoPlayer()), HistoryState.empty);
    });

    test('the three ways it can fail stay apart', () {
      expect(historyStateFor(const HistoryRejected(tag: 'invalid_session', message: '')),
          HistoryState.rejected);
      expect(historyStateFor(const HistoryFailed(status: 500, reason: '')),
          HistoryState.serverError);
      expect(historyStateFor(const HistoryUnreachable('no route')), HistoryState.offline);
    });
  });

  group('when asking again is worth offering', () {
    test('only where the answer could change', () {
      expect(canRetryHistory(HistoryState.offline), isTrue);
      expect(canRetryHistory(HistoryState.serverError), isTrue);
    });

    test('and never where it could not', () {
      for (final HistoryState state in <HistoryState>[
        HistoryState.noAccount,
        HistoryState.loading,
        HistoryState.ready,
        HistoryState.empty,
        HistoryState.rejected,
      ]) {
        expect(canRetryHistory(state), isFalse, reason: state.name);
      }
    });
  });

  group('whose problem it is', () {
    test('losing signal is nobody´s mistake', () {
      // The plan is explicit: *"Sin conexión no es un error del usuario: va en
      // amarillo."* The same judgement the account section makes.
      expect(isOurProblem(HistoryState.offline), isFalse);
      expect(isOurProblem(HistoryState.noAccount), isFalse);
      expect(isOurProblem(HistoryState.empty), isFalse);
    });

    test('and a refusal or an unreadable answer is ours', () {
      expect(isOurProblem(HistoryState.rejected), isTrue);
      expect(isOurProblem(HistoryState.serverError), isTrue);
    });
  });

  group('whether the section is drawn at all', () {
    test('nothing that can only ever be empty', () {
      // The first version told a player with no history *"los de hoy aparecen
      // aquí"*, and they do not: nothing in the app sends an attempt yet. A
      // heading over a section that would stay empty however much they played
      // is the same mistake as a toggle that does nothing (DR-P2).
      expect(historyWorthDrawing(HistoryState.noAccount), isFalse);
      expect(historyWorthDrawing(HistoryState.empty), isFalse);
    });

    test('but everything there is something true to say about', () {
      // A list, a wait for one, or a failure to fetch one.
      for (final HistoryState state in <HistoryState>[
        HistoryState.ready,
        HistoryState.loading,
        HistoryState.rejected,
        HistoryState.serverError,
        HistoryState.offline,
      ]) {
        expect(historyWorthDrawing(state), isTrue, reason: state.name);
      }
    });

    test('and every state is decided one way or the other', () {
      // The control: a state added later has to be classified, and this fails
      // if the switch grows a default instead.
      expect(
        HistoryState.values.map(historyWorthDrawing).toSet(),
        <bool>{true, false},
      );
    });
  });

  group('the copy', () {
    test('a drawn state that is not a list says something', () {
      for (final HistoryState state in HistoryState.values) {
        final String? message = historyMessage(state);
        if (state == HistoryState.ready ||
            state == HistoryState.loading ||
            !historyWorthDrawing(state)) {
          expect(message, isNull, reason: state.name);
        } else {
          expect(message, isNotNull, reason: state.name);
          expect(message, isNotEmpty, reason: state.name);
        }
      }
    });

    test('and no two of them say the same thing', () {
      final List<String> said = HistoryState.values
          .map(historyMessage)
          .whereType<String>()
          .toList();
      expect(said, isNotEmpty);
      expect(said.toSet(), hasLength(said.length));
    });

    test('and none of them promises something the app cannot do', () {
      // Sync does not exist yet. Any sentence implying a played round will turn
      // up here is a promise the product cannot keep.
      for (final String message
          in HistoryState.values.map(historyMessage).whereType<String>()) {
        expect(message, isNot(contains('aparecen')), reason: message);
        expect(message, isNot(contains('se guardan')), reason: message);
      }
    });
  });

  group('how a date reads beside a score', () {
    test('the day and the month, abbreviated', () {
      expect(entryDate(DateTime(2026, 8, 19)), '19 ago');
      expect(entryDate(DateTime(2026, 1, 1)), '1 ene');
      expect(entryDate(DateTime(2026, 12, 31)), '31 dic');
    });

    test('every month has a name, and no two share one', () {
      final List<String> named = List<int>.generate(12, (int i) => i + 1)
          .map((int month) => entryDate(DateTime(2026, month, 1)))
          .toList();
      expect(named.toSet(), hasLength(12));
      for (final String name in named) {
        expect(name.split(' ').last.length, 3);
      }
    });

    test('no leading zero, because nobody writes one', () {
      expect(entryDate(DateTime(2026, 3, 5)), '5 mar');
      expect(entryDate(DateTime(2026, 3, 5)), isNot(contains('05')));
    });
  });
}
