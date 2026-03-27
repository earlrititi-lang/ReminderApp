import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/features/reminders/presentation/utils/voice_reminder_parser.dart';

void main() {
  group('parseVoiceReminderCommand', () {
    test('extrae manana con hora numerica del titulo', () {
      final parsed = parseVoiceReminderCommand(
        'comprar pan mañana a las 8',
        now: DateTime(2026, 3, 26, 18, 15),
      );

      expect(parsed.title, 'Comprar pan');
      expect(parsed.hasSchedule, isTrue);
      expect(parsed.dateTime, DateTime(2026, 3, 27, 8));
    });

    test('extrae dia de la semana y mantiene el titulo limpio', () {
      final parsed = parseVoiceReminderCommand(
        'recuérdame llamar a mamá el viernes a las 20:30',
        now: DateTime(2026, 3, 26, 10),
      );

      expect(parsed.title, 'Llamar a mamá');
      expect(parsed.hasSchedule, isTrue);
      expect(parsed.dateTime, DateTime(2026, 3, 27, 20, 30));
    });

    test('si solo hay hora usa la siguiente ocurrencia', () {
      final parsed = parseVoiceReminderCommand(
        'pagar luz a las 7 de la tarde',
        now: DateTime(2026, 3, 26, 20),
      );

      expect(parsed.title, 'Pagar luz');
      expect(parsed.hasSchedule, isTrue);
      expect(parsed.dateTime, DateTime(2026, 3, 27, 19));
    });

    test('entiende fecha relativa con franja horaria', () {
      final parsed = parseVoiceReminderCommand(
        'estudiar pasado mañana por la tarde',
        now: DateTime(2026, 3, 26, 10),
      );

      expect(parsed.title, 'Estudiar');
      expect(parsed.hasSchedule, isTrue);
      expect(parsed.dateTime, DateTime(2026, 3, 28, 16));
    });

    test('sin fecha ni hora deja el titulo y no programa', () {
      final now = DateTime(2026, 3, 26, 10, 5);
      final parsed = parseVoiceReminderCommand(
        'comprar café',
        now: now,
      );

      expect(parsed.title, 'Comprar café');
      expect(parsed.hasSchedule, isFalse);
      expect(parsed.dateTime, now);
    });
  });
}
