import 'dart:convert';

import 'package:flutter/foundation.dart';

// Nomes em snake_case espelham o enum do Postgres (tipo_serie).
// ignore_for_file: constant_identifier_names
enum TipoSerie { normal, drop_set, superset, rest_pause }

extension TipoSerieX on TipoSerie {
  String get label {
    switch (this) {
      case TipoSerie.normal:
        return 'Normal';
      case TipoSerie.drop_set:
        return 'Drop set';
      case TipoSerie.superset:
        return 'Superset';
      case TipoSerie.rest_pause:
        return 'Rest-pause';
    }
  }

  /// Explicacao individual da tecnica (pt-BR) — usada no seletor e no (?) de
  /// ajuda da tela de recomendacao.
  String get descricao {
    switch (this) {
      case TipoSerie.normal:
        return 'Serie tradicional: as repeticoes previstas com a mesma carga '
            'e descanso completo entre as series.';
      case TipoSerie.drop_set:
        return 'Ao chegar na falha, reduza a carga (~20 a 30%) e continue sem '
            'descanso ate falhar de novo. Aumenta o estimulo metabolico.';
      case TipoSerie.superset:
        return 'Dois exercicios em sequencia, sem descanso entre eles (em '
            'geral de grupos opostos). Economiza tempo e eleva a intensidade.';
      case TipoSerie.rest_pause:
        return 'Leve a serie ate perto da falha, descanse 10 a 20s e faca mais '
            'algumas repeticoes com a mesma carga. Mais volume em menos tempo.';
    }
  }

  static TipoSerie fromString(String? raw) {
    for (final v in TipoSerie.values) {
      if (v.name == raw) return v;
    }
    return TipoSerie.normal;
  }
}

@immutable
class PlannedSet {
  const PlannedSet({
    required this.numero,
    this.repsAlvoMin = 8,
    this.repsAlvoMax = 12,
    this.cargaAlvo,
    this.descansoSegundos = 90,
    this.tipoSerie = TipoSerie.normal,
    this.aquecimento = false,
    this.duracaoAlvoSegundos,
  });

  final int numero;
  final int repsAlvoMin;
  final int repsAlvoMax;
  final double? cargaAlvo;
  final int descansoSegundos;
  final TipoSerie tipoSerie;
  final bool aquecimento;

  /// Alvo de duracao (segundos) para series medidas por tempo. Null = serie
  /// medida por repeticao. Override por serie do `Exercise.medidaPorTempo`.
  final int? duracaoAlvoSegundos;

  /// Serie medida por tempo quando tem alvo de duracao definido.
  bool get porTempo => duracaoAlvoSegundos != null;

  PlannedSet copyWith({
    int? numero,
    int? repsAlvoMin,
    int? repsAlvoMax,
    double? cargaAlvo,
    bool clearCargaAlvo = false,
    int? descansoSegundos,
    TipoSerie? tipoSerie,
    bool? aquecimento,
    int? duracaoAlvoSegundos,
    bool clearDuracaoAlvo = false,
  }) {
    return PlannedSet(
      numero: numero ?? this.numero,
      repsAlvoMin: repsAlvoMin ?? this.repsAlvoMin,
      repsAlvoMax: repsAlvoMax ?? this.repsAlvoMax,
      cargaAlvo: clearCargaAlvo ? null : (cargaAlvo ?? this.cargaAlvo),
      descansoSegundos: descansoSegundos ?? this.descansoSegundos,
      tipoSerie: tipoSerie ?? this.tipoSerie,
      aquecimento: aquecimento ?? this.aquecimento,
      duracaoAlvoSegundos: clearDuracaoAlvo
          ? null
          : (duracaoAlvoSegundos ?? this.duracaoAlvoSegundos),
    );
  }

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'reps_alvo_min': repsAlvoMin,
    'reps_alvo_max': repsAlvoMax,
    'carga_alvo': cargaAlvo,
    'descanso_segundos': descansoSegundos,
    'tipo_serie': tipoSerie.name,
    'aquecimento': aquecimento,
    'duracao_alvo_segundos': duracaoAlvoSegundos,
  };

  static PlannedSet fromJson(Map<String, dynamic> j) {
    return PlannedSet(
      numero: (j['numero'] as int?) ?? 1,
      repsAlvoMin: (j['reps_alvo_min'] as int?) ?? 8,
      repsAlvoMax: (j['reps_alvo_max'] as int?) ?? 12,
      cargaAlvo: (j['carga_alvo'] as num?)?.toDouble(),
      descansoSegundos: (j['descanso_segundos'] as int?) ?? 90,
      tipoSerie: TipoSerieX.fromString(j['tipo_serie'] as String?),
      aquecimento: (j['aquecimento'] as bool?) ?? false,
      duracaoAlvoSegundos: (j['duracao_alvo_segundos'] as int?),
    );
  }

  static String encode(List<PlannedSet> sets) =>
      jsonEncode(sets.map((s) => s.toJson()).toList());

  static List<PlannedSet> decode(String raw) {
    if (raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PlannedSet.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
