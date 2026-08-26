import '../../../domain/entities/exercise.dart';

/// Classificacao de nivel tecnico dos exercicios canonicos (E0 do
/// stage-05-recommender). Implementa a heuristica do PDF de regras de negocio
/// (RN-014 iniciante absoluto, RN-036 exercicios complexos) de forma
/// conservadora (RN-013): em duvida, classifica para baixo.
///
/// ESTE ARQUIVO E O ARTEFATO DE REVISAO. A Observacao final do PDF exige que
/// um profissional de Educacao Fisica revise a classificacao de nivel antes de
/// producao. Ajustes pontuais = editar os conjuntos abaixo.
///
/// Regra geral (apos as excecoes):
///   1. slug em [_avancado]                  -> avancado
///   2. slug em [_intermediarioPesoCorporal] -> intermediario
///   3. isolador (qualquer equipamento)      -> iniciante
///   4. multiarticular guiado/leve
///      (maquina, cabo, peso corporal)       -> iniciante
///   5. multiarticular com peso livre
///      (barra, halter, kettlebell, anilha)  -> intermediario
class ExerciseClassifier {
  const ExerciseClassifier._();

  /// Tecnicamente complexos ou de alto risco (RN-036): terra pesado,
  /// agachamentos livres com barra, dobradica de quadril carregada na coluna e
  /// pliometria/movimentos balisticos avancados.
  static const _avancado = <String>{
    'levantamento_terra_convencional',
    'agachamento_livre_barra',
    'agachamento_frontal_barra',
    'bom_dia_barra',
    'agachamento_salto',
    'box_jump',
    'turkish_get_up',
    'thruster_halter',
  };

  /// Peso corporal que exige forca de base relevante (barra fixa, paralelas).
  /// Nao sao iniciante absoluto apesar de "peso corporal".
  static const _intermediarioPesoCorporal = <String>{
    'barra_fixa_pronada',
    'barra_fixa_supinada',
    'paralelas_peito',
  };

  static NivelTecnico classificarNivel({
    required String slug,
    required PadraoMovimento padrao,
    required Equipamento equipamento,
  }) {
    if (_avancado.contains(slug)) return NivelTecnico.avancado;
    if (_intermediarioPesoCorporal.contains(slug)) {
      return NivelTecnico.intermediario;
    }
    // Isoladores tem baixa complexidade tecnica (RN-014).
    if (padrao == PadraoMovimento.isolador) return NivelTecnico.iniciante;
    // Multiarticulares guiados ou de peso corporal controlado -> iniciante.
    switch (equipamento) {
      case Equipamento.maquina:
      case Equipamento.cabo:
      case Equipamento.peso_corporal:
        return NivelTecnico.iniciante;
      case Equipamento.barra:
      case Equipamento.halter:
      case Equipamento.kettlebell:
      case Equipamento.anilha:
        return NivelTecnico.intermediario;
    }
  }
}
