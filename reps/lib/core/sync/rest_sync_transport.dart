import 'dart:async';

import '../network/api_client.dart';

/// Adapter REST que imita a fatia do `SupabaseClient` usada por
/// `sync_engine.dart` (`.auth.currentUser`, `.from(table).select()/.eq()/
/// .gt()/.upsert()`), para que o motor de sync (876 linhas já testadas)
/// continue igual — só troca o transporte de Supabase para o backend SECAMI
/// (SPEC §10.3 / E9). Superfície NARROW de propósito: cobre só as chamadas
/// que o engine realmente faz, não é um cliente REST genérico.
class RestSyncTransport {
  RestSyncTransport(this._api);

  final ApiClient _api;

  RestSyncAuth get auth => RestSyncAuth(_api);

  RestQueryBuilder from(String table) => RestQueryBuilder(_api, table);
}

class RestSyncAuth {
  RestSyncAuth(this._api);
  final ApiClient _api;

  /// Síncrono de propósito (mesma forma do `SupabaseClient.auth.currentUser`)
  /// — ver [ApiClient.cachedUserId] para a ressalva da corrida no cold-start.
  RestSyncUser? get currentUser {
    final id = _api.cachedUserId;
    return id == null ? null : RestSyncUser(id);
  }
}

class RestSyncUser {
  RestSyncUser(this.id);
  final String id;
}

/// Builder preguiçoso: `.select()`/`.eq()`/`.gt()` só configuram filtros —
/// a chamada HTTP real só acontece quando o resultado é `await`-ado (mesmo
/// contrato do `PostgrestFilterBuilder` do Supabase, que o sync_engine.dart
/// já assume ao fazer `final rows = await client.from(t).select().eq(...)`).
/// Por isso implementa `Future` em vez de expor `select()` como método
/// assíncrono direto.
class RestQueryBuilder implements Future<List<Map<String, dynamic>>> {
  RestQueryBuilder(this._api, this.table);

  final ApiClient _api;
  final String table;

  String? _since;

  RestQueryBuilder select([String? columns]) => this;

  /// `.eq(ownerColumn, uid)`: no legado filtrava por dono explicitamente;
  /// aqui o dono é sempre resolvido pelo JWT no backend, então o argumento
  /// é ignorado — mantém a mesma chamada no sync_engine.dart intacta.
  RestQueryBuilder eq(String column, Object? value) => this;

  RestQueryBuilder gt(String column, Object? value) {
    _since = value?.toString();
    return this;
  }

  Future<void> upsert(Object jsonOrList) async {
    final list = jsonOrList is List ? jsonOrList : [jsonOrList];
    await _api.post('/sync/$table', body: list);
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    if (table == 'exercises') {
      final data = await _api.get('/exercises') as List;
      return data
          .map((e) {
            final m = e as Map<String, dynamic>;
            final escopo = m['escopo'] as String?;
            return <String, dynamic>{
              'id': m['id'],
              'slug': m['slug'],
              // null = biblioteca global (mesmo contrato de `criado_por` do legado).
              'criado_por': escopo == 'global' ? null : (m['id'] as String?),
            };
          })
          .toList();
    }
    final path = _since == null
        ? '/sync/$table'
        : '/sync/$table?since=${Uri.encodeQueryComponent(_since!)}';
    final data = await _api.get(path) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ---- implementação de Future<...> por delegação a _fetch() ----

  @override
  Stream<List<Map<String, dynamic>>> asStream() => _fetch().asStream();

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) =>
      _fetch().catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) =>
      _fetch().then(onValue, onError: onError);

  @override
  Future<List<Map<String, dynamic>>> timeout(
    Duration timeLimit, {
    FutureOr<List<Map<String, dynamic>>> Function()? onTimeout,
  }) =>
      _fetch().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<Map<String, dynamic>>> whenComplete(FutureOr<void> Function() action) =>
      _fetch().whenComplete(action);
}
