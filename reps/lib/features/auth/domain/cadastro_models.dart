/// Modelos do fluxo de auto-cadastro publico de aluno (`POST /cadastro`).
/// Ver backend: aluno civil/militar sem conta preenche o formulario e fica
/// pendente de aprovacao do admin.
library;

/// Objetivos possiveis (`objetivos[]`) — valores EXATOS esperados pelo
/// backend, com acentuacao original.
const List<String> cadastroObjetivos = [
  'Emagrecimento',
  'Hipertrofia',
  'Condicionamento',
  'Saúde e bem-estar',
  'Reabilitação',
  'Força',
];

/// As 27 UFs (26 estados + DF) pro combo de CRM.
const List<String> ufsBrasil = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', //
  'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', //
  'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

/// Uma pergunta do questionario PAR-Q, com a chave exata esperada pelo
/// backend (`parQ.<chave>`) e o texto oficial (nao reformular).
class ParQPergunta {
  const ParQPergunta(this.chave, this.texto);

  final String chave;
  final String texto;
}

/// As 10 perguntas do PAR-Q, na ordem oficial. Todas obrigatorias, sem
/// resposta padrao.
const List<ParQPergunta> parQPerguntas = [
  ParQPergunta(
    'problema_coracao',
    'Algum médico já disse que você possui algum problema de coração e que '
        'só deveria realizar atividade física supervisionado por '
        'profissionais de saúde?',
  ),
  ParQPergunta(
    'dor_peito_atividade',
    'Você sente dores no peito e/ou tórax quando pratica atividade física?',
  ),
  ParQPergunta(
    'dor_peito_mes',
    'No último mês, você sentiu dores no peito independente da prática de '
        'atividade física?',
  ),
  ParQPergunta(
    'desequilibrio_tontura',
    'Você apresenta desequilíbrio devido a tontura e/ou perda de '
        'consciência?',
  ),
  ParQPergunta(
    'problema_osseo_articular',
    'Você possui algum problema ósseo ou articular que poderia piorar em '
        'consequência de alteração em sua atividade física?',
  ),
  ParQPergunta(
    'tratamento_pressao_coracao',
    'Você realiza algum tipo de tratamento médico para pressão arterial '
        'e/ou problema de coração?',
  ),
  ParQPergunta(
    'outra_razao_nao_praticar',
    'Sabe de alguma outra razão pela qual você não deve praticar atividade '
        'física?',
  ),
  ParQPergunta(
    'tratamento_continuo',
    'Você realiza algum tratamento médico contínuo, que possa ser afetado '
        'ou prejudicado com a atividade física?',
  ),
  ParQPergunta(
    'cirurgia_compromete_atividade',
    'Você já se submeteu a algum tipo de cirurgia, que comprometa de '
        'alguma forma a atividade física?',
  ),
  ParQPergunta(
    'outra_razao_compromete_saude',
    'Sabe de alguma outra razão pela qual a atividade física possa '
        'eventualmente comprometer sua saúde?',
  ),
];

/// Respostas do PAR-Q — as 10 chaves sao obrigatorias no payload, exatamente
/// com esses nomes (contrato do backend).
class ParQRespostas {
  const ParQRespostas({required this.respostas});

  /// Uma entrada por chave em [parQPerguntas], todas nao-nulas quando prontas
  /// pra envio (validado na tela antes de montar este objeto).
  final Map<String, bool> respostas;

  Map<String, dynamic> toJson() => respostas;
}

/// Payload completo do auto-cadastro (`POST /cadastro`, part `dados`).
class CadastroRequest {
  const CadastroRequest({
    required this.fullName,
    required this.cpf,
    required this.birthDate,
    required this.whatsapp,
    required this.departmentId,
    required this.email,
    required this.password,
    required this.weightKg,
    required this.heightCm,
    required this.objetivos,
    required this.parQ,
    required this.termoResponsabilidade,
    required this.termoCiencia,
    required this.medicoNome,
    required this.medicoCrm,
    required this.medicoCrmUf,
    required this.atestadoEmissaoData,
  });

  final String fullName;

  /// Somente digitos, 11 caracteres.
  final String cpf;
  final DateTime birthDate;
  final String whatsapp;
  final String departmentId;
  final String email;
  final String password;
  final double? weightKg;
  final double? heightCm;
  final List<String> objetivos;
  final ParQRespostas parQ;
  final bool termoResponsabilidade;
  final bool termoCiencia;
  final String medicoNome;
  final String medicoCrm;
  final String medicoCrmUf;
  final DateTime atestadoEmissaoData;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'cpf': cpf,
    'birthDate': _iso(birthDate),
    'whatsapp': whatsapp,
    'departmentId': departmentId,
    'email': email,
    'password': password,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'objetivos': objetivos,
    'parQ': parQ.toJson(),
    'termoResponsabilidade': termoResponsabilidade,
    'termoCiencia': termoCiencia,
    'medicoNome': medicoNome,
    'medicoCrm': medicoCrm,
    'medicoCrmUf': medicoCrmUf,
    'atestadoEmissaoData': _iso(atestadoEmissaoData),
  };
}
