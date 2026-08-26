import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../domain/guest_identity.dart';
import 'rest_auth_service.dart';

/// Provider raiz para SharedPreferences. Inicializado no main().
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Sobrescrever em ProviderScope.overrides');
});

final guestIdentityProvider = Provider<GuestIdentity>((ref) {
  return GuestIdentity(ref.watch(sharedPreferencesProvider));
});

/// Sessao Supabase corrente (legado). Sem uso quando `Env.hasRestApi` — o
/// router e `currentUserProvider` passam a observar `secamiCurrentUserProvider`.
final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (Env.hasRestApi) {
    return const Stream<AuthState?>.empty();
  }
  final client = SupabaseConfig.clientOrNull;
  if (client == null) {
    return Stream<AuthState?>.value(null);
  }
  return client.auth.onAuthStateChange;
});

/// User autenticado, ou null se convidado/nao-logado.
///
/// Modo SECAMI (`Env.hasRestApi`): a identidade real vem do backend LDAP/JWT
/// (`secamiCurrentUserProvider`), mas e adaptada para o tipo `User` do
/// Supabase (gotrue) para nao exigir reescrever os ~16 arquivos existentes
/// que ja leem `currentUserProvider?.id`/`.email` como dono dos dados locais.
/// So os campos usados nesses consumidores (id, email, userMetadata) tem
/// valor real; os demais campos do gotrue `User` sao placeholders inertes.
final currentUserProvider = Provider<User?>((ref) {
  if (Env.hasRestApi) {
    final secami = ref.watch(secamiCurrentUserProvider).valueOrNull;
    if (secami == null) return null;
    return User(
      id: secami.id,
      appMetadata: const {},
      userMetadata: {
        'nome': secami.nome,
        'roles': secami.roles,
        'sam_account_name': secami.samAccountName,
      },
      aud: 'secami',
      email: secami.email,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (state) => state?.session?.user,
    orElse: () => SupabaseConfig.clientOrNull?.auth.currentUser,
  );
});

/// ID efetivo do usuario para escritas locais.
/// Se autenticado -> id do usuario (SECAMI ou Supabase). Caso contrario ->
/// uuid de convidado (modo convidado so existe quando NAO ha backend REST).
final effectiveUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return user.id;
  }
  return ref.watch(guestIdentityProvider).getOrCreate();
});

/// True quando o usuario eh um convidado (sem conta autenticada).
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) == null;
});
