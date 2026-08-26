import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/network/api_client.dart';
import 'rest_auth_service.dart';

/// Fluxo legado por e-mail/senha (Supabase). Sem uso quando `Env.hasRestApi`
/// — nesse modo o login e via LDAP (ver [RestAuthService]/[SignInScreen]) e
/// as acoes de conta abaixo sao redirecionadas ou reportadas como
/// indisponiveis (contas SECAMI sao provisionadas/gerenciadas pelo AD, nao
/// por um fluxo de auto-servico por e-mail).
class AuthService {
  AuthService(this._client, this._api);

  final SupabaseClient? _client;
  final ApiClient _api;

  static String get _authCallbackUrl => Env.authRedirectUrl;

  bool get isOnline => Env.hasRestApi ? true : _client != null;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? nome,
  }) async {
    if (Env.hasRestApi) {
      throw StateError(
        'Cadastro por e-mail nao disponivel. Contas SECAMI sao provisionadas '
        'automaticamente no primeiro login com usuario de rede (AD).',
      );
    }
    final client = _requireClient();
    return client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _authCallbackUrl,
      data: {'nome': ?nome},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (Env.hasRestApi) {
      throw StateError('Use o login por usuario de rede (LDAP).');
    }
    final client = _requireClient();
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    if (Env.hasRestApi) {
      throw StateError(
        'Redefinicao de senha e feita pelo Active Directory do Governo de '
        'Goias, nao pelo app.',
      );
    }
    final client = _requireClient();
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: _authCallbackUrl,
    );
  }

  Future<void> signOut() async {
    if (Env.hasRestApi) {
      await _api.clearTokens();
      return;
    }
    final client = _client;
    if (client == null) {
      return;
    }
    await client.auth.signOut();
  }

  /// Marca a conta para exclusao em 30 dias (LGPD).
  /// Real cleanup roda em edge function agendada (out of scope no MVP).
  Future<void> requestAccountDeletion() async {
    if (Env.hasRestApi) {
      throw StateError(
        'Exclusao de conta SECAMI e feita pela gestao da academia '
        '(a identidade vem do AD, nao e auto-servico no app).',
      );
    }
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      return;
    }
    await client
        .from('users')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', user.id);
    await client.auth.signOut();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase nao configurado. Preencha SUPABASE_URL e SUPABASE_ANON_KEY no .env',
      );
    }
    return client;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(SupabaseConfig.clientOrNull, ref.watch(apiClientProvider));
});
