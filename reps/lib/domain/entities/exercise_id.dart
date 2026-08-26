/// Parser central de id de exercício (Stage-07 5.1).
///
/// Um id de exercício tem uma de quatro formas:
/// - `seed:<slug>`  — biblioteca canônica (100 exercícios).
/// - `extdb:<slug>` — base externa (ExerciseDB), só local.
/// - `custom:<uuid>`— exercício criado pelo usuário.
/// - `<uuid>`       — id cru (exercício custom em formato antigo / do banco).
///
/// Antes a checagem `id.startsWith('seed:') ? id.substring(5) : id` estava
/// espalhada por ~13 telas. Centralizar aqui evita divergência de prefixos.
enum ExerciseIdKind { seed, extdb, custom, raw }

class ExerciseId {
  const ExerciseId._(this.raw, this.kind, this.value);

  /// Id completo, como gravado (ex.: `seed:supino-reto`).
  final String raw;
  final ExerciseIdKind kind;

  /// Parte após o prefixo (slug ou uuid). Igual a [raw] quando não há prefixo.
  final String value;

  factory ExerciseId.parse(String id) {
    if (id.startsWith('seed:')) {
      return ExerciseId._(id, ExerciseIdKind.seed, id.substring(5));
    }
    if (id.startsWith('extdb:')) {
      return ExerciseId._(id, ExerciseIdKind.extdb, id.substring(6));
    }
    if (id.startsWith('custom:')) {
      return ExerciseId._(id, ExerciseIdKind.custom, id.substring(7));
    }
    return ExerciseId._(id, ExerciseIdKind.raw, id);
  }

  bool get isSeed => kind == ExerciseIdKind.seed;
  bool get isExtdb => kind == ExerciseIdKind.extdb;
  bool get isCustom => kind == ExerciseIdKind.custom;

  /// Slug da biblioteca quando `seed:`; senão o id cru. Espelha exatamente o
  /// padrão antigo `startsWith('seed:') ? substring(5) : id` — exercícios
  /// `extdb:`/`custom:` permanecem com o prefixo (como antes).
  String get librarySlug => isSeed ? value : raw;
}
