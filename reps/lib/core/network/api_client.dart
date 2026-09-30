import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

/// Erro de API com mensagem pronta para exibir (pt-BR) e status HTTP.
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Cliente HTTP do backend SECAMI (Spring Boot). JWT access + refresh,
/// com refresh automatico em 401. SPEC §9.2 / §10.
///
/// Substitui o acesso direto ao Supabase na migracao do transport (SPEC §10.2).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client() {
    // Aquece o cache síncrono do user id (ver [cachedUserId]) sem bloquear a
    // construção. Corrida possível apenas nos primeiros ~instantes do app
    // (SharedPreferences costuma responder em poucos ms); o sync engine tem
    // retry/periodic, então uma 1ª tentativa vazia não é um bug de dado.
    unawaited(_warmCache());
  }

  final http.Client _client;

  /// Sem timeout, um servidor que aceita a conexão e não responde deixa a
  /// tela girando pra sempre; estourou → cai no mesmo tratamento de falha de
  /// rede (mensagem amigável).
  static const _timeout = Duration(seconds: 30);

  static const _kAccess = 'secami.access';
  static const _kRefresh = 'secami.refresh';

  /// Sub (user id) do JWT de acesso, decodificado de forma síncrona a partir
  /// do cache em memória — usado pelo adapter de sync (`RestSyncTransport`),
  /// que precisa de `.auth.currentUser` sem `await` (mesma forma do antigo
  /// `SupabaseClient`). Populado por [_warmCache] e atualizado em
  /// [saveTokens]/[clearTokens].
  String? _cachedUserId;
  String? get cachedUserId => _cachedUserId;

  Future<void> _warmCache() async {
    final token = await accessToken;
    _cachedUserId = token == null ? null : _decodeJwtSub(token);
  }

  static String? _decodeJwtSub(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload += '=' * ((4 - payload.length % 4) % 4);
      final map =
          jsonDecode(utf8.decode(base64.decode(payload)))
              as Map<String, dynamic>;
      return map['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  String get _base => Env.apiBaseUrl;

  // ---- Tokens ----

  Future<String?> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccess);
  }

  Future<String?> get _refreshToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh);
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
    _cachedUserId = _decodeJwtSub(access);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    _cachedUserId = null;
  }

  Future<bool> get isAuthenticated async => (await accessToken) != null;

  // ---- Requests ----

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool retry = true,
  }) async {
    final uri = Uri.parse('$_base$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final encoded = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await _client.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          res = await _client
              .post(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'PUT':
          res = await _client
              .put(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'PATCH':
          res = await _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'DELETE':
          res = await _client.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError('Metodo nao suportado: $method');
      }
    } on ArgumentError {
      rethrow;
    } catch (e) {
      // Falha de rede (sem internet, servidor fora do ar, bloqueio de mixed
      // content, timeout etc.) — nunca repassa a exceção técnica bruta
      // (ex.: "ClientException: Failed to fetch") pro usuário.
      throw ApiException(
        0,
        'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.',
      );
    }

    if (res.statusCode == 401 && auth && retry && await _tryRefresh()) {
      return _send(method, path, body: body, auth: auth, retry: false);
    }
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    final ok = res.statusCode >= 200 && res.statusCode < 300;

    // O corpo pode não ser JSON válido (página de erro de proxy/gateway,
    // texto simples como "Invalid CORS request" etc.) — nunca deixa o
    // FormatException do jsonDecode vazar pra UI.
    dynamic data;
    var corpoInvalido = false;
    if (text.trim().isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        corpoInvalido = true;
      }
    }

    if (ok) {
      // 2xx com HTML/texto no lugar de JSON = proxy/SPA respondendo no lugar
      // da API (ex.: rota errada, deploy em andamento). Devolver null aqui
      // faria a tela quebrar adiante com um erro de cast sem sentido.
      if (corpoInvalido) {
        throw ApiException(res.statusCode, _mensagemRespostaInesperada);
      }
      return data;
    }

    final message = data is Map ? data['message'] : null;
    final msg = (message is String && message.trim().isNotEmpty)
        ? message
        : _mensagemPadraoPorStatus(res.statusCode);
    throw ApiException(res.statusCode, msg);
  }

  static const _mensagemRespostaInesperada =
      'O servidor devolveu uma resposta inesperada. Tente novamente em '
      'instantes.';

  String _mensagemPadraoPorStatus(int status) => switch (status) {
    401 || 403 => 'Sessão expirada ou sem permissão. Faça login novamente.',
    404 => 'Recurso não encontrado.',
    >= 500 => 'Servidor indisponível no momento. Tente novamente em instantes.',
    _ => 'Não foi possível completar a operação. Tente novamente.',
  };

  Future<bool> _tryRefresh() async {
    final refresh = await _refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$_base/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return false;
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      await saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Provider global do cliente de API.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
