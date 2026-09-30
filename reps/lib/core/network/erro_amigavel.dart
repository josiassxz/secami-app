import 'dart:async';

import 'api_client.dart';

const mensagemErroGenerica = 'Algo deu errado. Tente novamente em instantes.';

const mensagemErroConexao =
    'Não foi possível conectar ao servidor. Verifique sua internet e tente '
    'novamente.';

/// Texto seguro pra exibir ao usuário a partir de QUALQUER exceção.
///
/// Só [ApiException] carrega mensagem já pronta em pt-BR (vinda do backend ou
/// montada pelo [ApiClient]); qualquer outra coisa (FormatException,
/// TypeError, ClientException, stack de Drift etc.) é detalhe técnico e nunca
/// vai pra tela — o detalhe segue pra telemetria via `Observability`.
String mensagemDeErro(Object? erro, {String? fallback}) {
  if (erro is ApiException) {
    final msg = erro.message.trim();
    if (msg.isNotEmpty) return msg;
  }
  if (erro is TimeoutException) return mensagemErroConexao;
  return fallback ?? mensagemErroGenerica;
}
