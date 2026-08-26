import 'package:drift/drift.dart';

/// Espelha public.routines do Postgres.
@DataClassName('RoutineRow')
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get nome => text()();
  TextColumn get tipo => text().withDefault(const Constant('fixo'))();
  TextColumn get diasDaSemana =>
      text().withDefault(const Constant('[]'))(); // JSON int[]
  IntColumn get ordem => integer().withDefault(const Constant(0))();
  BoolColumn get ativo => boolean().withDefault(const Constant(true))();
  // Stage 4: rotina atribuida por um treinador. 'propria' | 'atribuida'.
  TextColumn get origem => text().withDefault(const Constant('propria'))();
  // user_id do professor que atribuiu (null quando origem='propria').
  TextColumn get atribuidoPor => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Espelha public.routine_exercises.
@DataClassName('RoutineExerciseRow')
class RoutineExercises extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().references(Routines, #id)();
  TextColumn get exerciseId => text()();
  IntColumn get ordem => integer().withDefault(const Constant(0))();
  TextColumn get seriesPlanejadas =>
      text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get notas => text().nullable()();
  // Stage 6 / Feature A: agrupamento bi-set/circuito. Exercicios com o mesmo
  // grupoId formam um bloco intercalado. grupoTipo: 'normal'|'bi_set'|'circuito'.
  TextColumn get grupoId => text().nullable()();
  TextColumn get grupoTipo => text().withDefault(const Constant('normal'))();
  IntColumn get rounds => integer().nullable()(); // rodadas do circuito
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
