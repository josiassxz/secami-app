// Testes de caracterizacao do WorkoutController — valida as transicoes de
// estado e persistencia de set_logs para startFromRoutine, confirmSet, skipSet
// e o guard de sessao inativa.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/sync/sync_providers.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/entities/planned_set.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:reps/features/workout/data/workout_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() {
    dotenv
        .testLoad(); // Observability.track consulta dotenv; sem init joga NotInitializedError.
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        effectiveUserIdProvider.overrideWithValue('u1'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Insere uma rotina 'r1' com um exercicio e uma serie planejada.
  Future<void> seedRoutine() async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r1', userId: 'u1', nome: 'Treino A'),
    );
    await db.routineDao.upsertExercise(
      RoutineExercisesCompanion.insert(
        id: 're1',
        routineId: 'r1',
        exerciseId: 'seed:supino_reto_barra',
        seriesPlanejadas: Value(
          PlannedSet.encode([
            const PlannedSet(numero: 1, repsAlvoMin: 8, repsAlvoMax: 12),
            const PlannedSet(numero: 2, repsAlvoMin: 8, repsAlvoMax: 12),
          ]),
        ),
      ),
    );
  }

  test('startFromRoutine cria sessao e popula slots', () async {
    await seedRoutine();

    final controller = container.read(workoutControllerProvider.notifier);
    final sessionId = await controller.startFromRoutine('r1');

    expect(sessionId, isNotEmpty);

    final state = container.read(workoutControllerProvider);
    expect(state, isNotNull);
    expect(state!.sessionId, sessionId);
    expect(state.cursor, 0);
    expect(state.slots, isNotEmpty);
    expect(state.slots.length, 2);

    final sess = await db.sessionDao.findById(sessionId);
    expect(sess, isNotNull);
  });

  test('confirmSet grava set_log executada e avanca cursor', () async {
    await seedRoutine();
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.startFromRoutine('r1');

    final before = container.read(workoutControllerProvider)!;
    await controller.confirmSet(repsRealizadas: 10, cargaKg: 50.0);

    final after = container.read(workoutControllerProvider)!;
    expect(after.cursor, before.cursor + 1);

    final logs = await db.setLogDao.ofSession(after.sessionId);
    expect(logs.where((l) => l.executada).length, 1);
    expect(logs.first.cargaKg, 50.0);
    expect(logs.first.repsRealizadas, 10);
  });

  test(
    'skipSet grava set_log nao executada com motivo e avanca cursor',
    () async {
      await seedRoutine();
      final controller = container.read(workoutControllerProvider.notifier);
      await controller.startFromRoutine('r1');

      final before = container.read(workoutControllerProvider)!;
      await controller.skipSet('equipamento_ocupado');

      final after = container.read(workoutControllerProvider)!;
      expect(after.cursor, before.cursor + 1);

      final logs = await db.setLogDao.ofSession(after.sessionId);
      final skipped = logs.firstWhere((l) => !l.executada);
      expect(skipped.motivoPulo, 'equipamento_ocupado');
    },
  );

  test('confirmSet sem sessao ativa e no-op', () async {
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.confirmSet(cargaKg: 40.0);
    expect(container.read(workoutControllerProvider), isNull);
  });

  test('skipSet sem sessao ativa e no-op', () async {
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.skipSet('cansado');
    expect(container.read(workoutControllerProvider), isNull);
  });

  // Regressao (double-submit): toque duplo rapido no botao CONCLUIR dispara
  // confirmSet 2x sobre o mesmo slot antes do cursor avancar. Sem o guard de
  // reentrancia, cada invocacao gera um setLogId novo => 2 linhas em set_logs
  // pra mesma serie (volume inflado, PR falso). Guard => a 2a e no-op.
  test('confirmSet duplo (concorrente) grava 1 linha e avanca 1', () async {
    await seedRoutine();
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.startFromRoutine('r1');

    final before = container.read(workoutControllerProvider)!;
    // Dispara as duas invocacoes antes de qualquer await terminar — simula o
    // toque duplo. A 2a pega _confirming=true (setado sincronamente pela 1a
    // antes do primeiro await) e vira no-op. Future.wait garante que a 1a
    // (unica que roda de verdade) terminou antes de checar o estado.
    final f1 = controller.confirmSet(repsRealizadas: 10, cargaKg: 50.0);
    final f2 = controller.confirmSet(repsRealizadas: 10, cargaKg: 50.0);
    await Future.wait([f1, f2]);

    final after = container.read(workoutControllerProvider)!;
    expect(after.cursor, before.cursor + 1);

    final logs = await db.setLogDao.ofSession(after.sessionId);
    final doSlot = logs
        .where((l) => l.ordemNoTreino == 0 && l.numeroSerie == 1)
        .toList();
    expect(doSlot.length, 1);
  });

  test('skipSet duplo (concorrente) grava 1 linha e avanca 1', () async {
    await seedRoutine();
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.startFromRoutine('r1');

    final before = container.read(workoutControllerProvider)!;
    final f1 = controller.skipSet('fadiga');
    final f2 = controller.skipSet('fadiga');
    await Future.wait([f1, f2]);

    final after = container.read(workoutControllerProvider)!;
    expect(after.cursor, before.cursor + 1);

    final logs = await db.setLogDao.ofSession(after.sessionId);
    final doSlot = logs
        .where((l) => l.ordemNoTreino == 0 && l.numeroSerie == 1)
        .toList();
    expect(doSlot.length, 1);
  });

  // O guard nao pode quebrar a edicao: goBackOneSet reabre o slot e reconfirmar
  // deve fazer upsert no MESMO setLogId (1 linha), com os valores atualizados.
  test('editar serie apos guard mantem 1 linha e atualiza valores', () async {
    await seedRoutine();
    final controller = container.read(workoutControllerProvider.notifier);
    await controller.startFromRoutine('r1');

    await controller.confirmSet(repsRealizadas: 10, cargaKg: 50.0);
    controller.goBackOneSet();
    await controller.confirmSet(repsRealizadas: 8, cargaKg: 60.0);

    final after = container.read(workoutControllerProvider)!;
    final logs = await db.setLogDao.ofSession(after.sessionId);
    final doSlot = logs
        .where((l) => l.ordemNoTreino == 0 && l.numeroSerie == 1)
        .toList();
    expect(doSlot.length, 1);
    expect(doSlot.first.cargaKg, 60.0);
    expect(doSlot.first.repsRealizadas, 8);
  });
}
