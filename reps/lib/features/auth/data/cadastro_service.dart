import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/env.dart';
import '../domain/cadastro_models.dart';
import '../domain/departamento.dart';

const int _maxAtestadoBytes = 10 * 1024 * 1024; // 10MB

/// Erro do fluxo de auto-cadastro, com mensagem pronta pra exibir (pt-BR —
/// o backend ja devolve a mensagem final em `message`).
class CadastroApiException implements Exception {
  CadastroApiException(this.status, this.message, {this.fieldErrors});

  final int status;
  final String message;

  /// Erros por campo (400), quando o backend os informa.
  final Map<String, String>? fieldErrors;

  @override
  String toString() => message;
}

/// Cliente do fluxo publico de auto-cadastro (`/cadastro/*`). Sem token —
/// nao passa pelo `ApiClient` (que e para rotas autenticadas com
/// refresh de JWT).
class CadastroService {
  CadastroService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => Env.apiBaseUrl;

  /// Secretarias/orgaos pro combo do formulario. Publico, sem token.
  Future<List<Departamento>> departamentos() async {
    final uri = Uri.parse('$_base/cadastro/departamentos');
    final http.Response res;
    try {
      res = await _client.get(uri);
    } on Object {
      throw CadastroApiException(
        0,
        'Sem conexão com o servidor. Verifique sua internet e tente de novo.',
      );
    }
    if (res.statusCode != 200) {
      throw CadastroApiException(
        res.statusCode,
        'Não foi possível carregar a lista de secretarias/órgãos.',
      );
    }
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return data
          .map((e) => Departamento.fromJson(e as Map<String, dynamic>))
          .where((d) => d.active)
          .toList();
    } on Object {
      // 200 com HTML/JSON inesperado (proxy no lugar da API) — nunca deixa o
      // FormatException/TypeError chegar na tela.
      throw CadastroApiException(
        res.statusCode,
        'Não foi possível carregar a lista de secretarias/órgãos.',
      );
    }
  }

  /// Envia o formulario completo + PDF do atestado. `multipart/form-data`
  /// com exatamente 2 partes: `dados` (JSON) e `atestado` (PDF).
  Future<void> enviar(CadastroRequest request, PlatformFile atestado) async {
    final bytes = atestado.bytes;
    if (bytes == null) {
      throw CadastroApiException(
        0,
        'Não foi possível ler o arquivo selecionado. Tente escolher o PDF '
        'novamente.',
      );
    }
    if (bytes.lengthInBytes > _maxAtestadoBytes) {
      throw CadastroApiException(
        0,
        'O arquivo do atestado deve ter no máximo 10MB.',
      );
    }

    final uri = Uri.parse('$_base/cadastro');
    final multipart = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromString(
          'dados',
          jsonEncode(request.toJson()),
          contentType: MediaType('application', 'json'),
        ),
      )
      ..files.add(
        http.MultipartFile.fromBytes(
          'atestado',
          bytes,
          filename: atestado.name,
          contentType: MediaType('application', 'pdf'),
        ),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(multipart);
    } on Object {
      throw CadastroApiException(
        0,
        'Sem conexão com o servidor. Verifique sua internet e tente de novo.',
      );
    }
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) return;
    throw _errorFrom(res);
  }

  CadastroApiException _errorFrom(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text) as Map<String, dynamic>;
      } on Object {
        data = null;
      }
    }
    final rawMessage = data?['message'];
    final backendMessage =
        (rawMessage is String && rawMessage.trim().isNotEmpty)
        ? rawMessage
        : null;
    Map<String, String>? fieldErrors;
    final rawFieldErrors = data?['fieldErrors'];
    if (rawFieldErrors is Map) {
      fieldErrors = rawFieldErrors.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    return CadastroApiException(
      res.statusCode,
      backendMessage ?? _fallbackMessage(res.statusCode),
      fieldErrors: fieldErrors,
    );
  }

  String _fallbackMessage(int status) {
    switch (status) {
      case 400:
        return 'Verifique os dados informados e tente novamente.';
      case 409:
        return 'CPF ou e-mail já cadastrado.';
      case 422:
        return 'Não foi possível concluir o cadastro com os dados '
            'informados.';
      default:
        return 'Não foi possível enviar o cadastro agora. Tente de novo em '
            'instantes.';
    }
  }
}

final cadastroServiceProvider = Provider<CadastroService>(
  (ref) => CadastroService(),
);

/// Lista de secretarias/orgaos pro combo — carregada uma vez por sessao de
/// tela (autoDispose: descarta quando a tela de cadastro sai da arvore).
final departamentosProvider = FutureProvider.autoDispose<List<Departamento>>((
  ref,
) {
  return ref.watch(cadastroServiceProvider).departamentos();
});
