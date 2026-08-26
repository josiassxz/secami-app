/// Unidade de peso exibida ao usuario.
///
/// O armazenamento canonico e sempre kg (coluna `carga_kg`). A conversao
/// para lb acontece apenas na borda de apresentacao/entrada.
enum WeightUnit {
  kg,
  lb;

  static const double _lbPerKg = 2.2046226218;

  String get suffix => this == WeightUnit.kg ? 'kg' : 'lb';

  /// Converte um valor canonico (kg) para a unidade de exibicao.
  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * _lbPerKg;

  /// Converte um valor digitado (nesta unidade) de volta para kg canonico.
  double toKg(double value) => this == WeightUnit.kg ? value : value / _lbPerKg;

  /// Incremento natural de step do input nesta unidade.
  double get step => this == WeightUnit.kg ? 2.5 : 5;

  /// Formata um valor canonico (kg) para texto na unidade de exibicao,
  /// sem sufixo. Usa no maximo 1 casa decimal.
  String format(double kg) {
    final v = fromKg(kg);
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  static WeightUnit fromString(String? raw) =>
      raw == 'lb' ? WeightUnit.lb : WeightUnit.kg;
}
