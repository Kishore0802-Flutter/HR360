import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session labels and late format', () {
    String formatLateMinutes(int lateMinutes) {
      if (lateMinutes < 60) return '$lateMinutes min late';
      if (lateMinutes % 60 == 0) return '${lateMinutes ~/ 60}h late';
      return '${lateMinutes ~/ 60}h ${lateMinutes % 60}m late';
    }

    test('formatLateMinutes formats minutes into hours and minutes', () {
      expect(formatLateMinutes(379), equals('6h 19m late'));
      expect(formatLateMinutes(60), equals('1h late'));
      expect(formatLateMinutes(125), equals('2h 5m late'));
      expect(formatLateMinutes(45), equals('45 min late'));
    });

    test('sessions list has Full day, First half, and Second half', () {
      const sessions = [
        ('Full day', 'FULL'),
        ('First half', 'FIRST_HALF'),
        ('Second half', 'SECOND_HALF'),
      ];

      expect(sessions.map((s) => s.$1).toList(), equals(['Full day', 'First half', 'Second half']));
      expect(sessions.map((s) => s.$2).toList(), equals(['FULL', 'FIRST_HALF', 'SECOND_HALF']));
    });
  });
}
