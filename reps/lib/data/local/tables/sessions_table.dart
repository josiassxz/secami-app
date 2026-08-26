import 'package:drift/drift.dart';

import 'routines_table.dart';

/// Espelha public.workout_sessions.
@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get routineId => text().nullable().references(Routines, #id)();
  DateTimeColumn get iniciadoEm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finalizadoEm => dateTime().nullable()();
  IntColumn get duracaoTotalSegundos => integer().nullable()();
  TextColumn get notas => text().nullable()();
  IntColumn get sentimento => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Espelha public.set_logs.
@DataClassName('SetLogRow')
class SetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId => text()();
  IntColumn get ordemNoTreino => integer()();
  IntColumn get numeroSerie => integer()();
  IntColumn get repsRealizadas => integer().nullable()();
  RealColumn get cargaKg => real().nullable()();
  // Duracao executada da serie, para exercicios medidos por tempo (prancha,
  // isometria, farmer carry). Null em series medidas por repeticao.
  IntColumn get duracaoSegundos => integer().nullable()();
  IntColumn get rpe => integer().nullable()();
  TextColumn get tipoSerie => text().withDefault(const Constant('normal'))();
  BoolColumn get executada => boolean().withDefault(const Constant(true))();
  TextColumn get motivoPulo => text().nullable()();
  TextColumn get substituidoDeExerciseId => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Espelha public.cardio_sessions.
@DataClassName('CardioSessionRow')
class CardioSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get modalidade => text()();
  IntColumn get duracaoMinutos => integer()();
  RealColumn get distanciaKm => real().nullable()();
  IntColumn get intensidade => integer().nullable()();
  IntColumn get fcMedia => integer().nullable()();
  IntColumn get fcMax => integer().nullable()();
  IntColumn get calorias => integer().nullable()();
  TextColumn get externalSource => text().nullable()();
  TextColumn get externalId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get executadoEm =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Estado de sync por tabela (local-only, nunca vai pra Supabase).
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get tabela => text()();
  DateTimeColumn get lastPullAt => dateTime().nullable()();
  DateTimeColumn get lastPushAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tabela};
}
