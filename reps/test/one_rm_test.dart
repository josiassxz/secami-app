import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/usecases/one_rm.dart';

void main() {
  test('Epley: 100kg x 10 reps ~= 133.33kg', () {
    expect(oneRmEpley(100, 10), closeTo(133.333, 0.01));
  });

  test('Epley: 1 rep retorna a propria carga', () {
    expect(oneRmEpley(80, 1), closeTo(82.667, 0.01)); // 80*(1+1/30)
  });

  test('reps <= 0 retorna a carga', () {
    expect(oneRmEpley(60, 0), 60);
  });
}
