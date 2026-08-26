import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/grupo_exercicio.dart';
import '../../../domain/entities/planned_set.dart';
import '../../auth/data/auth_providers.dart';

const _uuid = Uuid();

class RoutineService {
  RoutineService(this._db, this._userId);

  final AppDatabase _db;
  final String _userId;

  Stream<List<RoutineRow>> watchAll() => _db.routineDao.watchAtivas(_userId);

  Future<RoutineRow?> findById(String id) => _db.routineDao.findById(id);

  Stream<RoutineRow?> watchById(String id) => _db.routineDao.watchById(id);

  Stream<List<RoutineExerciseRow>> watchExercises(String routineId) =>
      _db.routineDao.watchExercisesOf(routineId);

  Future<List<RoutineExerciseRow>> exercisesOf(String routineId) =>
      _db.routineDao.exercisesOf(routineId);

  Future<String> create({
    required String nome,
    required String tipo,
    required List<int> diasDaSemana,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _db.routineDao.upsert(
      RoutinesCompanion.insert(
        id: id,
        userId: _userId,
        nome: nome,
        tipo: Value(tipo),
        diasDaSemana: Value(_encodeDias(diasDaSemana)),
        criadoEm: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> rename(String id, String nome) async {
    await _db.routineDao.upsert(
      RoutinesCompanion(id: Value(id), nome: Value(nome)),
    );
  }

  Future<void> updateDias(String id, List<int> diasDaSemana) async {
    await _db.routineDao.upsert(
      RoutinesCompanion(
        id: Value(id),
        diasDaSemana: Value(_encodeDias(diasDaSemana)),
      ),
    );
  }

  Future<void> updateTipo(String id, String tipo) async {
    await _db.routineDao.upsert(
      RoutinesCompanion(id: Value(id), tipo: Value(tipo)),
    );
  }

  Future<void> remove(String id) async {
    await _db.routineDao.softDelete(id);
  }

  Future<String> addExercise({
    required String routineId,
    required String exerciseId,
    required int ordem,
    List<PlannedSet> series = const [],
    String? notas,
  }) async {
    final id = _uuid.v4();
    await _db.routineDao.upsertExercise(
      RoutineExercisesCompanion.insert(
        id: id,
        routineId: routineId,
        exerciseId: exerciseId,
        ordem: Value(ordem),
        seriesPlanejadas: Value(PlannedSet.encode(series)),
        notas: Value(notas),
      ),
    );
    return id;
  }

  Future<void> updateExerciseSeries({
    required String routineExerciseId,
    required List<PlannedSet> series,
    String? notas,
  }) async {
    await _db.routineDao.updateExercise(
      routineExerciseId,
      RoutineExercisesCompanion(
        seriesPlanejadas: Value(PlannedSet.encode(series)),
        notas: notas == null ? const Value.absent() : Value(notas),
      ),
    );
  }

  Future<void> removeExercise(String routineExerciseId) async {
    await _db.routineDao.softDeleteExercise(routineExerciseId);
  }

  Future<void> reorderExercises(
    String routineId,
    List<String> orderedIds,
  ) async {
    await _db.routineDao.reorderExercises(routineId, orderedIds);
  }

  // ===== Agrupamento bi-set / circuito (Feature A) =====

  /// Agrupa o exercicio `reId` com o exercicio imediatamente anterior na ordem.
  /// Se o anterior ja e um grupo, entra nele (circuito de 3+). Senao, cria um
  /// grupo novo bi-set com os dois.
  Future<void> agruparComAnterior(String routineId, String reId) async {
    final list = await exercisesOf(routineId);
    final i = list.indexWhere((e) => e.id == reId);
    if (i <= 0) return;
    final prev = list[i - 1];
    final cur = list[i];
    final prevAgrupado = prev.grupoId != null;
    final gid = prev.grupoId ?? _uuid.v4();
    final tipo = prevAgrupado ? prev.grupoTipo : GrupoTipo.bi_set.name;
    final rounds = prevAgrupado ? prev.rounds : null;
    if (!prevAgrupado) {
      await _db.routineDao.updateExercise(
        prev.id,
        RoutineExercisesCompanion(
          grupoId: Value(gid),
          grupoTipo: Value(tipo),
          rounds: Value(rounds),
        ),
      );
    }
    await _db.routineDao.updateExercise(
      cur.id,
      RoutineExercisesCompanion(
        grupoId: Value(gid),
        grupoTipo: Value(tipo),
        rounds: Value(rounds),
      ),
    );
  }

  /// Tira o exercicio do grupo. Se o grupo ficar com um unico membro, esse
  /// membro tambem volta a solo (grupo de 1 nao faz sentido).
  Future<void> desagrupar(String routineId, String reId) async {
    final list = await exercisesOf(routineId);
    final cur = list.firstWhereOrNull((e) => e.id == reId);
    if (cur == null) return; // ja foi removido (ex.: sync de outro device)
    final gid = cur.grupoId;
    await _db.routineDao.updateExercise(
      reId,
      const RoutineExercisesCompanion(
        grupoId: Value(null),
        grupoTipo: Value('normal'),
        rounds: Value(null),
      ),
    );
    if (gid != null) {
      final restantes = list
          .where((e) => e.grupoId == gid && e.id != reId)
          .toList();
      if (restantes.length == 1) {
        await _db.routineDao.updateExercise(
          restantes.first.id,
          const RoutineExercisesCompanion(
            grupoId: Value(null),
            grupoTipo: Value('normal'),
            rounds: Value(null),
          ),
        );
      }
    }
  }

  /// Define o tipo (bi-set/circuito) e, no circuito, o nº de rodadas, para
  /// todos os membros de um grupo.
  Future<void> definirTipoGrupo({
    required String routineId,
    required String grupoId,
    required GrupoTipo tipo,
    int? rounds,
  }) async {
    final list = await exercisesOf(routineId);
    for (final e in list.where((e) => e.grupoId == grupoId)) {
      await _db.routineDao.updateExercise(
        e.id,
        RoutineExercisesCompanion(
          grupoTipo: Value(tipo.name),
          rounds: Value(rounds),
        ),
      );
    }
  }

  static List<int> decodeDias(String raw) {
    if (raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<int>();
    } on FormatException {
      return const [];
    }
  }

  static String _encodeDias(List<int> dias) => jsonEncode(dias);
}

final routineServiceProvider = Provider<RoutineService>((ref) {
  return RoutineService(
    ref.watch(appDatabaseProvider),
    ref.watch(effectiveUserIdProvider),
  );
});

final routinesAtivasProvider = StreamProvider<List<RoutineRow>>((ref) {
  return ref.watch(routineServiceProvider).watchAll();
});

final routineExercisesProvider =
    StreamProvider.family<List<RoutineExerciseRow>, String>((ref, routineId) {
      return ref.watch(routineServiceProvider).watchExercises(routineId);
    });

/// Stream da rotina por id - atualiza quando a rotina sofre escritas
/// (rename, dias, soft delete, etc).
final routineByIdProvider = StreamProvider.family<RoutineRow?, String>((
  ref,
  id,
) {
  return ref.watch(routineServiceProvider).watchById(id);
});
