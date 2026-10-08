import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';

/// Limite do PDF do atestado (o mesmo do auto-cadastro e do backend).
const int maxAtestadoBytes = 10 * 1024 * 1024; // 10MB

/// Situação do atestado médico do aluno (`GET /me/atestado`).
enum SituacaoAtestado {
  /// Em dia (faltam mais de 30 dias).
  ok,

  /// Faltam de 0 a 30 dias (0 = vence hoje).
  vencendo,

  /// Passou da data de vencimento.
  vencido,
}

/// Estado de um envio de atestado novo, aguardando o admin.
enum StatusEnvioAtestado { pendente, recusado, desconhecido }

/// O último envio de atestado que ainda importa: o que está em análise ou o
/// recusado que ainda não foi substituído por outro.
class EnvioAtestado {
  const EnvioAtestado({
    required this.id,
    required this.status,
    this.enviadoEm,
    this.emissaoData,
    this.motivoRecusa,
  });

  final String id;
  final StatusEnvioAtestado status;
  final DateTime? enviadoEm;
  final DateTime? emissaoData;

  /// Só vem quando [status] é [StatusEnvioAtestado.recusado].
  final String? motivoRecusa;

  bool get pendente => status == StatusEnvioAtestado.pendente;
  bool get recusado => status == StatusEnvioAtestado.recusado;

  /// Campos nulos/ausentes são omitidos pelo servidor — nada aqui é exigido.
  factory EnvioAtestado.fromJson(Map<String, dynamic> j) => EnvioAtestado(
    id: _texto(j['id']) ?? '',
    status: switch (_texto(j['status'])?.toUpperCase()) {
      'PENDENTE' => StatusEnvioAtestado.pendente,
      'RECUSADO' => StatusEnvioAtestado.recusado,
      _ => StatusEnvioAtestado.desconhecido,
    },
    enviadoEm: _data(j['enviadoEm']),
    emissaoData: _data(j['emissaoData']),
    motivoRecusa: _texto(j['motivoRecusa']),
  );
}

/// Situação do atestado médico do aluno logado (`GET /me/atestado`).
///
/// Militares, instrutores e contas sem cadastro de aluno vêm com
/// [aplicavel] `false` e nenhum outro campo: o app não mostra nada sobre
/// atestado pra eles.
class AtestadoStatus {
  const AtestadoStatus({
    required this.aplicavel,
    this.situacao = SituacaoAtestado.ok,
    this.bloqueado = false,
    this.vencimento,
    this.diasRestantes,
    this.base,
    this.envio,
  });

  static const naoAplicavel = AtestadoStatus(aplicavel: false);

  final bool aplicavel;
  final SituacaoAtestado situacao;

  /// Acesso à academia bloqueado por causa do atestado vencido.
  final bool bloqueado;
  final DateTime? vencimento;

  /// Dias até o vencimento: 0 = vence hoje; negativo = já venceu.
  final int? diasRestantes;

  /// De onde vem o vencimento: `ATESTADO` (último atestado aprovado) ou
  /// `CADASTRO` (data do cadastro, quando não há atestado aprovado depois).
  final String? base;
  final EnvioAtestado? envio;

  bool get envioPendente => envio?.pendente ?? false;
  bool get envioRecusado => envio?.recusado ?? false;

  /// Abre a janela ao entrar no app: perto de vencer, vencido ou bloqueado.
  bool get exigeAtencao =>
      aplicavel && (situacao != SituacaoAtestado.ok || bloqueado);

  /// [diasRestantes] do servidor; sem ele, calcula a partir do vencimento.
  int? diasAteVencer({DateTime? hoje}) {
    if (diasRestantes != null) return diasRestantes;
    final venc = vencimento;
    if (venc == null) return null;
    final h = hoje ?? DateTime.now();
    final inicio = DateTime.utc(h.year, h.month, h.day);
    final fim = DateTime.utc(venc.year, venc.month, venc.day);
    return fim.difference(inicio).inDays;
  }

  factory AtestadoStatus.fromJson(Map<String, dynamic> j) {
    if (j['aplicavel'] != true) return naoAplicavel;
    final envio = j['envio'];
    return AtestadoStatus(
      aplicavel: true,
      situacao: switch (_texto(j['situacao'])?.toUpperCase()) {
        'VENCENDO' => SituacaoAtestado.vencendo,
        'VENCIDO' => SituacaoAtestado.vencido,
        _ => SituacaoAtestado.ok,
      },
      bloqueado: j['bloqueado'] == true,
      vencimento: _data(j['vencimento']),
      diasRestantes: _inteiro(j['diasRestantes']),
      base: _texto(j['base']),
      envio: envio is Map
          ? EnvioAtestado.fromJson(Map<String, dynamic>.from(envio))
          : null,
    );
  }
}

