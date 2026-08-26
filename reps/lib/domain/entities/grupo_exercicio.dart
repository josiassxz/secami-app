// Nomes em snake_case espelham o enum/texto do Postgres (grupo_tipo).
// ignore_for_file: constant_identifier_names

/// Tipo de agrupamento de exercicios numa rotina (Stage 6 / Feature A).
///
/// - [normal]: exercicio solo, executado serie a serie (comportamento padrao).
/// - [bi_set]: 2+ exercicios encadeados sem descanso entre eles; descanso so
///   ao fechar a rodada. Nº de rodadas = nº de series do grupo.
/// - [circuito]: 2+ exercicios encadeados por N rodadas (`rounds`).
enum GrupoTipo {
  normal,
  bi_set,
  circuito;

  String get label {
    switch (this) {
      case GrupoTipo.normal:
        return 'Normal';
      case GrupoTipo.bi_set:
        return 'Bi-set';
      case GrupoTipo.circuito:
        return 'Circuito';
    }
  }

  /// Agrupa de forma intercalada (uma rodada por vez), em vez de serie a serie.
  bool get intercalado =>
      this == GrupoTipo.bi_set || this == GrupoTipo.circuito;

  static GrupoTipo fromString(String? raw) {
    for (final v in GrupoTipo.values) {
      if (v.name == raw) return v;
    }
    return GrupoTipo.normal;
  }
}
