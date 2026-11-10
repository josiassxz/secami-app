import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/academy/data/academy_api.dart';

void main() {
  ScheduledAppointment ag(String date, String slot) => ScheduledAppointment(
    id: 'a',
    date: date,
    slotStart: slot,
    slotEnd: slot,
    status: 'confirmado',
  );

  test('horário já começado sai da agenda (não pode ser cancelado)', () {
    final agora = DateTime(2026, 11, 10, 12, 30);
    expect(ag('2026-11-09', '18:00').jaComecou(agora), isTrue);
    expect(ag('2026-11-10', '12:00').jaComecou(agora), isTrue);
    expect(ag('2026-11-10', '13:00').jaComecou(agora), isFalse);
    expect(ag('2026-11-11', '08:00').jaComecou(agora), isFalse);
  });
}