/// PDF escolhido pelo aluno no aparelho.
class ArquivoPdf {
  const ArquivoPdf({required this.nome, required this.bytes});

  final String nome;
  final Uint8List bytes;

  int get tamanho => bytes.lengthInBytes;
}

/// O seletor devolveu um arquivo sem conteúdo legível.
class ArquivoIlegivelException implements Exception {
  const ArquivoIlegivelException();
}

/// Atestado médico do aluno logado: situação e envio de um atestado novo
/// (que vai pra fila de validação do admin).
class AtestadoApi {
  AtestadoApi(this._api);

  final ApiClient _api;

  static const _respostaInesperada =
      'O servidor devolveu uma resposta inesperada. Tente novamente em '
      'instantes.';

  Future<AtestadoStatus> status() async {
    final data = await _api.get('/me/atestado');
    if (data is! Map) throw ApiException(200, _respostaInesperada);
    return AtestadoStatus.fromJson(Map<String, dynamic>.from(data));
  }

  /// `multipart/form-data` com a parte `dados` (JSON) e a parte `arquivo`
  /// (PDF). Erros do servidor (422 regra de negócio, 409 já há envio em
  /// análise) chegam como [ApiException] com a mensagem pronta.
  Future<EnvioAtestado> enviar({
    required DateTime emissaoData,
    required String medicoNome,
    required String medicoCrm,
    required String medicoCrmUf,
    required ArquivoPdf arquivo,
  }) async {
    if (arquivo.tamanho > maxAtestadoBytes) {
      throw ApiException(0, 'O arquivo do atestado deve ter no máximo 10MB.');
    }
    final dados = jsonEncode({
      'emissaoData': dataIso(emissaoData),
      'medicoNome': medicoNome,
      'medicoCrm': medicoCrm,
      'medicoCrmUf': medicoCrmUf,
    });
    final data = await _api.postMultipart(
      '/me/atestado',
      () => [
        http.MultipartFile.fromString(
          'dados',
          dados,
          contentType: MediaType('application', 'json'),
        ),
        http.MultipartFile.fromBytes(
          'arquivo',
          arquivo.bytes,
          filename: arquivo.nome,
          contentType: MediaType('application', 'pdf'),
        ),
      ],
    );
    if (data is Map) {
      return EnvioAtestado.fromJson(Map<String, dynamic>.from(data));
    }
    // 201 sem corpo: o envio foi aceito do mesmo jeito.
    return EnvioAtestado(
      id: '',
      status: StatusEnvioAtestado.pendente,
      enviadoEm: DateTime.now(),
      emissaoData: emissaoData,
    );
  }
}

final atestadoApiProvider = Provider<AtestadoApi>(
  (ref) => AtestadoApi(ref.watch(apiClientProvider)),
);

/// Situação do atestado pras telas do aluno (perfil, agenda, envio). Falha
/// aqui nunca bloqueia nada: as telas simplesmente não mostram o atestado.
final atestadoStatusProvider = FutureProvider.autoDispose<AtestadoStatus>((
  ref,
) async {
  if (!Env.hasRestApi) return AtestadoStatus.naoAplicavel;
  return ref.watch(atestadoApiProvider).status();
});

/// Abre o seletor de arquivos do aparelho (só PDF). Num provider pra ser
/// trocado nos testes — o `file_picker` não roda em widget test.
final selecionarPdfProvider = Provider<Future<ArquivoPdf?> Function()>(
  (ref) => _selecionarPdfDoAparelho,
);

Future<ArquivoPdf?> _selecionarPdfDoAparelho() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) throw const ArquivoIlegivelException();
  return ArquivoPdf(nome: file.name, bytes: bytes);
}

/// `YYYY-MM-DD` (data sem hora, como o backend espera).
String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String? _texto(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? _inteiro(Object? v) => switch (v) {
  final num n => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

/// `2027-03-30` vira data local (sem fuso); `2026-10-08T14:00:00-03:00`
/// vira o instante no fuso do aparelho.
DateTime? _data(Object? v) {
  final t = _texto(v);
  if (t == null) return null;
  final d = DateTime.tryParse(t);
  if (d == null) return null;
  return d.isUtc ? d.toLocal() : d;
}
