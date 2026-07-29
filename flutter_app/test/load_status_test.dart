import 'package:flutter_test/flutter_test.dart';
import 'package:lobos_trucking/models/load_status.dart';

void main() {
  group('LoadProgressStatus', () {
    test('allows the required driver workflow in order', () {
      expect(
        LoadProgressStatus.assigned.canTransitionTo(
          LoadProgressStatus.accepted,
        ),
        isTrue,
      );
      expect(
        LoadProgressStatus.accepted.canTransitionTo(
          LoadProgressStatus.arrivedAtPickup,
        ),
        isTrue,
      );
      expect(
        LoadProgressStatus.arrivedAtPickup.canTransitionTo(
          LoadProgressStatus.inTransit,
        ),
        isTrue,
      );
      expect(
        LoadProgressStatus.inTransit.canTransitionTo(
          LoadProgressStatus.delivered,
        ),
        isTrue,
      );
    });

    test('rejects skipped and post-delivery transitions', () {
      expect(
        LoadProgressStatus.assigned.canTransitionTo(
          LoadProgressStatus.delivered,
        ),
        isFalse,
      );
      expect(
        LoadProgressStatus.delivered.canTransitionTo(
          LoadProgressStatus.assigned,
        ),
        isFalse,
      );
    });

    test('uses stable Firestore values', () {
      for (final status in LoadProgressStatus.values) {
        expect(LoadProgressStatus.fromValue(status.value), status);
      }
    });
  });
}
