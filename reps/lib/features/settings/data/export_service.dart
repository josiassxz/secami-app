import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_providers.dart';

enum ExportFormat { csv, json }

class ExportService {
  ExportService(this._db, this._userId);

  final AppDatabase _db;
  final String _userId;

  Future<int> share(ExportFormat fmt) async {
    final sessions = await _db.sessionDao.watchByUser(_userId).first;
    final cardio = await _db.cardioDao.watchByUser(_userId).first;

    final tmp = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final File file;
    if (fmt == ExportFormat.csv) {
      file = File('${tmp.path}/reps-export-$stamp.csv');
      await file.writeAsString(await _buildCsv(sessions, cardio));
    } else {
      file = File('${tmp.path}/reps-export-$stamp.json');
      await file.writeAsString(await _buildJson(sessions, cardio));
    }

    final params = ShareParams(
      files: [XFile(file.path)],
      subject: 'reps - exportacao de treinos',
    );
    await SharePlus.instance.share(params);
    return sessions.length + cardio.length;
  }

  Future<String> _buildCsv(
    List<WorkoutSessionRow> sessions,
    List<CardioSessionRow> cardio,
  ) async {
    final rows = <List<dynamic>>[
      [
        'tipo',
        'session_id',
        'iniciado_em',
        'finalizado_em',
        'exercise_id',
        'ordem_no_treino',
        'numero_serie',
        'reps',
        'carga_kg',
        'rpe',
        'tipo_serie',
        'executada',
        'motivo_pulo',
        'modalidade_cardio',
        'duracao_min',
        'distancia_km',
        'intensidade',
        'fc_media',
        'fc_max',
        'calorias',
        'duracao_segundos',
      ],
    ];
    for (final s in sessions) {
      final logs = await _db.setLogDao.ofSession(s.id);
      for (final l in logs) {
        rows.add([
          'musculacao',
          s.id,
          s.iniciadoEm.toIso8601String(),
          s.finalizadoEm?.toIso8601String() ?? '',
          l.exerciseId,
          l.ordemNoTreino,
          l.numeroSerie,
          l.repsRealizadas ?? '',
          l.cargaKg ?? '',
          l.rpe ?? '',
          l.tipoSerie,
          l.executada,
          l.motivoPulo ?? '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          l.duracaoSegundos ?? '',
        ]);
      }
    }
    for (final c in cardio) {
      rows.add([
        'cardio',
        c.id,
        c.executadoEm.toIso8601String(),
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        c.modalidade,
        c.duracaoMinutos,
        c.distanciaKm ?? '',
        c.intensidade ?? '',
        c.fcMedia ?? '',
        c.fcMax ?? '',
        c.calorias ?? '',
        '',
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _buildJson(
    List<WorkoutSessionRow> sessions,
    List<CardioSessionRow> cardio,
  ) async {
    final sessoesJson = <Map<String, dynamic>>[];
    for (final s in sessions) {
      final logs = await _db.setLogDao.ofSession(s.id);
      sessoesJson.add({
        'id': s.id,
        'iniciado_em': s.iniciadoEm.toIso8601String(),
        'finalizado_em': s.finalizadoEm?.toIso8601String(),
        'duracao_total_segundos': s.duracaoTotalSegundos,
        'set_logs': [
          for (final l in logs)
            {
              'id': l.id,
              'exercise_id': l.exerciseId,
              'ordem_no_treino': l.ordemNoTreino,
              'numero_serie': l.numeroSerie,
              'reps_realizadas': l.repsRealizadas,
              'duracao_segundos': l.duracaoSegundos,
              'carga_kg': l.cargaKg,
              'rpe': l.rpe,
              'tipo_serie': l.tipoSerie,
              'executada': l.executada,
              'motivo_pulo': l.motivoPulo,
              'substituido_de': l.substituidoDeExerciseId,
            },
        ],
      });
    }
    final payload = {
      'export_version': 1,
      'gerado_em': DateTime.now().toUtc().toIso8601String(),
      'sessoes_musculacao': sessoesJson,
      'sessoes_cardio': [
        for (final c in cardio)
          {
            'id': c.id,
            'modalidade': c.modalidade,
            'duracao_minutos': c.duracaoMinutos,
            'distancia_km': c.distanciaKm,
            'intensidade': c.intensidade,
            'fc_media': c.fcMedia,
            'fc_max': c.fcMax,
            'calorias': c.calorias,
            'executado_em': c.executadoEm.toIso8601String(),
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(appDatabaseProvider),
    ref.watch(effectiveUserIdProvider),
  );
});
