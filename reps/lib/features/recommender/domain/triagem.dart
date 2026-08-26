/// Respostas da triagem de seguranca inspirada no PAR-Q+ (RN-001). Cada flag
/// true indica resposta positiva a uma pergunta de risco.
class RespostasTriagem {
  const RespostasTriagem({
    this.condicaoCardiaca = false,
    this.pressaoAltaNaoControlada = false,
    this.dorNoPeito = false,
    this.tonturaDesmaio = false,
    this.perdaEquilibrio = false,
    this.doencaCronicaNaoAcompanhada = false,
    this.usaMedicamentos = false,
    this.lesaoRelevante = false,
    this.gestacaoRisco = false,
    this.restricaoMedica = false,
  });

  /// Sem nenhum alerta (atalho para a analise simplificada quando o usuario
  /// confirma estar apto).
  const RespostasTriagem.semAlertas() : this();

  final bool condicaoCardiaca;
  final bool pressaoAltaNaoControlada;
  final bool dorNoPeito;
  final bool tonturaDesmaio;
  final bool perdaEquilibrio;
  final bool doencaCronicaNaoAcompanhada;
  final bool usaMedicamentos;
  final bool lesaoRelevante;
  final bool gestacaoRisco;
  final bool restricaoMedica;

  Map<String, dynamic> toJson() => {
    'condicao_cardiaca': condicaoCardiaca,
    'pressao_alta_nao_controlada': pressaoAltaNaoControlada,
    'dor_no_peito': dorNoPeito,
    'tontura_desmaio': tonturaDesmaio,
    'perda_equilibrio': perdaEquilibrio,
    'doenca_cronica_nao_acompanhada': doencaCronicaNaoAcompanhada,
    'usa_medicamentos': usaMedicamentos,
    'lesao_relevante': lesaoRelevante,
    'gestacao_risco': gestacaoRisco,
    'restricao_medica': restricaoMedica,
  };
}

/// Veredito da triagem (secao 13, etapa 1).
enum TriagemNivel {
  /// Sem alertas: pode gerar treino normal.
  liberado,

  /// Alertas leves (medicamentos, perda de equilibrio): gera treino, mas
  /// conservador, sem alta intensidade.
  liberadoComCautela,

  /// Alerta critico (RN-002): nao gera treino intenso automaticamente; mostra
  /// orientacao de avaliacao profissional.
  encaminhar;

  String get label {
    switch (this) {
      case TriagemNivel.liberado:
        return 'Liberado';
      case TriagemNivel.liberadoComCautela:
        return 'Liberado com cautela';
      case TriagemNivel.encaminhar:
        return 'Buscar avaliacao';
    }
  }
}

class TriagemResultado {
  const TriagemResultado({
    required this.nivel,
    required this.bloqueiaIntenso,
    required this.motivos,
    required this.orientacao,
  });

  final TriagemNivel nivel;

  /// RN-002: impede treino intenso/avancado/alta carga.
  final bool bloqueiaIntenso;

  /// Motivos legiveis do alerta (para exibir e auditar).
  final List<String> motivos;

  /// Orientacao ao usuario (RN-003).
  final String orientacao;

  Map<String, dynamic> toJson() => {
    'nivel': nivel.name,
    'bloqueia_intenso': bloqueiaIntenso,
    'motivos': motivos,
  };
}
