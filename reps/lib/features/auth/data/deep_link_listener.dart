import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/logging/observability.dart';

/// Escuta deep links no formato `reps://auth-callback?code=...` e troca o
/// code por sessao no Supabase. Singleton inicializado no main().
class DeepLinkListener {
  DeepLinkListener._();
  static final DeepLinkListener instance = DeepLinkListener._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Captura o link inicial se o app foi aberto por um deep link (cold start)
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handle(initial);
      }
    } on Exception catch (e, st) {
      await Observability.captureError(e, st, hint: 'deeplink_initial');
    }

    // Continua escutando enquanto app rodando (warm)
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e, StackTrace st) {
        Observability.captureError(e, st, hint: 'deeplink_stream');
      },
    );
  }

  Future<void> _handle(Uri uri) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[deeplink] received: $uri');
    }
    if (uri.scheme != 'reps') return;

    // Supabase as vezes coloca os parametros depois de '#' (fragment) e nao
    // como query — tratamos os dois.
    final params = <String, String>{}
      ..addAll(uri.queryParameters)
      ..addAll(Uri.splitQueryString(uri.fragment));

    final error = params['error'] ?? params['error_code'];
    final errorDescription = params['error_description'];

    if (error != null && error.isNotEmpty) {
      await Observability.captureError(
        StateError('auth deep link error: $error'),
        StackTrace.current,
        hint: errorDescription ?? error,
      );
      _emitMessage(errorDescription ?? 'Link inválido ou expirado.');
      return;
    }

    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      await Observability.captureError(
        StateError('supabase nao configurado no deep link callback'),
        StackTrace.current,
      );
      return;
    }

    // Fluxo PKCE: ?code=...
    final code = params['code'];
    if (code != null && code.isNotEmpty) {
      try {
        await client.auth.exchangeCodeForSession(code);
        await Observability.track('auth_email_confirmed_via_link');
        _emitMessage('E-mail confirmado! Bem-vindo ao reps.');
        return;
      } on AuthException catch (e, st) {
        await Observability.captureError(e, st, hint: 'exchange_code');
        _emitMessage('Link expirou ou já foi usado. Faça login normal.');
        return;
      }
    }

    // Fluxo OTP / token_hash: ?token_hash=...&type=signup|recovery|magiclink
    final tokenHash = params['token_hash'] ?? params['token'];
    final typeRaw = params['type'];
    if (tokenHash != null && tokenHash.isNotEmpty && typeRaw != null) {
      final otpType = _parseOtpType(typeRaw);
      if (otpType == null) {
        await Observability.captureError(
          StateError('tipo de OTP desconhecido: $typeRaw'),
          StackTrace.current,
        );
        _emitMessage('Link inválido.');
        return;
      }
      try {
        await client.auth.verifyOTP(tokenHash: tokenHash, type: otpType);
        await Observability.track('auth_email_confirmed_via_link');
        _emitMessage('E-mail confirmado! Bem-vindo ao reps.');
        return;
      } on AuthException catch (e, st) {
        await Observability.captureError(e, st, hint: 'verify_otp');
        _emitMessage('Link expirou ou já foi usado. Faça login normal.');
        return;
      }
    }

    // Fluxo de sessao direta no fragment: #access_token=...&refresh_token=...
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];
    if (accessToken != null && refreshToken != null) {
      try {
        await client.auth.setSession(refreshToken);
        await Observability.track('auth_session_via_link');
        _emitMessage('Sessão restaurada.');
        return;
      } on AuthException catch (e, st) {
        await Observability.captureError(e, st, hint: 'set_session');
        _emitMessage('Não foi possível restaurar a sessão.');
        return;
      }
    }
  }

  OtpType? _parseOtpType(String raw) {
    switch (raw) {
      case 'signup':
      case 'email':
        return OtpType.signup;
      case 'recovery':
        return OtpType.recovery;
      case 'magiclink':
        return OtpType.magiclink;
      case 'invite':
        return OtpType.invite;
      case 'email_change':
        return OtpType.emailChange;
      default:
        return null;
    }
  }

  // Stream com mensagens de UI pro listener mostrar SnackBar.
  final _messages = StreamController<String>.broadcast();
  Stream<String> get messages => _messages.stream;

  void _emitMessage(String msg) {
    if (!_messages.isClosed) _messages.add(msg);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _messages.close();
    _started = false;
  }
}
