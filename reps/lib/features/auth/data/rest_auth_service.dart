import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Usuario autenticado no backend SECAMI.
class SecamiUser {
  const SecamiUser({
    required this.id,
    required this.samAccountName,
    required this.nome,
    required this.email,
    required this.roles,
  });

  final String id;
  final String samAccountName;
  final String nome;
  final String email;
  final List<String> roles;

  bool hasRole(String role) => roles.contains(role);
  bool get isProfessor => hasRole('professor');
  bool get isAluno => hasRole('aluno');

  /// Perfil "Instrutor" da interface = papel `professor` do backend (o nome
  /// do papel é legado; na tela o termo é sempre "Instrutor").
  bool get isInstrutor => hasRole('professor');

  /// Instrutor que NÃO é aluno: não tem cadastro de aluno no backend, então
  /// agenda, ficha própria, perfil de aluno e "Meu treinador" não se aplicam
  /// (as rotas `/me/student`, `/me/appointments` etc. não existem pra ele).
  bool get isSomenteInstrutor => isInstrutor && !isAluno;

  factory SecamiUser.fromJson(Map<String, dynamic> j) => SecamiUser(
    id: j['id'] as String,
    samAccountName: (j['samAccountName'] as String?) ?? '',
    nome: (j['nome'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    roles: ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Autenticacao local por e-mail/senha → JWT (SPEC §12, revisado — LDAP
/// removido). Substitui o Supabase Auth do legado.
class RestAuthService {
  RestAuthService(this._api);

  final ApiClient _api;

  /// Login por e-mail + senha. Guarda os tokens.
  Future<SecamiUser> login(String email, String password) async {
    final data =
        await _api.post(
              '/auth/login',
              auth: false,
              body: {'email': email.trim(), 'password': password},
            )
            as Map<String, dynamic>;
    await _api.saveTokens(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return me();
  }

  Future<SecamiUser> me() async {
    final data = await _api.get('/me') as Map<String, dynamic>;
    return SecamiUser.fromJson(data);
  }

  Future<SecamiUser?> currentUserOrNull() async {
    if (!await _api.isAuthenticated) return null;
    try {
      return await me();
    } catch (_) {
      await _api.clearTokens();
      return null;
    }
  }

  Future<void> logout() => _api.clearTokens();
}

final restAuthServiceProvider = Provider<RestAuthService>(
  (ref) => RestAuthService(ref.watch(apiClientProvider)),
);

/// Estado de autenticacao SECAMI para o router observar (SPEC §10.2).
/// Nome distinto do `currentUserProvider` legado (Supabase `User?`) em
/// auth_providers.dart para evitar colisao — este e a fonte de verdade
/// quando `Env.hasRestApi`; auth_providers.dart adapta o resultado para o
/// tipo `User` do Supabase (compatibilidade com os ~16 consumidores
/// existentes que leem `currentUserProvider.id`).
final secamiCurrentUserProvider = FutureProvider<SecamiUser?>(
  (ref) => ref.watch(restAuthServiceProvider).currentUserOrNull(),
);
