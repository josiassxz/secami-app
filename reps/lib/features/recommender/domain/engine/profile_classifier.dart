import '../../../../domain/entities/exercise.dart';
import '../questionario.dart';

/// Perfil de treino derivado do questionario + triagem.
class PerfilTreino {
  const PerfilTreino({
    required this.experienciaEfetiva,
    required this.tetoNivel,
    required this.conservador,
  });

  final NivelExperiencia experienciaEfetiva;

  /// Nivel tecnico maximo de exercicio permitido na selecao (RN-036).
  final NivelTecnico tetoNivel;

  /// Se a prescricao deve ser conservadora (menos volume/intensidade).
  final bool conservador;
}

/// Classifica o usuario em perfil de treino (RN-013/014/016/017).
class ProfileClassifier {
  const ProfileClassifier._();

  static PerfilTreino classificar(
    PerfilQuestionario p, {
    required bool bloqueiaIntenso,
  }) {
    var exp = p.experiencia;

    // RN-017: retorno apos longa pausa -> rebaixa um nivel (conservador).
    if (p.retornoAposPausa) exp = _rebaixar(exp);

    // RN-002: alerta de seguranca -> nunca tratar como avancado.
    if (bloqueiaIntenso && exp == NivelExperiencia.avancado) {
      exp = NivelExperiencia.intermediario;
    }

    final teto = _tetoDoNivel(exp, bloqueiaIntenso: bloqueiaIntenso);
    final conservador =
        bloqueiaIntenso ||
        p.fadigaElevada ||
        exp == NivelExperiencia.nuncaTreinou ||
        exp == NivelExperiencia.iniciante;

    return PerfilTreino(
      experienciaEfetiva: exp,
      tetoNivel: teto,
      conservador: conservador,
    );
  }

  static NivelExperiencia _rebaixar(NivelExperiencia e) {
    switch (e) {
      case NivelExperiencia.avancado:
        return NivelExperiencia.intermediario;
      case NivelExperiencia.intermediario:
        return NivelExperiencia.iniciante;
      case NivelExperiencia.iniciante:
      case NivelExperiencia.nuncaTreinou:
        return NivelExperiencia.iniciante;
    }
  }

  static NivelTecnico _tetoDoNivel(
    NivelExperiencia e, {
    required bool bloqueiaIntenso,
  }) {
    // Com alerta de seguranca, nunca liberar exercicios avancados (RN-002/036).
    if (bloqueiaIntenso) return NivelTecnico.iniciante;
    switch (e) {
      case NivelExperiencia.nuncaTreinou:
      case NivelExperiencia.iniciante:
        return NivelTecnico.iniciante;
      case NivelExperiencia.intermediario:
        return NivelTecnico.intermediario;
      case NivelExperiencia.avancado:
        return NivelTecnico.avancado;
    }
  }
}
