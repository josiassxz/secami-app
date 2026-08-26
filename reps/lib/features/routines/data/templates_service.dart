import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/planned_set.dart';
import 'routine_providers.dart';

class TemplateExercise {
  TemplateExercise({
    required this.slug,
    required this.series,
    required this.repsMin,
    required this.repsMax,
    required this.descansoSegundos,
  });

  final String slug;
  final int series;
  final int repsMin;
  final int repsMax;
  final int descansoSegundos;
}

class TemplateRoutine {
  TemplateRoutine({
    required this.nome,
    required this.diasDaSemana,
    required this.exercicios,
  });

  final String nome;
  final List<int> diasDaSemana;
  final List<TemplateExercise> exercicios;
}

class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.rotinas,
  });

  final String id;
  final String nome;
  final String descricao;
  final List<TemplateRoutine> rotinas;
}

class TemplatesService {
  TemplatesService(this._routines);

  final RoutineService _routines;

  Future<List<WorkoutTemplate>> load() async {
    final raw = await rootBundle.loadString('assets/templates/templates.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((j) => _parseTemplate(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  WorkoutTemplate _parseTemplate(Map<String, dynamic> j) {
    final rotinas = (j['rotinas'] as List<dynamic>)
        .map((r) => _parseRoutine(r as Map<String, dynamic>))
        .toList();
    return WorkoutTemplate(
      id: j['id'] as String,
      nome: j['nome'] as String,
      descricao: (j['descricao'] as String?) ?? '',
      rotinas: rotinas,
    );
  }

  TemplateRoutine _parseRoutine(Map<String, dynamic> j) {
    return TemplateRoutine(
      nome: j['nome'] as String,
      diasDaSemana: (j['dias_da_semana'] as List<dynamic>).cast<int>(),
      exercicios: (j['exercicios'] as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        return TemplateExercise(
          slug: m['slug'] as String,
          series: (m['series'] as int?) ?? 3,
          repsMin: (m['reps_min'] as int?) ?? 8,
          repsMax: (m['reps_max'] as int?) ?? 12,
          descansoSegundos: (m['descanso_segundos'] as int?) ?? 90,
        );
      }).toList(),
    );
  }

  /// Aplica um template criando todas as rotinas no banco.
  Future<void> apply(WorkoutTemplate template) async {
    for (final r in template.rotinas) {
      final routineId = await _routines.create(
        nome: r.nome,
        tipo: 'fixo',
        diasDaSemana: r.diasDaSemana,
      );
      for (var i = 0; i < r.exercicios.length; i++) {
        final te = r.exercicios[i];
        final series = List.generate(
          te.series,
          (idx) => PlannedSet(
            numero: idx + 1,
            repsAlvoMin: te.repsMin,
            repsAlvoMax: te.repsMax,
            descansoSegundos: te.descansoSegundos,
          ),
        );
        await _routines.addExercise(
          routineId: routineId,
          exerciseId: 'seed:${te.slug}',
          ordem: i,
          series: series,
        );
      }
    }
  }
}

final templatesServiceProvider = Provider<TemplatesService>((ref) {
  return TemplatesService(ref.watch(routineServiceProvider));
});
