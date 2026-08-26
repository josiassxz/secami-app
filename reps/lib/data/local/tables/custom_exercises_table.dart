import 'package:drift/drift.dart';

@DataClassName('CustomExerciseRow')
class CustomExercises extends Table {
  TextColumn get id => text()();
  TextColumn get nome => text()();
  TextColumn get descricao => text().withDefault(const Constant(''))();
  TextColumn get grupoPrimario => text()();
  TextColumn get padraoMovimento => text()();
  TextColumn get equipamento => text()();
  BoolColumn get arquivado => boolean().withDefault(const Constant(false))();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
