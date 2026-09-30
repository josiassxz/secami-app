import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/rest_auth_service.dart';
import 'academy_api.dart';

/// Avisos que abrem como janela ao entrar no app (SECAMI): os ativos, dentro
/// do período de exibição definido no admin e que o usuário ainda não marcou
/// "Não mostrar novamente". A dispensa fica no servidor, por usuário — vale
/// em qualquer aparelho/navegador.
class AvisosApi {
  AvisosApi(this._api);

  final ApiClient _api;

  Future<List<NoticeDto>> janela() async {
    final data = await _api.get('/notices/modal') as List;
    return data
        .map((e) => NoticeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Não mostrar novamente" (idempotente no servidor).
  Future<void> dispensar(String avisoId) async {
    await _api.post('/notices/$avisoId/dispensar');
  }
}

final avisosApiProvider = Provider<AvisosApi>(
  (ref) => AvisosApi(ref.watch(apiClientProvider)),
);

/// Id do usuário pra quem a janela de avisos já foi verificada nesta sessão
/// do app — evita reabrir a cada troca de aba. Volta a zero sempre que a
/// sessão muda (entrar, sair, entrar de novo), porque observa
/// [secamiCurrentUserProvider]; abrir o app ou recarregar a página também
/// começa do zero.
final avisosVerificadosParaProvider = StateProvider<String?>((ref) {
  ref.watch(secamiCurrentUserProvider);
  return null;
});
