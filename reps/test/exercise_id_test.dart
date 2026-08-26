// Stage-07 5.1: parser central de id de exercício.

import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/entities/exercise_id.dart';

void main() {
  test('seed: vira slug', () {
    final id = ExerciseId.parse('seed:supino-reto');
    expect(id.isSeed, isTrue);
    expect(id.value, 'supino-reto');
    expect(id.librarySlug, 'supino-reto');
  });

  test('extdb: preserva o id cru no librarySlug (comportamento antigo)', () {
    final id = ExerciseId.parse('extdb:agachamento-bulgaro');
    expect(id.isExtdb, isTrue);
    expect(id.value, 'agachamento-bulgaro');
    expect(id.librarySlug, 'extdb:agachamento-bulgaro');
  });

  test('custom: detectado e cru preservado', () {
    final id = ExerciseId.parse('custom:abc-123');
    expect(id.isCustom, isTrue);
    expect(id.value, 'abc-123');
    expect(id.librarySlug, 'custom:abc-123');
  });

  test('uuid cru sem prefixo', () {
    final id = ExerciseId.parse('e3f1-uuid');
    expect(id.kind, ExerciseIdKind.raw);
    expect(id.librarySlug, 'e3f1-uuid');
  });
}
