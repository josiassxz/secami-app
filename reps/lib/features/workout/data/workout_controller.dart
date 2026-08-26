import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/health/health_service.dart';
import '../../../core/logging/observability.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../../domain/entities/grupo_exercicio.dart';
import '../../../domain/entities/planned_set.dart';
import '../../../domain/usecases/pr_detector.dart';
import '../../auth/data/auth_providers.dart';
import '../../routines/data/routine_providers.dart';
import '../../settings/data/settings_providers.dart';

const _uuid = Uuid();

/// Item planejado da sessao corrente (uma "linha" do treino: serie X do exercicio Y).
class ActiveSetSlot {
  const ActiveSetSlot({
    required this.id,
    required this.exerciseId,
    required this.routineExerciseId,
    required this.ordemNoTreino,
    required this.numeroSerie,
    required this.planned,
    this.substituidoDeExerciseId,
    this.grupoId,
    this.grupoTipo = 'normal',
    this.round = 0,
    this.completed = false,
    this.skipped = false,
    this.repsRealizadas,
    this.cargaKg,
    this.rpe,
    this.duracaoSegundos,
    this.motivoPulo,
    this.setLogId,
  });

  final String id;
  final String exerciseId;
  final String routineExerciseId;
  final int ordemNoTreino;
  final int numeroSerie;
  final PlannedSet planned;
  final String? substituidoDeExerciseId;

  /// Agrupamento bi-set/circuito (Feature A). `grupoId` null = exercicio solo.
  /// `round` = rodada (0-based) dentro do bloco intercalado.
  final String? grupoId;
  final String grupoTipo;
  final int round;

  // Estado de execucao — imutavel (4.4). O rebuild da UI depende da troca de
  // referencia da lista de slots; mutar um slot in-place nao atualizava a tela
  // sem avancar o cursor. `copyWith` produz um novo slot e o caller troca a
  // referencia na lista.
  final bool completed;
  final bool skipped;
  final int? repsRealizadas;
  final double? cargaKg;
  final int? rpe;
  final int? duracaoSegundos;
  final String? motivoPulo;
  final String? setLogId;

  ActiveSetSlot copyWith({
    String? exerciseId,
    PlannedSet? planned,
    String? substituidoDeExerciseId,
    bool? completed,
    bool? skipped,
    int? repsRealizadas,
    double? cargaKg,
    int? rpe,
    int? duracaoSegundos,
    String? motivoPulo,
    String? setLogId,
  }) {
    return ActiveSetSlot(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      routineExerciseId: routineExerciseId,
      ordemNoTreino: ordemNoTreino,
      numeroSerie: numeroSerie,
      planned: planned ?? this.planned,
      substituidoDeExerciseId:
          substituidoDeExerciseId ?? this.substituidoDeExerciseId,
      grupoId: grupoId,
      grupoTipo: grupoTipo,
      round: round,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      repsRealizadas: repsRealizadas ?? this.repsRealizadas,
      cargaKg: cargaKg ?? this.cargaKg,
      rpe: rpe ?? this.rpe,
      duracaoSegundos: duracaoSegundos ?? this.duracaoSegundos,
      motivoPulo: motivoPulo ?? this.motivoPulo,
      setLogId: setLogId ?? this.setLogId,
    );
  }
}

class ActiveWorkoutState {
  ActiveWorkoutState({
    required this.sessionId,
    required this.routineId,
    required this.slots,
    required this.cursor,
  });

  final String sessionId;
  final String? routineId;
  final List<ActiveSetSlot> slots;
  final int cursor;

  bool get isFinished => cursor >= slots.length;
  ActiveSetSlot? get current => isFinished ? null : slots[cursor];

  int get completedCount => slots.where((s) => s.completed).length;
  int get skippedCount => slots.where((s) => s.skipped).length;

  ActiveWorkoutState copyWith({List<ActiveSetSlot>? slots, int? cursor}) {
    return ActiveWorkoutState(
      sessionId: sessionId,
      routineId: routineId,
      slots: slots ?? this.slots,
      cursor: cursor ?? this.cursor,
    );
  }
}

/// Especificacao minima de um exercicio da rotina para montar os slots.
/// Desacopla a logica de intercalamento da row do Drift (testavel em isolado).
class SlotSpec {
  const SlotSpec({
    required this.id,
    required this.exerciseId,
    required this.series,
    this.grupoId,
    this.grupoTipo = 'normal',
    this.rounds,
  });

