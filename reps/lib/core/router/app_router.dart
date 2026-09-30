import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/env.dart';
import '../../features/academy/presentation/academia_home_screen.dart';
import '../../features/academy/presentation/avisos_janela.dart';
import '../../features/academy/presentation/avisos_screen.dart';
import '../../features/academy/presentation/meu_perfil_screen.dart';
import '../../features/academy/presentation/meu_treino_screen.dart';
import '../../features/academy/presentation/minha_agenda_screen.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/data/rest_auth_service.dart';
import '../../features/auth/presentation/ldap_sign_in_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/auth/presentation/cadastro_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/cardio/presentation/cardio_screen.dart';
import '../../features/coaching/presentation/aluno_detalhe_screen.dart';
import '../../features/coaching/presentation/atribuir_treino_screen.dart';
import '../../features/coaching/presentation/meu_treinador_screen.dart';
import '../../features/coaching/presentation/meus_alunos_screen.dart';
import '../../features/coaching/presentation/org_admin_screen.dart';
import '../../features/history/presentation/exercise_history_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/session_detail_screen.dart';
import '../../features/insights/presentation/weekly_volume_screen.dart';
import '../../features/instructor/presentation/alunos_instrutor_screen.dart';
import '../../features/instructor/presentation/ficha_editor_screen.dart';
import '../../features/instructor/presentation/fichas_aluno_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/recommender/presentation/questionario_screen.dart';
import '../../features/records/presentation/records_screen.dart';
import '../../features/routines/presentation/routine_builder_screen.dart';
import '../../features/routines/presentation/routines_screen.dart';
import '../../features/settings/presentation/delete_account_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/workout/presentation/workout_screen.dart';
import 'home_shell.dart';
import 'secami_access.dart';

