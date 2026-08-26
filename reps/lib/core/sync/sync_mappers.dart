// Mappers JSON ⇄ Drift companions para o sync. Funções puras (sem estado do
// engine) para permitir teste de roundtrip por tabela (Stage-07 3.1). A
// tradução de exercise_id (`seed:`/`extdb:` ⇄ uuid) é injetada pelo caller via
// callbacks, pois depende do mapa carregado a cada sync.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/database.dart';

/// Parse tolerante de timestamp vindo do Supabase (String ISO, DateTime, null).
DateTime? parseTs(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) {
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      return null;
    }
  }
  if (kDebugMode) {
    // ignore: avoid_print
    print('[sync] timestamp inesperado: $raw');
  }
  return null;
}

// ===== routines =====
Map<String, dynamic> routineToJson(RoutineRow r) {
  return {
    'id': r.id,
    'user_id': r.userId,
    'nome': r.nome,
    'tipo': r.tipo,
    'dias_da_semana': jsonDecode(r.diasDaSemana),
    'ordem': r.ordem,
    'ativo': r.ativo,
    'origem': r.origem,
    'atribuido_por': r.atribuidoPor,
    'criado_em': r.criadoEm.toUtc().toIso8601String(),
    'updated_at': r.updatedAt.toUtc().toIso8601String(),
    'deleted_at': r.deletedAt?.toUtc().toIso8601String(),
    'device_id': r.deviceId,
  };
}

RoutinesCompanion routineFromJson(Map<String, dynamic> j) {
  return RoutinesCompanion(
    id: Value(j['id'] as String),
    userId: Value(j['user_id'] as String),
    nome: Value(j['nome'] as String),
    tipo: Value((j['tipo'] as String?) ?? 'fixo'),
    diasDaSemana: Value(jsonEncode(j['dias_da_semana'] ?? const <int>[])),
    ordem: Value((j['ordem'] as int?) ?? 0),
    ativo: Value((j['ativo'] as bool?) ?? true),
    origem: Value((j['origem'] as String?) ?? 'propria'),
    atribuidoPor: Value(j['atribuido_por'] as String?),
    criadoEm: Value(parseTs(j['criado_em']) ?? DateTime.now().toUtc()),
    updatedAt: Value(parseTs(j['updated_at']) ?? DateTime.now().toUtc()),
    deletedAt: Value(parseTs(j['deleted_at'])),
    deviceId: Value(j['device_id'] as String?),
    dirty: const Value(false),
  );
}

// ===== routine_exercises =====
Map<String, dynamic> routineExerciseToJson(RoutineExerciseRow re) {
  return {
    'id': re.id,
    'routine_id': re.routineId,
    'exercise_id': re.exerciseId,
    'ordem': re.ordem,
    'series_planejadas': jsonDecode(re.seriesPlanejadas),
    'notas': re.notas,
    'grupo_id': re.grupoId,
    'grupo_tipo': re.grupoTipo,
    'rounds': re.rounds,
    'criado_em': re.criadoEm.toUtc().toIso8601String(),
    'updated_at': re.updatedAt.toUtc().toIso8601String(),
    'deleted_at': re.deletedAt?.toUtc().toIso8601String(),
    'device_id': re.deviceId,
  };
}

/// [exIdFromDb] traduz o exercise_id do banco para o id local.
RoutineExercisesCompanion routineExerciseFromJson(
  Map<String, dynamic> j,
  String Function(String) exIdFromDb,
) {
  return RoutineExercisesCompanion(
    id: Value(j['id'] as String),
    routineId: Value(j['routine_id'] as String),
    exerciseId: Value(exIdFromDb(j['exercise_id'] as String)),
    ordem: Value((j['ordem'] as int?) ?? 0),
    seriesPlanejadas: Value(jsonEncode(j['series_planejadas'] ?? const [])),
    notas: Value(j['notas'] as String?),
    grupoId: Value(j['grupo_id'] as String?),
    grupoTipo: Value((j['grupo_tipo'] as String?) ?? 'normal'),
    rounds: Value(j['rounds'] as int?),
    criadoEm: Value(parseTs(j['criado_em']) ?? DateTime.now().toUtc()),
    updatedAt: Value(parseTs(j['updated_at']) ?? DateTime.now().toUtc()),
    deletedAt: Value(parseTs(j['deleted_at'])),
    deviceId: Value(j['device_id'] as String?),
    dirty: const Value(false),
  );
}

// ===== workout_sessions =====
Map<String, dynamic> sessionToJson(WorkoutSessionRow s) {
  return {
    'id': s.id,
    'user_id': s.userId,
    'routine_id': s.routineId,
    'iniciado_em': s.iniciadoEm.toUtc().toIso8601String(),
    'finalizado_em': s.finalizadoEm?.toUtc().toIso8601String(),
    'duracao_total_segundos': s.duracaoTotalSegundos,
    'notas': s.notas,
    'sentimento': s.sentimento,
    'updated_at': s.updatedAt.toUtc().toIso8601String(),
    'deleted_at': s.deletedAt?.toUtc().toIso8601String(),
    'device_id': s.deviceId,
  };
}

WorkoutSessionsCompanion sessionFromJson(Map<String, dynamic> j) {
  return WorkoutSessionsCompanion(
    id: Value(j['id'] as String),
    userId: Value(j['user_id'] as String),
    routineId: Value(j['routine_id'] as String?),
    iniciadoEm: Value(parseTs(j['iniciado_em']) ?? DateTime.now().toUtc()),
    finalizadoEm: Value(parseTs(j['finalizado_em'])),
    duracaoTotalSegundos: Value(j['duracao_total_segundos'] as int?),
    notas: Value(j['notas'] as String?),
    sentimento: Value(j['sentimento'] as int?),
    updatedAt: Value(parseTs(j['updated_at']) ?? DateTime.now().toUtc()),
    deletedAt: Value(parseTs(j['deleted_at'])),
    deviceId: Value(j['device_id'] as String?),
    dirty: const Value(false),
  );
}