  final String id;
  final String exerciseId;
  final List<PlannedSet> series;
  final String? grupoId;
  final String grupoTipo;
  final int? rounds;
}

/// Monta os slots da sessao a partir das specs, intercalando blocos bi-set/
/// circuito. `ordemNoTreino` = indice absoluto do exercicio na lista (preserva
/// a identidade do exercicio para insights/PR mesmo intercalado).
List<ActiveSetSlot> buildActiveSlots(
  List<SlotSpec> specs, {
  String Function()? idGen,
}) {
  final newId = idGen ?? () => _uuid.v4();
  List<PlannedSet> effOf(SlotSpec s) =>
      s.series.isEmpty ? const [PlannedSet(numero: 1)] : s.series;

  final slots = <ActiveSetSlot>[];
  var i = 0;
  while (i < specs.length) {
    final spec = specs[i];
    final tipo = GrupoTipo.fromString(spec.grupoTipo);
    // Bloco solo (normal): serie a serie, como sempre.
    if (spec.grupoId == null || !tipo.intercalado) {
      for (final p in effOf(spec)) {
        slots.add(
          ActiveSetSlot(
            id: newId(),
            exerciseId: spec.exerciseId,
            routineExerciseId: spec.id,
            ordemNoTreino: i,
            numeroSerie: p.numero,
            planned: p,
          ),
        );
      }
      i++;
      continue;
    }
    // Bloco intercalado: junta exercicios consecutivos com o mesmo grupoId.
    final gid = spec.grupoId;
    final membros = <int>[];
    var j = i;
    while (j < specs.length && specs[j].grupoId == gid) {
      membros.add(j);
      j++;
    }
    final seriesByIdx = {for (final idx in membros) idx: effOf(specs[idx])};
    final maxSeries = seriesByIdx.values
        .map((s) => s.length)
        .fold(0, (a, b) => a > b ? a : b);
    final rounds = tipo == GrupoTipo.circuito
        ? (spec.rounds ?? maxSeries).clamp(1, 99).toInt()
        : maxSeries;
    for (var r = 0; r < rounds; r++) {
      for (final idx in membros) {
        final series = seriesByIdx[idx]!;
        PlannedSet? p;
        if (r < series.length) {
          p = series[r];
        } else if (tipo == GrupoTipo.circuito && series.isNotEmpty) {
          // Circuito com mais rodadas que series: repete a config da ultima.
          p = series.last;
        }
        if (p == null) continue;
        slots.add(
          ActiveSetSlot(
            id: newId(),
            exerciseId: specs[idx].exerciseId,
            routineExerciseId: specs[idx].id,
            ordemNoTreino: idx,
            numeroSerie: r + 1,
            planned: p,
            grupoId: gid,
            grupoTipo: tipo.name,
            round: r,
          ),
        );
      }
    }
    i = j;
  }
  return slots;
}

/// Chave do "bloco" de um slot: o grupo (bi-set/circuito) ou o proprio
/// exercicio quando solo. Usada para pular o bloco inteiro.
String slotBlockKey(ActiveSetSlot s) => s.grupoId ?? 'solo:${s.ordemNoTreino}';

class WorkoutController extends Notifier<ActiveWorkoutState?> {
  @override
  ActiveWorkoutState? build() {
    ref.onDispose(_prEvents.close);
    return null;
  }

  final _prEvents = StreamController<List<PrEvent>>.broadcast();
  Stream<List<PrEvent>> get prStream => _prEvents.stream;

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String get _userId => ref.read(effectiveUserIdProvider);

  List<ActiveSetSlot> _buildSlots(List<RoutineExerciseRow> rows) {
    return buildActiveSlots([
      for (final re in rows)
        SlotSpec(
          id: re.id,
          exerciseId: re.exerciseId,
          series: PlannedSet.decode(re.seriesPlanejadas),
          grupoId: re.grupoId,
          grupoTipo: re.grupoTipo,
          rounds: re.rounds,
        ),
    ]);
  }

  /// Cria nova sessao a partir de uma rotina. Retorna o sessionId.
  Future<String> startFromRoutine(String routineId) async {
    final routine = await ref.read(routineServiceProvider).findById(routineId);
    final routineExercises = await ref
        .read(routineServiceProvider)
        .exercisesOf(routineId);

    final sessionId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(
        id: sessionId,
        userId: _userId,
        routineId: Value(routineId),
        iniciadoEm: Value(now),
      ),
    );

    final slots = _buildSlots(routineExercises);

