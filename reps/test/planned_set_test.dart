import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/entities/planned_set.dart';

void main() {
  group('PlannedSet', () {
    test('toJson/fromJson roundtrip', () {
      const s = PlannedSet(
        numero: 2,
        repsAlvoMin: 6,
        repsAlvoMax: 10,
        cargaAlvo: 42.5,
        descansoSegundos: 120,
        tipoSerie: TipoSerie.drop_set,
        aquecimento: true,
        duracaoAlvoSegundos: 45,
      );
      final json = s.toJson();
      final back = PlannedSet.fromJson(json);
      expect(back.numero, s.numero);
      expect(back.repsAlvoMin, s.repsAlvoMin);
      expect(back.repsAlvoMax, s.repsAlvoMax);
      expect(back.cargaAlvo, s.cargaAlvo);
      expect(back.descansoSegundos, s.descansoSegundos);
      expect(back.tipoSerie, s.tipoSerie);
      expect(back.aquecimento, s.aquecimento);
      expect(back.duracaoAlvoSegundos, s.duracaoAlvoSegundos);
      expect(back.porTempo, isTrue);
    });

    test('retrocompat: json sem duracao_alvo_segundos -> null', () {
      // Rotinas antigas nao tem o campo; deve desserializar para null.
      final back = PlannedSet.fromJson(const {
        'numero': 1,
        'reps_alvo_min': 8,
        'reps_alvo_max': 12,
      });
      expect(back.duracaoAlvoSegundos, isNull);
      expect(back.porTempo, isFalse);
    });

    test('clearDuracaoAlvo remove o alvo de tempo', () {
      const s = PlannedSet(numero: 1, duracaoAlvoSegundos: 60);
      final back = s.copyWith(clearDuracaoAlvo: true);
      expect(back.duracaoAlvoSegundos, isNull);
      expect(back.porTempo, isFalse);
    });

    test('encode/decode lista', () {
      final list = [
        const PlannedSet(numero: 1),
        const PlannedSet(numero: 2, cargaAlvo: 50.0),
        const PlannedSet(numero: 3, tipoSerie: TipoSerie.rest_pause),
      ];
      final encoded = PlannedSet.encode(list);
      final back = PlannedSet.decode(encoded);
      expect(back.length, 3);
      expect(back[1].cargaAlvo, 50.0);
      expect(back[2].tipoSerie, TipoSerie.rest_pause);
    });

    test('decode string vazia retorna lista vazia', () {
      expect(PlannedSet.decode(''), isEmpty);
    });

    test('clearCargaAlvo remove a carga', () {
      const s = PlannedSet(numero: 1, cargaAlvo: 60.0);
      final back = s.copyWith(clearCargaAlvo: true);
      expect(back.cargaAlvo, isNull);
    });
  });
}
