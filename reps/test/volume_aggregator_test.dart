import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/domain/usecases/volume_aggregator.dart';

final _epoch = DateTime(2026, 1, 1);

WorkoutSessionRow _session(String id, DateTime iniciadoEm) => WorkoutSessionRow(
  id: id,
  userId: 'u1',
  iniciadoEm: iniciadoEm,
  updatedAt: _epoch,
  dirty: false,
);

SetLogRow _log(
  String id,
  String sessionId, {
  double? cargaKg,
  int? repsRealizadas,
  bool executada = true,
}) => SetLogRow(
  id: id,
  sessionId: sessionId,
  exerciseId: 'seed:supino_reto_barra',
  ordemNoTreino: 0,
  numeroSerie: 1,
  repsRealizadas: repsRealizadas,
  cargaKg: cargaKg,
  tipoSerie: 'normal',
  executada: executada,
  criadoEm: _epoch,
  updatedAt: _epoch,
  dirty: false,
);

void main() {
  final from = DateTime(2026, 6, 1);
  final to = DateTime(2026, 6, 8); // [from, to)

  test('soma carga*reps dos logs dentro da janela', () {
    final s = _session('s1', DateTime(2026, 6, 3));
    final logs = [
      _log('l1', 's1', cargaKg: 50, repsRealizadas: 10), // 500
      _log('l2', 's1', cargaKg: 40, repsRealizadas: 5), // 200
    ];
    expect(
      volumeExecutado(logs: logs, sessionById: {s.id: s}, from: from, to: to),
      700,
    );
  });

  test('sessao fora da janela e ignorada', () {
    final dentro = _session('s1', DateTime(2026, 6, 3));
    final fora = _session('s2', DateTime(2026, 5, 30));
    final logs = [
      _log('l1', 's1', cargaKg: 50, repsRealizadas: 10), // 500 dentro
      _log('l2', 's2', cargaKg: 60, repsRealizadas: 10), // fora
    ];
    expect(
      volumeExecutado(
        logs: logs,
        sessionById: {dentro.id: dentro, fora.id: fora},
        from: from,
        to: to,
      ),
      500,
    );
  });

  test('janela [from, to): inclui from, exclui to', () {
    final noFrom = _session('s1', from);
    final noTo = _session('s2', to);
    final logs = [
      _log('l1', 's1', cargaKg: 10, repsRealizadas: 10), // 100 incluso
      _log('l2', 's2', cargaKg: 99, repsRealizadas: 99), // excluso
    ];
    expect(
      volumeExecutado(
        logs: logs,
        sessionById: {noFrom.id: noFrom, noTo.id: noTo},
        from: from,
        to: to,
      ),
      100,
    );
  });

  test('logs com executada=false sao ignorados', () {
    final s = _session('s1', DateTime(2026, 6, 3));
    final logs = [
      _log('l1', 's1', cargaKg: 50, repsRealizadas: 10, executada: false),
    ];
    expect(
      volumeExecutado(logs: logs, sessionById: {s.id: s}, from: from, to: to),
      0,
    );
  });

  test('carga ou reps null contam como 0', () {
    final s = _session('s1', DateTime(2026, 6, 3));
    final logs = [
      _log('l1', 's1', cargaKg: null, repsRealizadas: 10),
      _log('l2', 's1', cargaKg: 50, repsRealizadas: null),
    ];
    expect(
      volumeExecutado(logs: logs, sessionById: {s.id: s}, from: from, to: to),
      0,
    );
  });

  test('log sem sessao no mapa e ignorado', () {
    final logs = [_log('l1', 'ausente', cargaKg: 50, repsRealizadas: 10)];
    expect(
      volumeExecutado(logs: logs, sessionById: const {}, from: from, to: to),
      0,
    );
  });

  test('lista de logs vazia retorna 0', () {
    expect(
      volumeExecutado(
        logs: const [],
        sessionById: const {},
        from: from,
        to: to,
      ),
      0,
    );
  });
}