    state = ActiveWorkoutState(
      sessionId: sessionId,
      routineId: routine?.id,
      slots: slots,
      cursor: 0,
    );

    await Observability.track('workout_started', {
      'routine_id': routineId,
      'num_slots': slots.length,
    });
    return sessionId;
  }

  // Reentrancia: toque duplo dispara confirmSet/skipSet 2x sobre o mesmo slot
  // (o cursor so avanca apos os awaits). Sem guard, cada invocacao gera um
  // setLogId diferente => linha duplicada em set_logs (volume inflado, PR
  // falso). O guard torna a 2a invocacao concorrente um no-op.
  bool _confirming = false;

  Future<void> confirmSet({
    int? repsRealizadas,
    required double cargaKg,
    int? rpe,
    int? duracaoSegundos,
  }) async {
    if (_confirming) return;
    _confirming = true;
    try {
      final s = state;
      if (s == null || s.current == null) return;
      final slot = s.current!;
      final setLogId = slot.setLogId ?? _uuid.v4();
      final novo = slot.copyWith(
        completed: true,
        skipped: false,
        repsRealizadas: repsRealizadas,
        cargaKg: cargaKg,
        rpe: rpe,
        duracaoSegundos: duracaoSegundos,
        setLogId: setLogId,
      );

      await _db.setLogDao.upsert(
        SetLogsCompanion.insert(
          id: setLogId,
          sessionId: s.sessionId,
          exerciseId: slot.exerciseId,
          ordemNoTreino: slot.ordemNoTreino,
          numeroSerie: slot.numeroSerie,
          repsRealizadas: Value(repsRealizadas),
          cargaKg: Value(cargaKg),
          duracaoSegundos: Value(duracaoSegundos),
          rpe: Value(rpe),
          tipoSerie: Value(slot.planned.tipoSerie.name),
          executada: const Value(true),
          substituidoDeExerciseId: Value(slot.substituidoDeExerciseId),
        ),
      );

      await Observability.track('set_logged', {
        'exercise_id': slot.exerciseId,
        'reps': ?repsRealizadas,
        'carga_kg': cargaKg,
        'duracao_segundos': ?duracaoSegundos,
        'tipo_serie': slot.planned.tipoSerie.name,
      });

      // Deteccao de PR (in-band, mas nao bloqueia o avanco do treino). Serie
      // por reps -> carga/volume/reps; serie por tempo -> maior duracao +
      // carga (E6).
      final detector = ref.read(prDetectorProvider);
      List<PrEvent> prs = const [];
      if (repsRealizadas != null) {
        prs = await detector.detect(
          exerciseId: slot.exerciseId,
          reps: repsRealizadas,
          cargaKg: cargaKg,
          currentSetLogId: setLogId,
        );
      } else if (duracaoSegundos != null) {
        prs = await detector.detectTimed(
          exerciseId: slot.exerciseId,
          duracaoSegundos: duracaoSegundos,
          cargaKg: cargaKg,
          currentSetLogId: setLogId,
        );
      }
      if (prs.isNotEmpty) {
        _prEvents.add(prs);
        for (final pr in prs) {
          await Observability.track('pr_detected', {
            'exercise_id': pr.exerciseId,
            'tipo': pr.tipo.name,
            'valor': pr.valor,
          });
        }
      }

      final novosSlots = [...s.slots]..[s.cursor] = novo;
      state = s.copyWith(slots: novosSlots, cursor: s.cursor + 1);
    } finally {
      _confirming = false;
    }
  }

  Future<void> skipSet(String motivo) async {
    if (_confirming) return;
    _confirming = true;
    try {
      final s = state;
      if (s == null || s.current == null) return;
      final slot = s.current!;
      final setLogId = slot.setLogId ?? _uuid.v4();
      final novo = slot.copyWith(
        skipped: true,
        completed: false,
        motivoPulo: motivo,
        setLogId: setLogId,
      );

      await _db.setLogDao.upsert(
        SetLogsCompanion.insert(
          id: setLogId,
          sessionId: s.sessionId,
          exerciseId: slot.exerciseId,
          ordemNoTreino: slot.ordemNoTreino,
          numeroSerie: slot.numeroSerie,
          executada: const Value(false),
          motivoPulo: Value(motivo),
          tipoSerie: Value(slot.planned.tipoSerie.name),
        ),
      );

      await Observability.track('set_skipped', {'motivo': motivo});

      final novosSlots = [...s.slots]..[s.cursor] = novo;
      state = s.copyWith(slots: novosSlots, cursor: s.cursor + 1);
    } finally {
      _confirming = false;
    }
  }

  /// Substitui o exercicio do slot atual (e todos os slots subsequentes do mesmo
  /// ordem_no_treino) pelo novo exercicio. Herda series planejadas; carga vem
  /// do historico do substituto ou do alvo original.
  Future<void> substituteCurrent({
    required String newExerciseId,
    double? cargaAlvo,
  }) async {
    final s = state;
    if (s == null || s.current == null) return;
    final cur = s.current!;
    final novosSlots = [...s.slots];
    // Num bloco intercalado os slots do mesmo exercicio nao sao contiguos
    // (alternam com os parceiros do grupo), entao varremos ate o fim sem `break`
    // e aplicamos so nos que batem o ordemNoTreino.
    for (var i = s.cursor; i < novosSlots.length; i++) {
      if (novosSlots[i].ordemNoTreino != cur.ordemNoTreino) continue;
      final old = novosSlots[i];
      final patched = ActiveSetSlot(
        id: old.id,
        exerciseId: newExerciseId,
        routineExerciseId: old.routineExerciseId,
        ordemNoTreino: old.ordemNoTreino,
        numeroSerie: old.numeroSerie,
        planned: old.planned.copyWith(
          cargaAlvo: cargaAlvo,
          clearCargaAlvo: cargaAlvo == null,
        ),
        substituidoDeExerciseId: old.substituidoDeExerciseId ?? old.exerciseId,
        grupoId: old.grupoId,
        grupoTipo: old.grupoTipo,
        round: old.round,
        setLogId: old.setLogId,
      );
      novosSlots[i] = patched;
    }
    state = s.copyWith(slots: novosSlots);
  }

  /// Volta uma serie (permite corrigir uma serie ja registrada).
  /// O slot anterior reabre com os valores logados; reconfirmar faz upsert
  /// no mesmo setLogId e avanca de novo.
  void goBackOneSet() {
    final s = state;
    if (s == null || s.cursor == 0) return;
    state = s.copyWith(cursor: s.cursor - 1);
  }

  /// Pula o cursor direto para um slot especifico (modo lista do treino).
  /// Slot ja concluido reabre em edicao — mesma semantica do goBackOneSet.
  void jumpToSlot(String slotId) {
    final s = state;
    if (s == null) return;
    final i = s.slots.indexWhere((sl) => sl.id == slotId);
    if (i < 0) return;
    state = s.copyWith(cursor: i);
  }

  /// Pula direto pro proximo bloco. Para exercicio solo, pula as series
  /// restantes dele; para bi-set/circuito, pula o grupo intercalado inteiro.
  void jumpToNextExercise() {
    final s = state;
    if (s == null || s.current == null) return;
    final key = slotBlockKey(s.current!);
    var i = s.cursor;
    while (i < s.slots.length && slotBlockKey(s.slots[i]) == key) {
      i++;
    }
    state = s.copyWith(cursor: i);
  }

  Future<void> finish() async {
    final s = state;
    if (s == null) return;
    final now = DateTime.now().toUtc();
    final session = await _db.sessionDao.findById(s.sessionId);
    if (session != null && session.iniciadoEm.isBefore(now)) {
      await _db.sessionDao.finalize(
        id: s.sessionId,
        finalizadoEm: now,
        duracaoSegundos: now.difference(session.iniciadoEm).inSeconds,
      );
      // Exporta para Health Connect / Apple Health se o usuario habilitou.
      // Usa o nome da rotina como titulo da atividade (o que o Gymrats exibe).
      if (ref.read(healthIntegrationProvider)) {
        String? titulo;
        final rid = s.routineId;
        if (rid != null) {
          final routine = await ref.read(routineServiceProvider).findById(rid);
          titulo = routine?.nome;
        }
        unawaited(
          ref
              .read(healthServiceProvider)
              .exportWorkout(
                inicio: session.iniciadoEm,
                fim: now,
                titulo: titulo,
              ),
        );
      }
    }
    await Observability.track('workout_completed', {
      'duracao_segundos': session == null
          ? 0
          : now.difference(session.iniciadoEm).inSeconds,
      'num_series': s.completedCount,
      'num_puladas': s.skippedCount,
    });
    state = null;
  }

  void cancel() {
    state = null;
  }
}

final workoutControllerProvider =
    NotifierProvider<WorkoutController, ActiveWorkoutState?>(
      WorkoutController.new,
    );
