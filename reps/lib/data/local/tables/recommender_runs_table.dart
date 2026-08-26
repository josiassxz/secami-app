import 'package:drift/drift.dart';

/// Registro auditavel de cada recomendacao gerada (RN-050 / CA-008 / RNF-005).
/// `triagemJson` (dado de saude) so e gravado quando ha consentimento (RN-051).
@DataClassName('RecommenderRunRow')
class RecommenderRuns extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
  TextColumn get versaoRegras => text()();
  TextColumn get perfilJson => text()();

  /// Respostas de triagem (dado sensivel). Null quando sem consentimento.
  TextColumn get triagemJson => text().nullable()();
  TextColumn get treinoJson => text()();
  TextColumn get divisao => text().nullable()();
  BoolColumn get bloqueado => boolean().withDefault(const Constant(false))();

  /// Snapshot do consentimento no momento da geracao (RN-051). Quando false,
  /// o registro NUNCA sobe para o Supabase, mesmo que o usuario ative o
  /// consentimento depois (o dado foi coletado sem permissao de sync).
  BoolColumn get sincronizavel =>
      boolean().withDefault(const Constant(false))();

  /// Se ja foi enviado ao Supabase.
  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
