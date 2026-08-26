import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';
import '../config/supabase_client.dart';

/// Wrappers de telemetria. No-op silencioso quando as chaves estao vazias.
class Observability {
  const Observability._();

  static Future<void> initSentry({required Widget Function() runApp}) async {
    if (!Env.hasSentry) {
      runApp();
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      options.tracesSampleRate = 0.2;
      options.attachScreenshot = false;
    }, appRunner: runApp);
  }

  static Future<void> initPostHog() async {
    if (!Env.hasPostHog) {
      return;
    }
    // posthog_flutter usa configuracao via Info.plist/AndroidManifest.
    // Aqui apenas garantimos init e identidade anonima.
    await Posthog().setup(
      PostHogConfig(Env.posthogApiKey)
        ..host = Env.posthogHost
        ..debug = kDebugMode,
    );
  }

  static Future<void> captureError(
    Object error,
    StackTrace? stack, {
    String? hint,
  }) async {
    // Grava no Supabase pra consulta posterior (tabela client_logs). Best-
    // effort e nao-bloqueante: erros server-side (RLS, constraint, schema)
    // ficam consultaveis mesmo sem Sentry. Offline nao sobe — e benigno.
    unawaited(_logToSupabase(error, hint));
    if (!Env.hasSentry) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[obs] error: $error\n$stack');
      }
      return;
    }
    await Sentry.captureException(
      error,
      stackTrace: stack,
      hint: Hint.withMap({'hint': ?hint}),
    );
  }

  /// Prepara a mensagem de erro para persistir em client_logs: trunca e REDIGE
  /// PII (e-mails, uuids, tokens JWT-like) — mensagens de Postgrest/constraint
  /// embutem valores de coluna. Diagnostico precisa da CLASSE do erro +
  /// contexto, nao do dado do usuario (LGPD).
  @visibleForTesting
  static String redactErrorMessage(Object error, {int maxLen = 500}) {
    var msg = '${error.runtimeType}: $error';
    msg = msg
        .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<email>')
        .replaceAll(
          RegExp(
            r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
            r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
          ),
          '<uuid>',
        )
        .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '<jwt>');
    return msg.length > maxLen ? '${msg.substring(0, maxLen)}...' : msg;
  }

  /// Insere o erro em public.client_logs quando ha sessao Supabase. Silencioso
  /// em qualquer falha (offline, RLS, sem auth) — telemetria nunca pode
  /// derrubar o fluxo nem recursar (por isso o catch nao chama captureError).
  static Future<void> _logToSupabase(Object error, String? hint) async {
    try {
      final client = SupabaseConfig.clientOrNull;
      final uid = client?.auth.currentUser?.id;
      if (client == null || uid == null) return;
      final msg = redactErrorMessage(error);
      await client.from('client_logs').insert({
        'user_id': uid,
        'nivel': 'error',
        'hint': hint,
        'mensagem': msg,
        'plataforma': defaultTargetPlatform.name,
      });
    } catch (_) {
      // Ignora: nao deixa a gravacao do log quebrar nada.
    }
  }

  static Future<void> track(String event, [Map<String, Object>? props]) async {
    if (!Env.hasPostHog) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[obs] track: $event ${props ?? const <String, Object>{}}');
      }
      return;
    }
    await Posthog().capture(eventName: event, properties: props);
  }
}
