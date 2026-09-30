import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class LoggedExercise {
  const LoggedExercise({required this.exerciseName, this.load});
  final String exerciseName;
  final String? load;

  Map<String, dynamic> toJson() => {'exerciseName': exerciseName, 'load': load};
}

/// Execução diária da ficha (SPEC §9.3 / §10.4). Espelha o WorkoutLog do
/// backend (professor prescreve a ficha; aluno marca o que fez no dia).
class WorkoutLogApi {
  WorkoutLogApi(this._api);
  final ApiClient _api;

  Future<void> saveToday({
    required String? workoutPlanId,
    required String sheetLabel,
    required List<LoggedExercise> exercises,
  }) {
    final today = DateTime.now();
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _api.put(
      '/me/workout-logs',
      body: {
        'date': date,
        'workoutPlanId': workoutPlanId,
        'sheetLabel': sheetLabel,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      },
    );
  }
}

final workoutLogApiProvider = Provider<WorkoutLogApi>(
  (ref) => WorkoutLogApi(ref.watch(apiClientProvider)),
);