// ===== set_logs =====
Map<String, dynamic> setLogToJson(SetLogRow l) {
  return {
    'id': l.id,
    'session_id': l.sessionId,
    'exercise_id': l.exerciseId,
    'ordem_no_treino': l.ordemNoTreino,
    'numero_serie': l.numeroSerie,
    'reps_realizadas': l.repsRealizadas,
    'duracao_segundos': l.duracaoSegundos,
    'carga_kg': l.cargaKg,
    'rpe': l.rpe,
    'tipo_serie': l.tipoSerie,
    'executada': l.executada,
    'motivo_pulo': l.motivoPulo,
    'substituido_de_exercise_id': l.substituidoDeExerciseId,
    'criado_em': l.criadoEm.toUtc().toIso8601String(),
    'updated_at': l.updatedAt.toUtc().toIso8601String(),
    'deleted_at': l.deletedAt?.toUtc().toIso8601String(),
    'device_id': l.deviceId,
  };
}

/// [exIdFromDb] traduz exercise_id (e o substituído) do banco para id local.
SetLogsCompanion setLogFromJson(
  Map<String, dynamic> j,
  String Function(String) exIdFromDb,
) {
  final sub = j['substituido_de_exercise_id'] as String?;
  return SetLogsCompanion(
    id: Value(j['id'] as String),
    sessionId: Value(j['session_id'] as String),
    exerciseId: Value(exIdFromDb(j['exercise_id'] as String)),
    ordemNoTreino: Value(j['ordem_no_treino'] as int),
    numeroSerie: Value(j['numero_serie'] as int),
    repsRealizadas: Value(j['reps_realizadas'] as int?),
    duracaoSegundos: Value(j['duracao_segundos'] as int?),
    cargaKg: Value((j['carga_kg'] as num?)?.toDouble()),
    rpe: Value(j['rpe'] as int?),
    tipoSerie: Value((j['tipo_serie'] as String?) ?? 'normal'),
    executada: Value((j['executada'] as bool?) ?? true),
    motivoPulo: Value(j['motivo_pulo'] as String?),
    substituidoDeExerciseId: Value(sub == null ? null : exIdFromDb(sub)),
    criadoEm: Value(parseTs(j['criado_em']) ?? DateTime.now().toUtc()),
    updatedAt: Value(parseTs(j['updated_at']) ?? DateTime.now().toUtc()),
    deletedAt: Value(parseTs(j['deleted_at'])),
    deviceId: Value(j['device_id'] as String?),
    dirty: const Value(false),
  );
}

// ===== cardio_sessions =====
Map<String, dynamic> cardioToJson(CardioSessionRow c) {
  return {
    'id': c.id,
    'user_id': c.userId,
    'modalidade': c.modalidade,
    'duracao_minutos': c.duracaoMinutos,
    'distancia_km': c.distanciaKm,
    'intensidade': c.intensidade,
    'fc_media': c.fcMedia,
    'fc_max': c.fcMax,
    'calorias': c.calorias,
    'external_source': c.externalSource,
    'external_id': c.externalId,
    'synced_at': c.syncedAt?.toUtc().toIso8601String(),
    'executado_em': c.executadoEm.toUtc().toIso8601String(),
    'updated_at': c.updatedAt.toUtc().toIso8601String(),
    'deleted_at': c.deletedAt?.toUtc().toIso8601String(),
    'device_id': c.deviceId,
  };
}

CardioSessionsCompanion cardioFromJson(Map<String, dynamic> j) {
  return CardioSessionsCompanion(
    id: Value(j['id'] as String),
    userId: Value(j['user_id'] as String),
    modalidade: Value(j['modalidade'] as String),
    duracaoMinutos: Value(j['duracao_minutos'] as int),
    distanciaKm: Value((j['distancia_km'] as num?)?.toDouble()),
    intensidade: Value(j['intensidade'] as int?),
    fcMedia: Value(j['fc_media'] as int?),
    fcMax: Value(j['fc_max'] as int?),
    calorias: Value(j['calorias'] as int?),
    externalSource: Value(j['external_source'] as String?),
    externalId: Value(j['external_id'] as String?),
    syncedAt: Value(parseTs(j['synced_at'])),
    executadoEm: Value(parseTs(j['executado_em']) ?? DateTime.now().toUtc()),
    updatedAt: Value(parseTs(j['updated_at']) ?? DateTime.now().toUtc()),
    deletedAt: Value(parseTs(j['deleted_at'])),
    deviceId: Value(j['device_id'] as String?),
    dirty: const Value(false),
  );
}

// ===== recommender_runs (push-only) =====
Map<String, dynamic> recommenderRunToJson(RecommenderRunRow r) {
  return {
    'id': r.id,
    'user_id': r.userId,
    'versao_regras': r.versaoRegras,
    // colunas jsonb: enviar objeto, nao string.
    'perfil_json': jsonDecode(r.perfilJson),
    'triagem_json': r.triagemJson == null ? null : jsonDecode(r.triagemJson!),
    'treino_json': jsonDecode(r.treinoJson),
    'divisao': r.divisao,
    'bloqueado': r.bloqueado,
    'criado_em': r.criadoEm.toUtc().toIso8601String(),
  };
}
