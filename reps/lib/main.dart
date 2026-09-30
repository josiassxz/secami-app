import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/supabase_client.dart';
import 'core/logging/observability.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/auth/data/deep_link_listener.dart';
import 'features/library/data/library_repository.dart';
import 'features/library/presentation/exercise_thumb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Em release, uma excecao durante o build vira tela preta/cinza sem aviso.
  // Troca por um card legivel com a mensagem do erro (e registra na telemetria).
  ErrorWidget.builder = (details) => _FatalErrorWidget(details: details);
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    prevOnError?.call(details);
    unawaited(
      Observability.captureError(
        details.exception,
        details.stack ?? StackTrace.current,
        hint: 'flutter_error',
      ),
    );
  };
  // Erro assincrono nao capturado: em release isso FECHA o app. Captura,
  // loga e retorna true pra manter o app vivo (ex.: falha de sync/export).
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      Observability.captureError(error, stack, hint: 'platform_dispatcher'),
    );
    return true;
  };

  await Env.load();
  await initializeDateFormatting('pt_BR');
  await SupabaseConfig.initialize();
  await Observability.initPostHog();
  // Seed estendido (ExerciseDB ja traduzido) carrega no _Bootstrap, via
  // libraryRepositoryProvider (sem mais singleton static — 4.2).
  // Notificacoes locais (no-op em web). Pede permissao logo apos inicializar
  // (init() so marca _ready ao terminar, por isso o encadeamento).
  unawaited(
    NotificationService.instance.init().then(
      (_) => NotificationService.instance.requestPermissions(),
    ),
  );
  // Escuta deep links de auth (ex.: reps://auth-callback?code=...)
  unawaited(DeepLinkListener.instance.start());

  final prefs = await SharedPreferences.getInstance();

  await Observability.initSentry(
    runApp: () {
      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const _Bootstrap(),
        ),
      );
      return const RepsApp();
    },
  );
}

/// Substitui a tela preta/cinza padrao de erro de build por um aviso legivel
/// e sem jargao tecnico (o detalhe so aparece fora de release).
/// Funciona sem ancestral Material (usa apenas widgets basicos).
class _FatalErrorWidget extends StatelessWidget {
  const _FatalErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(
          0xFFB00020,
        ), // vermelho vivo: nunca confundir com preto
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Algo deu errado nesta tela.',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Volte e tente novamente. Se o problema continuar, avise o '
                'suporte da Academia SECAMI.',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Detalhe técnico só fora de release (o erro já vai pra
              // telemetria em FlutterError.onError).
              if (!kReleaseMode) ...[
                const SizedBox(height: 12),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ],
              if (!kReleaseMode && details.stack != null) ...[
                const SizedBox(height: 12),
                Text(
                  details.stack.toString(),
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    Observability.track('app_open');
    // Warm-up do seed estendido (no-op se asset nao existir). Antes vivia no
    // main() via singleton static; agora pela instancia do provider (4.2).
    final library = ref.read(libraryRepositoryProvider);
    // ignore: discarded_futures
    library.ensureLoaded().then((_) {
      // Pre-aquece o cache de existencia de asset dos GIFs da biblioteca para
      // evitar o flash fallback->GIF na primeira abertura de cada thumb.
      unawaited(warmupAssetCache(library.all().map((e) => e.assetPath)));
    });
  }

  @override
  Widget build(BuildContext context) => const RepsApp();
}
