import '../triagem.dart';

/// Portao de seguranca (RN-001/002/003). Avalia a triagem PAR-Q+ ANTES de
/// qualquer geracao de treino. E o componente mais critico do motor.
class SafetyGate {
  const SafetyGate._();

  /// Condicoes criticas (RN-002): bloqueiam treino intenso e encaminham para
  /// avaliacao profissional.
  static TriagemResultado avaliar(RespostasTriagem t) {
    final criticos = <String>[];
    if (t.condicaoCardiaca) criticos.add('Condicao cardiaca');
    if (t.pressaoAltaNaoControlada) {
      criticos.add('Pressao alta nao controlada');
    }
    if (t.dorNoPeito) criticos.add('Dor no peito');
    if (t.tonturaDesmaio) criticos.add('Tontura ou desmaio recorrente');
    if (t.doencaCronicaNaoAcompanhada) {
      criticos.add('Doenca cronica nao acompanhada');
    }
    if (t.gestacaoRisco) criticos.add('Gestacao de risco');
    if (t.lesaoRelevante) criticos.add('Lesao relevante');
    if (t.restricaoMedica) criticos.add('Restricao medica');

    if (criticos.isNotEmpty) {
      return TriagemResultado(
        nivel: TriagemNivel.encaminhar,
        bloqueiaIntenso: true,
        motivos: criticos,
        orientacao:
            'Identificamos uma condicao que pede avaliacao antes de treinar. '
            'Procure um medico, fisioterapeuta ou profissional de Educacao '
            'Fisica antes de iniciar. Esta recomendacao e apenas informativa '
            'e nao substitui avaliacao individualizada.',
      );
    }

    // Alertas leves: gera treino, mas conservador (sem alta intensidade).
    final leves = <String>[];
    if (t.usaMedicamentos) leves.add('Uso de medicamentos');
    if (t.perdaEquilibrio) leves.add('Perda de equilibrio');
    if (leves.isNotEmpty) {
      return TriagemResultado(
        nivel: TriagemNivel.liberadoComCautela,
        bloqueiaIntenso: true,
        motivos: leves,
        orientacao:
            'Geramos um treino conservador. Comece leve e, se possivel, '
            'confirme com um profissional de saude se ha alguma restricao.',
      );
    }

    return const TriagemResultado(
      nivel: TriagemNivel.liberado,
      bloqueiaIntenso: false,
      motivos: [],
      orientacao:
          'Recomendacao educativa, nao substitui avaliacao de profissional '
          'habilitado.',
    );
  }
}
