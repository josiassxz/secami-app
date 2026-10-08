// Fake do AtestadoApi (sem rede) compartilhado pelos testes do fluxo de
// atestado médico: situação configurável, contagem de consultas, envios
// registrados e um "segurar" pra testar o estado de envio em andamento.

import 'dart:async';

import 'package:reps/core/network/api_client.dart';
import 'package:reps/features/academy/data/atestado_api.dart';

class EnvioRegistrado {
  const EnvioRegistrado({
    required this.emissaoData,
    required this.medicoNome,
    required this.medicoCrm,
    required this.medicoCrmUf,
    required this.arquivo,
  });

  final DateTime emissaoData;
  final String medicoNome;
  final String medicoCrm;
  final String medicoCrmUf;
  final ArquivoPdf arquivo;
}

class FakeAtestadoApi implements AtestadoApi {
  FakeAtestadoApi({
    this.situacao = AtestadoStatus.naoAplicavel,
    this.falhaStatus = false,
  });

  AtestadoStatus situacao;
  bool falhaStatus;

  /// Erro devolvido por [enviar] (ex.: `ApiException(409, ...)`).
  Object? erroEnvio;

  /// Quando definido, [enviar] só termina depois que ele completar.
  Completer<void>? segurarEnvio;

  int consultas = 0;
  final envios = <EnvioRegistrado>[];

  @override
  Future<AtestadoStatus> status() async {
    consultas++;
    if (falhaStatus) {
      throw ApiException(0, 'Não foi possível conectar ao servidor.');
    }
    return situacao;
  }

  @override
  Future<EnvioAtestado> enviar({
    required DateTime emissaoData,
    required String medicoNome,
    required String medicoCrm,
    required String medicoCrmUf,
    required ArquivoPdf arquivo,
  }) async {
    envios.add(
      EnvioRegistrado(
        emissaoData: emissaoData,
        medicoNome: medicoNome,
        medicoCrm: medicoCrm,
        medicoCrmUf: medicoCrmUf,
        arquivo: arquivo,
      ),
    );
    final segurar = segurarEnvio;
    if (segurar != null) await segurar.future;
    final erro = erroEnvio;
    if (erro != null) throw erro;
    return EnvioAtestado(
      id: 'e1',
      status: StatusEnvioAtestado.pendente,
      enviadoEm: DateTime(2026, 10, 8, 14),
      emissaoData: emissaoData,
    );
  }
}