/// Adapter Riverpod -> Listenable para o GoRouter atualizar quando a sessao
/// muda (ex.: depois do deep link de confirmacao de email).
class _GoRouterAuthRefresh extends ChangeNotifier {
  _GoRouterAuthRefresh(this._ref) {
    // Modo SECAMI: a sessao vem do JWT/LDAP (secamiCurrentUserProvider), nao
    // do Supabase auth stream — escuta a fonte certa em cada modo.
    _sub = Env.hasRestApi
        ? _ref.listen(secamiCurrentUserProvider, (_, _) => notifyListeners())
        : _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterAuthRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    // Sem isto, uma rota nao-resolvida ou pilha vazia pinta a tela de preto
    // (scaffoldBackground = surface, quase preto no tema escuro). Aqui mostra
    // um estado visivel com o erro e um caminho de volta.
    errorBuilder: (context, state) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: const Text('Ops')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Não encontramos esta tela.'),
              // Detalhe técnico (rota/erro) só em desenvolvimento — o usuário
              // final nunca vê caminho interno nem stack.
              if (!kReleaseMode) ...[
                const SizedBox(height: 8),
                Text(
                  'rota: ${state.uri}\n${state.error}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/routines'),
                child: const Text('Voltar para Treinos'),
              ),
            ],
          ),
        ),
      );
    },
    redirect: (context, state) async {
      final loc = state.matchedLocation;

      if (Env.hasRestApi) {
        // Modo SECAMI: login local obrigatorio, sem modo convidado (SPEC
        // §12.4). Espera a sessao salva (token no SharedPreferences)
        // resolver ANTES de decidir — ref.read(...future) so espera de
        // verdade na carga inicial da pagina (refresh do navegador); depois
        // que resolve uma vez, retorna na hora. Sem isso, um refresh lia
        // currentUserProvider ainda em loading (null) e derrubava pro
        // /sign-in mesmo com uma sessao valida salva.
        final secamiUser = await ref.read(secamiCurrentUserProvider.future);
        // Sem sessão → /sign-in (ou /cadastro, público). Logado: sai das
        // telas de entrada e respeita o papel — telas de aluno só para
        // `aluno`, telas do instrutor só para `professor` (secami_access).
        return secamiRedirect(secamiUser, loc);
      }

      // ---- modo legado (Supabase + convidado) ----
      final hasGuest = ref.read(guestIdentityProvider).current != null;
      final isAuthed = ref.read(currentUserProvider) != null;

      // Acabou de logar (deep link, signin): sai da Welcome / Sign-* pra app.
      const authRoutes = {'/', '/sign-in', '/sign-up', '/forgot-password'};
      if (authRoutes.contains(loc) && isAuthed) {
        return '/routines';
      }
      if (loc == '/' && hasGuest) {
        return '/routines';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (_, _) =>
            Env.hasRestApi ? const LdapSignInScreen() : const SignInScreen(),
      ),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      // Auto-cadastro publico de aluno (civil/militar sem conta) — so existe
      // no modo SECAMI (backend REST tem /cadastro/*; Supabase legado nao).
      if (Env.hasRestApi)
        GoRoute(path: '/cadastro', builder: (_, _) => const CadastroScreen()),
      ShellRoute(
        // Avisos do admin abrem como janela ao entrar no app (só no modo
        // SECAMI; fora dele o gate não faz nada).
        builder: (context, state, child) =>
            AvisosJanelaGate(child: HomeShell(child: child)),
        routes: [
          GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
          GoRoute(path: '/routines', builder: (_, _) => const RoutinesScreen()),
          GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          if (Env.hasRestApi)
            GoRoute(
              path: '/academia',
              builder: (_, _) => const AcademiaHomeScreen(),
            ),
        ],
      ),
      // Sub-telas da Academia FORA do ShellRoute (mesmo padrão de /coach/*,
      // /records, /cardio abaixo): tela cheia, sem a bottom nav do
      // HomeShell sobreposta. Aninhar em ShellRoute causava um bug real
      // encontrado pelo teste de integração: o botão "Agendar" ficava sob a
      // NavigationBar (mesma faixa Y na tela), e o tap não acertava o botão
      // (hit-test miss) mesmo com o texto visível.
      if (Env.hasRestApi) ...[
        GoRoute(
          path: '/academia/agenda',
          builder: (_, _) => const MinhaAgendaScreen(),
        ),
        GoRoute(
          path: '/academia/treino',
          builder: (_, _) => const MeuTreinoScreen(),
        ),
        GoRoute(
          path: '/academia/avisos',
          builder: (_, _) => const AvisosScreen(),
        ),
        GoRoute(
          path: '/academia/perfil',
          builder: (_, _) => const MeuPerfilScreen(),
        ),
        // Perfil Instrutor (papel `professor`): alunos e fichas de treino.
        // Também fora do ShellRoute — o FAB "Nova ficha" e o botão "Salvar
        // ficha" ficam no rodapé, exatamente onde a bottom nav os cobriria.
        GoRoute(
          path: '/instrutor/alunos',
          builder: (_, _) => const AlunosInstrutorScreen(),
        ),
        GoRoute(
          path: '/instrutor/aluno/:id',
          builder: (_, state) => FichasAlunoScreen(
            studentId: state.pathParameters['id']!,
            // `extra` some num refresh do navegador (web): a tela cai no
            // nome que vier das próprias fichas.
            studentName: state.extra is String ? state.extra as String : null,
          ),
        ),
        GoRoute(
          path: '/instrutor/aluno/:id/ficha',
          builder: (_, state) {
            final extra = state.extra;
            return FichaEditorScreen(
              studentId: state.pathParameters['id']!,
              // Sem `extra` (refresh no web), `?plano=<id>` ainda diz qual
              // ficha editar; sem os dois, é uma ficha nova.
              planId: state.uri.queryParameters['plano'],
              args: extra is FichaEditorArgs ? extra : null,
            );
          },
        ),
      ],
      GoRoute(
        path: '/recomendador',
        builder: (_, state) => QuestionarioScreen(
          completa: state.uri.queryParameters['modo'] != 'simplificada',
        ),
      ),
      GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
      GoRoute(path: '/cardio', builder: (_, _) => const CardioScreen()),
      GoRoute(
        path: '/coach/alunos',
        builder: (_, _) => const MeusAlunosScreen(),
      ),
      GoRoute(
        path: '/coach/treinador',
        builder: (_, _) => const MeuTreinadorScreen(),
      ),
      GoRoute(
        path: '/coach/aluno/:id',
        builder: (_, state) => AlunoDetalheScreen(
          alunoId: state.pathParameters['id']!,
          alunoNome: (state.extra as String?) ?? 'Aluno',
        ),
      ),
      GoRoute(
        path: '/coach/aluno/:id/atribuir',
        builder: (_, state) => AtribuirTreinoScreen(
          alunoId: state.pathParameters['id']!,
          alunoNome: (state.extra as String?) ?? 'aluno',
        ),
      ),
      GoRoute(
        path: '/coach/academia',
        builder: (_, _) => const OrgAdminScreen(),
      ),
      GoRoute(
        path: '/insights/weekly',
        builder: (_, _) => const WeeklyVolumeScreen(),
      ),
      GoRoute(
        path: '/routines/:id',
        builder: (_, state) => RoutineBuilderScreen(
          routineId: state.pathParameters['id']!,
          openPickerOnLoad: state.uri.queryParameters['new'] == '1',
        ),
      ),
      GoRoute(path: '/workout/:id', builder: (_, _) => const WorkoutScreen()),
      GoRoute(
        path: '/history/:id',
        builder: (_, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (_, state) =>
            ExerciseHistoryScreen(exerciseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (_, _) => const AccountScreen(),
      ),
    ],
  );
});
