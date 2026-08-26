import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/library/data/library_repository.dart';
import 'package:reps/domain/entities/exercise.dart';
import 'package:reps/features/recommender/domain/engine/safety_gate.dart';
import 'package:reps/features/recommender/domain/engine/workout_recommender.dart';
import 'package:reps/features/recommender/domain/questionario.dart';
import 'package:reps/features/recommender/domain/treino_recomendado.dart';
import 'package:reps/features/recommender/domain/triagem.dart';

void main() {
  final biblioteca = LibraryRepository().all();
  const motor = WorkoutRecommender();

  PerfilQuestionario perfil({
    Objetivo objetivo = Objetivo.hipertrofia,
    PrioridadeMuscular prioridade = PrioridadeMuscular.corpoTodo,
    NivelExperiencia experiencia = NivelExperiencia.iniciante,
    int dias = 3,
    int minutos = 45,
    LocalTreino local = LocalTreino.academiaCompleta,
    Set<Equipamento>? equip,
    Set<GrupoMuscular> restricoes = const {},
    Set<String> evitados = const {},
    bool fadiga = false,
  }) {
    return PerfilQuestionario(
      objetivo: objetivo,
      prioridade: prioridade,
      experiencia: experiencia,
      diasPorSemana: dias,
      minutosPorSessao: minutos,
      local: local,
      equipamentos: equip ?? local.equipamentosPadrao,
      restricoesGrupos: restricoes,
      exerciciosEvitados: evitados,
      fadigaElevada: fadiga,
    );
  }

  test('CA-001: 3d iniciante hipertrofia -> full body, volume moderado', () {
    final t = motor.gerar(
      perfil: perfil(),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    expect(t.bloqueado, isFalse);
    expect(t.divisao, TipoDivisao.fullBodyABC);
    expect(t.dias.length, 3);
    for (final d in t.dias) {
      expect(d.exercicios, isNotEmpty);
      // iniciante: nenhum exercicio avancado.
      for (final e in d.exercicios) {
        expect(e.exercicio.nivelTecnico, isNot(NivelTecnico.avancado));
        expect(e.exercicio.recomendavel, isTrue);
      }
    }
  });

  test('CA-002: condicao cardiaca -> nao gera treino, encaminha', () {
    final t = motor.gerar(
      perfil: perfil(),
      triagem: const RespostasTriagem(condicaoCardiaca: true),
      biblioteca: biblioteca,
    );
    expect(t.bloqueado, isTrue);
    expect(t.triagem.nivel, TriagemNivel.encaminhar);
    expect(t.dias, isEmpty);
    expect(t.justificativa.toLowerCase(), contains('avalia'));
  });

  test('SafetyGate bloqueia todas as condicoes criticas (RN-002)', () {
    final criticas = <RespostasTriagem>[
      const RespostasTriagem(condicaoCardiaca: true),
      const RespostasTriagem(pressaoAltaNaoControlada: true),
      const RespostasTriagem(dorNoPeito: true),
      const RespostasTriagem(tonturaDesmaio: true),
      const RespostasTriagem(doencaCronicaNaoAcompanhada: true),
      const RespostasTriagem(gestacaoRisco: true),
      const RespostasTriagem(lesaoRelevante: true),
      const RespostasTriagem(restricaoMedica: true),
    ];
    for (final c in criticas) {
      final r = SafetyGate.avaliar(c);
      expect(r.nivel, TriagemNivel.encaminhar);
      expect(r.bloqueiaIntenso, isTrue);
    }
  });

  test('alerta leve -> liberado com cautela e conservador', () {
    final t = motor.gerar(
      perfil: perfil(experiencia: NivelExperiencia.avancado),
      triagem: const RespostasTriagem(usaMedicamentos: true),
      biblioteca: biblioteca,
    );
    expect(t.bloqueado, isFalse);
    expect(t.triagem.nivel, TriagemNivel.liberadoComCautela);
    expect(t.entradas['conservador'], isTrue);
    // teto rebaixado para iniciante (sem exercicios avancados).
    for (final d in t.dias) {
      for (final e in d.exercicios) {
        expect(e.exercicio.nivelTecnico, NivelTecnico.iniciante);
      }
    }
  });

  test('CA-003: casa sem equipamento -> so peso corporal compativel', () {
    final t = motor.gerar(
      perfil: perfil(
        local: LocalTreino.arLivre,
        equip: {Equipamento.peso_corporal},
      ),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    for (final d in t.dias) {
      for (final e in d.exercicios) {
        expect(e.exercicio.equipamento, Equipamento.peso_corporal);
      }
    }
  });

  test('CA-004: prioridade pernas/gluteos aumenta volume inferior', () {
    final t = motor.gerar(
      perfil: perfil(
        dias: 4,
        prioridade: PrioridadeMuscular.pernasGluteos,
        experiencia: NivelExperiencia.intermediario,
      ),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    final inferior = {
      GrupoMuscular.quadriceps,
      GrupoMuscular.posterior,
      GrupoMuscular.gluteos,
      GrupoMuscular.panturrilha,
    };
    var infCount = 0;
    var supCount = 0;
    for (final d in t.dias) {
      for (final e in d.exercicios) {
        if (inferior.contains(e.exercicio.grupoPrimario)) {
          infCount++;
        } else {
          supCount++;
        }
      }
    }
    expect(infCount, greaterThan(0));
    // superiores nao sao zerados (RN-009).
    expect(supCount, greaterThan(0));
  });

  test('CA-005: exercicio evitado nao aparece, substituicao equivalente', () {
    final t = motor.gerar(
      perfil: perfil(evitados: {'supino_reto_barra'}),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    final slugs = t.dias
        .expand((d) => d.exercicios.map((e) => e.exercicio.slug))
        .toSet();
    expect(slugs, isNot(contains('supino_reto_barra')));
  });

  test('CA-006: fadiga elevada reduz volume e marca alerta', () {
    final normal = motor.gerar(
      perfil: perfil(experiencia: NivelExperiencia.intermediario),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    final fadigado = motor.gerar(
      perfil: perfil(experiencia: NivelExperiencia.intermediario, fadiga: true),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    int seriesDe(TreinoRecomendado t) => t.dias
        .expand((d) => d.exercicios)
        .fold(0, (a, e) => a + e.series.length);
    expect(seriesDe(fadigado), lessThan(seriesDe(normal)));
    expect(
      fadigado.alertas.any((a) => a.toLowerCase().contains('fadiga')),
      isTrue,
    );
  });

  test('matriz de divisao 2..6 dias (RN-018..022)', () {
    final esperado = {
      2: TipoDivisao.fullBodyAB,
      3: TipoDivisao.fullBodyABC, // iniciante
      4: TipoDivisao.upperLower2x,
      5: TipoDivisao.upperLowerPonto,
      6: TipoDivisao.ppl2x,
    };
    esperado.forEach((dias, tipo) {
      final exp = dias >= 5
          ? NivelExperiencia.avancado
          : NivelExperiencia.iniciante;
      final t = motor.gerar(
        perfil: perfil(dias: dias, experiencia: exp),
        triagem: const RespostasTriagem.semAlertas(),
        biblioteca: biblioteca,
      );
      expect(t.divisao, tipo, reason: '$dias dias');
      expect(t.dias.length, dias);
    });
  });

  test('RN-033: compostos vem antes de isoladores no dia', () {
    final t = motor.gerar(
      perfil: perfil(dias: 4, experiencia: NivelExperiencia.intermediario),
      triagem: const RespostasTriagem.semAlertas(),
      biblioteca: biblioteca,
    );
    for (final d in t.dias) {
      var viuIsolador = false;
      for (final e in d.exercicios) {
        if (e.exercicio.tipo == TipoExercicio.isolador) {
          viuIsolador = true;
        } else {
          expect(
            viuIsolador,
            isFalse,
            reason: 'composto apos isolador em ${d.nome}',
          );
        }
      }
    }
  });

  test('forca usa menos reps e mais descanso que hipertrofia (RN-027)', () {
    PlannedSetSummary resumo(Objetivo o) {
      final t = motor.gerar(
        perfil: perfil(
          objetivo: o,
          experiencia: NivelExperiencia.intermediario,
        ),
        triagem: const RespostasTriagem.semAlertas(),
        biblioteca: biblioteca,
      );
      final first = t.dias.first.exercicios.first.series.first;
      return PlannedSetSummary(first.repsAlvoMax, first.descansoSegundos);
    }

    final forca = resumo(Objetivo.forca);
    final hiper = resumo(Objetivo.hipertrofia);
    expect(forca.reps, lessThan(hiper.reps));
    expect(forca.descanso, greaterThan(hiper.descanso));
  });
}

class PlannedSetSummary {
  PlannedSetSummary(this.reps, this.descanso);
  final int reps;
  final int descanso;
}
