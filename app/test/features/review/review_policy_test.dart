import 'package:cuadrante/features/review/domain/review_policy.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// When Turnly may ask for a store review: every rule of [ReviewPolicy] on a
/// fixed calendar (no clock involved).
void main() {
  final first = CivilDate(2026, 10, 1);
  final today = CivilDate(2026, 10, 8); // 7 days after the first launch

  ReviewState ready({
    int openDays = 5,
    int requestCount = 0,
    CivilDate? lastRequestDay,
    String? lastRequestVersion,
  }) => ReviewState(
    firstLaunch: first,
    lastOpenDay: today,
    openDays: openDays,
    requestCount: requestCount,
    lastRequestDay: lastRequestDay,
    lastRequestVersion: lastRequestVersion,
  );

  bool asks(
    ReviewState state, {
    CivilDate? on,
    String version = '1.2.0',
    bool hasShift = true,
    bool inFirstRun = false,
    bool afterRestoreOrImport = false,
  }) => ReviewPolicy.shouldAsk(
    state: state,
    today: on ?? today,
    appVersion: version,
    hasShift: hasShift,
    inFirstRun: inFirstRun,
    afterRestoreOrImport: afterRestoreOrImport,
  );

  group('ReviewPolicy.shouldAsk', () {
    test('asks when every condition holds', () {
      expect(asks(ready()), isTrue);
    });

    test('never on the first days: 7 days since the first launch', () {
      expect(asks(ready(), on: CivilDate(2026, 10, 7)), isFalse);
      expect(asks(ready(), on: CivilDate(2026, 10, 8)), isTrue);
      expect(asks(ReviewState.empty), isFalse);
    });

    test('needs 5 distinct days of use', () {
      expect(asks(ready(openDays: 4)), isFalse);
      expect(asks(ready(openDays: 5)), isTrue);
    });

    test('needs at least one shift in the active calendar', () {
      expect(asks(ready(), hasShift: false), isFalse);
    });

    test('not in the first-use flow', () {
      expect(asks(ready(), inFirstRun: true), isFalse);
    });

    test('not after a restore or an import', () {
      expect(asks(ready(), afterRestoreOrImport: true), isFalse);
    });

    test('at most one request per app version', () {
      final asked = ready(
        requestCount: 1,
        lastRequestDay: CivilDate(2026, 6, 1),
        lastRequestVersion: '1.2.0',
      );
      expect(asks(asked), isFalse);
      expect(asks(asked, version: '1.3.0'), isTrue);
    });

    test('90 days between requests', () {
      final last = CivilDate(2026, 7, 10);
      final asked = ready(
        requestCount: 1,
        lastRequestDay: last,
        lastRequestVersion: '1.1.0',
      );
      // 90 days after 10 jul is 8 oct.
      expect(today.differenceInDays(last), 90);
      expect(asks(asked), isTrue);
      expect(asks(asked, on: CivilDate(2026, 10, 7)), isFalse);
    });

    test('at most 3 requests ever', () {
      final three = ready(
        requestCount: 3,
        lastRequestDay: CivilDate(2025, 1, 1),
        lastRequestVersion: '0.9.0',
      );
      expect(asks(three), isFalse);
      expect(
        asks(
          ready(
            requestCount: 2,
            lastRequestDay: CivilDate(2025, 1, 1),
            lastRequestVersion: '0.9.0',
          ),
        ),
        isTrue,
      );
    });
  });

  group('ReviewState', () {
    test('counts each civil day once, however many times it opens', () {
      var state = ReviewState.empty.withOpenOn(first);
      state = state.withOpenOn(first).withOpenOn(first);
      expect(state.openDays, 1);
      expect(state.firstLaunch, first);
      state = state.withOpenOn(CivilDate(2026, 10, 2));
      expect(state.openDays, 2);
      expect(state.firstLaunch, first);
    });

    test('a clock that goes back does not count a day twice', () {
      final state = ReviewState.empty
          .withOpenOn(CivilDate(2026, 10, 5))
          .withOpenOn(CivilDate(2026, 10, 3));
      expect(state.openDays, 1);
      expect(state.lastOpenDay, CivilDate(2026, 10, 5));
    });

    test('a request is recorded with its day and version', () {
      final state = ready().withRequestOn(today, '1.2.0');
      expect(state.requestCount, 1);
      expect(state.lastRequestDay, today);
      expect(state.lastRequestVersion, '1.2.0');
    });

    test('survives a round trip through JSON', () {
      final state = ready(
        requestCount: 2,
        lastRequestDay: CivilDate(2026, 7, 10),
        lastRequestVersion: '1.1.0',
      );
      final again = ReviewState.fromJson(state.toJson());
      expect(again.toJson(), state.toJson());
    });

    test('malformed fields fall back to nothing recorded', () {
      final state = ReviewState.fromJson({
        'firstLaunch': 'not a date',
        'openDays': -3,
        'requestCount': 'many',
        'lastRequestVersion': 4,
      });
      expect(state.toJson(), ReviewState.empty.toJson());
    });
  });
}
