import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/features/routines/data/routine_providers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('desagrupar de exercicio inexistente nao lanca', () async {
    final service = RoutineService(db, 'u1');
    await expectLater(
      service.desagrupar('rotina-qualquer', 'id-que-nao-existe'),
      completes,
    );
  });
}
