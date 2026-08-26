import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../logging/observability.dart';

/// Exporta sessoes de treino para Health Connect (Android) / Apple Health (iOS).
///
/// Web nao e suportado — todos os metodos viram no-op via [kIsWeb], mesmo
/// padrao de `notification_service.dart`. Gymrats e afins importam dessas
/// plataformas, entao basta escrever um registro `WORKOUT` ao finalizar.
class HealthService {
  HealthService();

  final Health _health = Health();
  bool _configured = false;
  bool _authorized = false;

  static const _types = [HealthDataType.WORKOUT];
  static const _access = [HealthDataAccess.WRITE];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Pede permissao de escrita. Retorna true se autorizado.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      await _ensureConfigured();
      _authorized = await _health.requestAuthorization(
        _types,
        permissions: _access,
      );
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'health_request_perms');
      _authorized = false;
    }
    return _authorized;
  }

  /// Escreve uma sessao de musculacao na plataforma de saude.
  /// Nao lanca: erro e logado (exportar nao pode quebrar o fim do treino).
  /// Nao depende de hasPermissions (que retorna null pra WRITE no Health
  /// Connect) — tenta escrever direto; se faltar permissao, o write lanca.
  Future<void> exportWorkout({
    required DateTime inicio,
    required DateTime fim,
    String? titulo,
  }) async {
    final err = await _write(inicio: inicio, fim: fim, titulo: titulo);
    if (err != null) {
      await Observability.captureError(
        err,
        StackTrace.current,
        hint: 'health_export',
      );
    }
  }

  /// Escreve um treino de teste (ultimos 30 min) AGORA.
  /// Retorna null em sucesso, ou a mensagem de erro pra exibir ao usuario.
  Future<String?> testExport() async {
    if (kIsWeb) return 'Não suportado na web.';
    final granted = await requestPermissions();
    if (!granted) {
      return 'Permissão de Exercício não concedida no Health Connect. '
          'Abra o Health Connect e libere a gravação de Exercício para o reps.';
    }
    final now = DateTime.now();
    final err = await _write(
      inicio: now.subtract(const Duration(minutes: 30)),
      fim: now,
      titulo: 'Treino de teste (reps)',
    );
    return err;
  }

  /// Faz a escrita. Retorna null em sucesso ou a mensagem de erro.
  /// [titulo] vira o nome da atividade no Health Connect (ExerciseSessionRecord
  /// .title) — e o que apps como o Gymrats exibem.
  Future<String?> _write({
    required DateTime inicio,
    required DateTime fim,
    String? titulo,
  }) async {
    if (kIsWeb) return 'Não suportado na web.';
    try {
      await _ensureConfigured();
      final ok = await _health.writeWorkoutData(
        // STRENGTH_TRAINING e suportado no Health Connect (Android).
        // TRADITIONAL_STRENGTH_TRAINING so existe no iOS/HealthKit.
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: inicio,
        end: fim,
        title: (titulo != null && titulo.trim().isNotEmpty)
            ? titulo.trim()
            : 'Treino de força',
      );
      return ok
          ? null
          : 'Health Connect recusou a gravação (writeWorkoutData '
                'retornou false). Verifique a permissão de Exercício.';
    } catch (e) {
      return e.toString();
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});
