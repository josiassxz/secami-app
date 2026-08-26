import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_providers.dart';

/// Consentimento para tratar/armazenar dados de saude da triagem (RN-051).
/// Opt-in explicito. Sem consentimento, respostas de triagem nao sao gravadas
/// nem sincronizadas - so o treino gerado (nao sensivel) e mantido.
class HealthConsentNotifier extends Notifier<bool> {
  static const _key = 'reps.recomendador.consentimento_saude';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  bool build() => _prefs.getBool(_key) ?? false;

  Future<void> set(bool v) async {
    await _prefs.setBool(_key, v);
    state = v;
  }
}

final healthConsentProvider = NotifierProvider<HealthConsentNotifier, bool>(
  HealthConsentNotifier.new,
);
