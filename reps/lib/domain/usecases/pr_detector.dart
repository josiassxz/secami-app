import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../data/local/database.dart';

enum PrTipo { cargaMax, volume, repsNaCarga, duracaoMax }

extension PrTipoX on PrTipo {
  String get label {
    switch (this) {
      case PrTipo.cargaMax:
        return 'Carga maxima';
      case PrTipo.volume:
        return 'Volume da serie';
      case PrTipo.repsNaCarga:
        return 'Reps na carga atual';
      case PrTipo.duracaoMax:
        return 'Maior duracao';
    }
  }
}

class PrEvent {
  const PrEvent({
    required this.exerciseId,
    required this.tipo,
    required this.valor,
    required this.detectadoEm,
  });

  final String exerciseId;
  final PrTipo tipo;
  final double valor;
  final DateTime detectadoEm;
}

class PrDetector {
  PrDetector(this._db);

  final AppDatabase _db;

  /// Verifica se a serie recem-registrada eh um PR comparado ao historico.
  /// Considera apenas series executadas anteriores a esta.
  Future<List<PrEvent>> detect({
    required String exerciseId,
    required int reps,
    required double cargaKg,
    required String currentSetLogId,
  }) async {
    final all = await _db.setLogDao.ofExercise(exerciseId, limit: 1000);
    final anteriores = all
        .where((l) => l.id != currentSetLogId && l.executada)
        .toList(growable: false);
    if (anteriores.isEmpty) {
      // Primeira serie do exercicio - ja eh PR de carga max, mas so quando ha
      // carga (evita banner "Carga maxima 0kg" em series de peso corporal).
      if (cargaKg > 0) {
        return [
          PrEvent(
            exerciseId: exerciseId,
            tipo: PrTipo.cargaMax,
            valor: cargaKg,
            detectadoEm: DateTime.now().toUtc(),
          ),
        ];
      }
      return const [];
    }
    final out = <PrEvent>[];

    final maxCargaHist = anteriores
        .map((l) => l.cargaKg ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (cargaKg > maxCargaHist) {
      out.add(
        PrEvent(
          exerciseId: exerciseId,
          tipo: PrTipo.cargaMax,
          valor: cargaKg,
          detectadoEm: DateTime.now().toUtc(),
        ),
      );
    }

    final maxVolumeHist = anteriores
        .map((l) => (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0))
        .fold<double>(0, (a, b) => a > b ? a : b);
    final volume = cargaKg * reps;
    if (volume > maxVolumeHist && reps > 0 && cargaKg > 0) {
      out.add(
        PrEvent(
          exerciseId: exerciseId,
          tipo: PrTipo.volume,
          valor: volume,
          detectadoEm: DateTime.now().toUtc(),
        ),
      );
    }

    final repsNaMesma = anteriores
        .where((l) => (l.cargaKg ?? 0) == cargaKg)
        .map((l) => l.repsRealizadas ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (cargaKg > 0 && reps > repsNaMesma) {
      out.add(
        PrEvent(
          exerciseId: exerciseId,
          tipo: PrTipo.repsNaCarga,
          valor: reps.toDouble(),
          detectadoEm: DateTime.now().toUtc(),
        ),
      );
    }

    return out;
  }

  /// PR para series medidas por tempo (E6): maior duracao executada e — quando
  /// ha carga (prancha/farmer com peso) — carga maxima. Series por tempo nao
  /// geram PR de reps/volume.
  Future<List<PrEvent>> detectTimed({
    required String exerciseId,
    required int duracaoSegundos,
    required double cargaKg,
    required String currentSetLogId,
  }) async {
    final all = await _db.setLogDao.ofExercise(exerciseId, limit: 1000);
    final anteriores = all
        .where((l) => l.id != currentSetLogId && l.executada)
        .toList(growable: false);
    final agora = DateTime.now().toUtc();
    if (anteriores.isEmpty) {
      return [
        PrEvent(
          exerciseId: exerciseId,
          tipo: PrTipo.duracaoMax,
          valor: duracaoSegundos.toDouble(),
          detectadoEm: agora,
        ),
      ];
    }
    final out = <PrEvent>[];

    final maxDurHist = anteriores
        .map((l) => l.duracaoSegundos ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (duracaoSegundos > maxDurHist) {
      out.add(
        PrEvent(
          exerciseId: exerciseId,
          tipo: PrTipo.duracaoMax,
          valor: duracaoSegundos.toDouble(),
          detectadoEm: agora,
        ),
      );
    }

    if (cargaKg > 0) {
      final maxCargaHist = anteriores
          .map((l) => l.cargaKg ?? 0)
          .fold<double>(0, (a, b) => a > b ? a : b);
      if (cargaKg > maxCargaHist) {
        out.add(
          PrEvent(
            exerciseId: exerciseId,
            tipo: PrTipo.cargaMax,
            valor: cargaKg,
            detectadoEm: agora,
          ),
        );
      }
    }

    return out;
  }
}

final prDetectorProvider = Provider<PrDetector>((ref) {
  return PrDetector(ref.watch(appDatabaseProvider));
});
