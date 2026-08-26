import 'package:flutter_test/flutter_test.dart';
import 'package:reps/features/library/data/library_repository.dart';
import 'package:reps/domain/entities/exercise.dart';

/// Cobre o E0 do recomendador: metadados de exercicio (nivel tecnico, tipo,
/// flag de recomendavel). Roda sobre os 100 exercicios canonicos em memoria.
void main() {
  final repo = LibraryRepository();
  final seed = repo
      .all()
      .where((e) => e.id.startsWith('seed:'))
      .toList(growable: false);

  test('os 100 canonicos sao recomendaveis e ativos', () {
    expect(seed.length, 100);
    expect(seed.every((e) => e.recomendavel), isTrue);
    expect(seed.every((e) => e.ativo), isTrue);
  });

  test('tipo deriva do padrao de movimento', () {
    final supino = repo.findBySlug('supino_reto_barra')!;
    final rosca = repo.findBySlug('rosca_direta_barra')!;
    expect(supino.tipo, TipoExercicio.multiarticular);
    expect(rosca.tipo, TipoExercicio.isolador);
  });

  test('nivel: isoladores e guiados sao iniciante (RN-014)', () {
    // CA-001: iniciante recebe leg press, supino maquina, hip thrust etc.
    for (final slug in [
      'leg_press_45',
      'supino_maquina',
      'hip_thrust_maquina',
      'agachamento_smith',
      'rosca_direta_barra',
      'cadeira_extensora',
      'puxada_frente_pegada_pronada',
    ]) {
      expect(
        repo.findBySlug(slug)!.nivelTecnico,
        NivelTecnico.iniciante,
        reason: slug,
      );
    }
  });

  test('nivel: compostos com peso livre sao intermediario', () {
    for (final slug in [
      'supino_reto_barra',
      'remada_curvada_barra',
      'desenvolvimento_militar_barra',
      'stiff_barra',
      'agachamento_bulgaro_halter',
    ]) {
      expect(
        repo.findBySlug(slug)!.nivelTecnico,
        NivelTecnico.intermediario,
        reason: slug,
      );
    }
  });

  test('nivel: complexos/alto risco sao avancado (RN-036)', () {
    for (final slug in [
      'levantamento_terra_convencional',
      'agachamento_livre_barra',
      'agachamento_frontal_barra',
      'bom_dia_barra',
      'agachamento_salto',
      'box_jump',
      'turkish_get_up',
      'thruster_halter',
    ]) {
      expect(
        repo.findBySlug(slug)!.nivelTecnico,
        NivelTecnico.avancado,
        reason: slug,
      );
    }
  });

  test('barra fixa e paralelas exigem base de forca (intermediario)', () {
    for (final slug in [
      'barra_fixa_pronada',
      'barra_fixa_supinada',
      'paralelas_peito',
    ]) {
      expect(
        repo.findBySlug(slug)!.nivelTecnico,
        NivelTecnico.intermediario,
        reason: slug,
      );
    }
  });
}
