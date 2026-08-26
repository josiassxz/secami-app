import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/health/health_service.dart';
import '../../../core/units/weight_unit.dart';
import '../../auth/data/auth_providers.dart';

class TimerSettings {
  const TimerSettings({
    this.vibracao = true,
    this.bipe = true,
    this.alertaInicio = true,
    this.som = 'freesound_community-alert-sound-87478',
  });

  final bool vibracao;
  final bool bipe;
  final bool alertaInicio;
  final String som;

  TimerSettings copyWith({
    bool? vibracao,
    bool? bipe,
    bool? alertaInicio,
    String? som,
  }) {
    return TimerSettings(
      vibracao: vibracao ?? this.vibracao,
      bipe: bipe ?? this.bipe,
      alertaInicio: alertaInicio ?? this.alertaInicio,
      som: som ?? this.som,
    );
  }
}

class TimerSettingsController extends Notifier<TimerSettings> {
  static const _kVibrar = 'reps.timer.vibracao';
  static const _kBipe = 'reps.timer.bipe';
  static const _kAlertaInicio = 'reps.timer.alerta_inicio';
  static const _kSom = 'reps.timer.som';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  static const _defaultSom = 'freesound_community-alert-sound-87478';

  @override
  TimerSettings build() {
    var som = _prefs.getString(_kSom) ?? _defaultSom;
    // Migra valor antigo que não corresponde a nenhum arquivo.
    if (som == 'beep') som = _defaultSom;
    return TimerSettings(
      vibracao: _prefs.getBool(_kVibrar) ?? true,
      bipe: _prefs.getBool(_kBipe) ?? true,
      alertaInicio: _prefs.getBool(_kAlertaInicio) ?? true,
      som: som,
    );
  }

  Future<void> setVibracao(bool v) async {
    await _prefs.setBool(_kVibrar, v);
    state = state.copyWith(vibracao: v);
  }

  Future<void> setBipe(bool v) async {
    await _prefs.setBool(_kBipe, v);
    state = state.copyWith(bipe: v);
  }

  Future<void> setAlertaInicio(bool v) async {
    await _prefs.setBool(_kAlertaInicio, v);
    state = state.copyWith(alertaInicio: v);
  }

  Future<void> setSom(String s) async {
    await _prefs.setString(_kSom, s);
    state = state.copyWith(som: s);
  }
}

final timerSettingsProvider =
    NotifierProvider<TimerSettingsController, TimerSettings>(
      TimerSettingsController.new,
    );

/// Unidade de peso preferida do usuario (kg por padrao).
class WeightUnitController extends Notifier<WeightUnit> {
  static const _kUnidade = 'reps.peso.unidade';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  WeightUnit build() => WeightUnit.fromString(_prefs.getString(_kUnidade));

  Future<void> set(WeightUnit u) async {
    await _prefs.setString(_kUnidade, u.name);
    state = u;
  }
}

final weightUnitProvider = NotifierProvider<WeightUnitController, WeightUnit>(
  WeightUnitController.new,
);

/// Exportacao automatica de treinos para Health Connect / Apple Health.
/// Desligado por padrao (opt-in). Web nunca habilita.
class HealthIntegrationNotifier extends Notifier<bool> {
  static const _key = 'reps.health.ativo';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  bool build() => _prefs.getBool(_key) ?? false;

  Future<void> toggle(bool v) async {
    var ativo = v;
    if (v) {
      ativo = await ref.read(healthServiceProvider).requestPermissions();
    }
    await _prefs.setBool(_key, ativo);
    state = ativo;
  }
}

final healthIntegrationProvider =
    NotifierProvider<HealthIntegrationNotifier, bool>(
      HealthIntegrationNotifier.new,
    );
