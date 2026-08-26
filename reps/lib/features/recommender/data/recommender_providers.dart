import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_providers.dart';
import '../../library/data/library_repository.dart';
import '../../routines/data/routine_providers.dart';
import '../domain/engine/workout_recommender.dart';
import '../domain/questionario.dart';
import '../domain/treino_recomendado.dart';
import '../domain/triagem.dart';
import 'recommender_consent.dart';

const _uuid = Uuid();

/// Servico do recomendador: gera o treino pelo motor, persiste o registro
/// auditavel (RN-050) respeitando o consentimento (RN-051) e salva o treino
/// como rotina(s) reusando o [RoutineService].
class RecommenderService {
  RecommenderService(
    this._db,
    this._library,
    this._routines,
    this._userId, {
    required this.consentimentoSaude,
  });

  final AppDatabase _db;
  final LibraryRepository _library;
  final RoutineService _routines;
  final String _userId;
  final bool consentimentoSaude;

  static const _motor = WorkoutRecommender();

  Future<TreinoRecomendado> gerar({
    required PerfilQuestionario perfil,
    required RespostasTriagem triagem,
    int variacao = 0,
  }) async {
    await _library.ensureLoaded();
    final treino = _motor.gerar(
      perfil: perfil,
      triagem: triagem,
      biblioteca: _library.all(),
      variacao: variacao,
    );
    await _persistir(perfil, triagem, treino);
    return treino;
  }

  Future<void> _persistir(
    PerfilQuestionario perfil,
    RespostasTriagem triagem,
    TreinoRecomendado treino,
  ) async {
    // RN-051: triagem (dado de saude) so e gravada com consentimento.
    final triagemJson = consentimentoSaude
        ? jsonEncode(triagem.toJson())
        : null;
    await _db.recommenderRunDao.insert(
      RecommenderRunsCompanion.insert(
        id: _uuid.v4(),
        userId: _userId,
        versaoRegras: treino.versaoRegras,
        perfilJson: jsonEncode(perfil.toJson()),
        triagemJson: Value(triagemJson),
        treinoJson: jsonEncode(treino.toJson()),
        divisao: Value(treino.divisao?.name),
        bloqueado: Value(treino.bloqueado),
        // Snapshot do consentimento: define se pode sincronizar (RN-051).
        sincronizavel: Value(consentimentoSaude),
      ),
    );
  }

  /// Cria rotina(s) a partir do treino recomendado (RF-008). Reusa a mesma
  /// API do [RoutineService] usada pelos templates. Retorna os ids criados.
  Future<List<String>> salvarComoRotina(TreinoRecomendado treino) async {
    final ids = <String>[];
    for (final dia in treino.dias) {
      final routineId = await _routines.create(
        nome: dia.nome,
        tipo: 'fixo',
        diasDaSemana: dia.diasDaSemana,
      );
      for (var i = 0; i < dia.exercicios.length; i++) {
        final ex = dia.exercicios[i];
        await _routines.addExercise(
          routineId: routineId,
          exerciseId: ex.exercicio.id,
          ordem: i,
          series: ex.series,
          notas: ex.observacao,
        );
      }
      ids.add(routineId);
    }
    return ids;
  }
}

final recommenderServiceProvider = Provider<RecommenderService>((ref) {
  return RecommenderService(
    ref.watch(appDatabaseProvider),
    ref.watch(libraryRepositoryProvider),
    ref.watch(routineServiceProvider),
    ref.watch(effectiveUserIdProvider),
    consentimentoSaude: ref.watch(healthConsentProvider),
  );
});

/// Historico de recomendacoes geradas (RNF-005 / auditoria).
final recommenderRunsProvider = StreamProvider<List<RecommenderRunRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);
  return db.recommenderRunDao.watchAll(userId);
});
