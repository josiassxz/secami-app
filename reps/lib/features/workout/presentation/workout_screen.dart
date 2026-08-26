import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/units/weight_unit.dart';
import '../../../domain/entities/exercise_id.dart';
import '../../../domain/entities/grupo_exercicio.dart';
import '../../../domain/usecases/pr_detector.dart';
import '../../../domain/usecases/progression_engine.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/exercise_thumb.dart';
import '../../settings/data/settings_providers.dart';
import '../data/progression_providers.dart';
import '../data/workout_controller.dart';
import 'rest_timer_overlay.dart';
import 'substitute_sheet.dart';
import 'timed_exercise_overlay.dart';
part 'widgets/workout_screen_widgets.dart';

/// Formata segundos como mm:ss (ex.: 45 -> "0:45", 90 -> "1:30").
String _fmtMmss(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  final _repsCtrl = TextEditingController();
  final _cargaCtrl = TextEditingController();
  int? _rpe;
  // Alterna entre o modo foco (serie atual) e a lista do treino inteiro.
  bool _listView = false;
  // Trava os botoes de submit enquanto uma serie esta sendo registrada. Sem
  // isso, um toque duplo dispara confirmSet/skipSet 2x (o controller so avanca
  // o cursor apos os awaits) => serie duplicada em set_logs.
  bool _submitting = false;

  String _lastSlotId = '';
  StreamSubscription<void>? _prSub;
  final _startPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playStartSound();
    final controller = ref.read(workoutControllerProvider.notifier);
    _prSub = controller.prStream.listen((events) {
      if (!mounted || events.isEmpty) return;
      final tipos = events.map((e) => e.tipo.label).join(' · ');
      final scheme = Theme.of(context).colorScheme;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: scheme.secondary,
          leading: Icon(
            Icons.emoji_events,
            size: 20,
            color: scheme.onSecondary,
          ),
          content: Text(
            'PR — $tipos',
            style: TextStyle(
              color: scheme.onSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: Text('OK', style: TextStyle(color: scheme.onSecondary)),
            ),
          ],
        ),
      );
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) messenger.hideCurrentMaterialBanner();
      });
    });
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _cargaCtrl.dispose();
    _prSub?.cancel();
    unawaited(_startPlayer.dispose());
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _playStartSound() async {
    final settings = ref.read(timerSettingsProvider);
    if (!settings.alertaInicio) return;
    try {
      const assetKey = 'assets/sounds/irinairinafomicheva-start-13691.mp3';
      final data = await rootBundle.load(assetKey);
      if (data.lengthInBytes > 0) {
        await _startPlayer.play(
          AssetSource('sounds/irinairinafomicheva-start-13691.mp3'),
        );
      }
    } catch (_) {
      // Asset ausente ou erro de playback — silencioso.
    }
  }

  void _hydrateFromCurrent(ActiveWorkoutState s) {
    final cur = s.current;
    if (cur == null) return;
    if (cur.id == _lastSlotId) return;
    _lastSlotId = cur.id;
    final unit = ref.read(weightUnitProvider);
    // Slot ja registrado (edicao): reabre com o que foi feito.
    if (cur.completed) {
      _repsCtrl.text = '${cur.repsRealizadas ?? 0}';
      _cargaCtrl.text = cur.cargaKg == null ? '' : unit.format(cur.cargaKg!);
      _rpe = cur.rpe;
      return;
    }
    final mid = (cur.planned.repsAlvoMin + cur.planned.repsAlvoMax) ~/ 2;
    // Pré-preenche com a série anterior do mesmo exercício, se já foi feita.
    final prev = s.slots
        .where(
          (sl) =>
              sl.ordemNoTreino == cur.ordemNoTreino &&
              sl.numeroSerie == cur.numeroSerie - 1 &&
              sl.completed,
        )
        .firstOrNull;
    if (prev != null) {
      _repsCtrl.text = '${prev.repsRealizadas ?? mid}';
      _cargaCtrl.text = prev.cargaKg == null ? '' : unit.format(prev.cargaKg!);
    } else {
      _repsCtrl.text = '$mid';
      _cargaCtrl.text = cur.planned.cargaAlvo == null
          ? ''
          : unit.format(cur.planned.cargaAlvo!);
    }
    _rpe = null;
  }

  /// Recebe carga canonica (kg) e exibe na unidade preferida.
  void _applyCargaKg(double kg) {
    _cargaCtrl.text = ref.read(weightUnitProvider).format(kg);
    _cargaCtrl.selection = TextSelection.collapsed(
      offset: _cargaCtrl.text.length,
    );
    HapticFeedback.selectionClick();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final cur = ref.read(workoutControllerProvider)?.current;
    if (cur == null) return;
    final reps = int.tryParse(_repsCtrl.text) ?? 0;
    final entrada =
        double.tryParse(_cargaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    // Input esta na unidade de exibicao; persiste sempre em kg.
    final carga = ref.read(weightUnitProvider).toKg(entrada);
    setState(() => _submitting = true);
    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .confirmSet(repsRealizadas: reps, cargaKg: carga, rpe: _rpe);
      await _maybeRest(cur);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Abre o descanso, exceto quando a proxima serie e do mesmo grupo e mesma
  /// rodada (bi-set/circuito não descansam entre exercícios da rodada).
  Future<void> _maybeRest(ActiveSetSlot justCompleted) async {
    if (!mounted) return;
    final next = ref.read(workoutControllerProvider)?.current;
    if (next == null) return; // treino acabou
    final mesmaRodada =
        justCompleted.grupoId != null &&
        next.grupoId == justCompleted.grupoId &&
        next.round == justCompleted.round;
    if (mesmaRodada) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RestTimerOverlay(
          durationSeconds: justCompleted.planned.descansoSegundos,
        ),
      ),
    );
  }

  /// Fluxo de exercicio por tempo: abre o timer regressivo, registra a duracao
  /// executada e segue para o descanso (igual ao fluxo de reps).
  Future<void> _confirmTimed(int alvoSeg, String? nome) async {
    if (_submitting) return;
    final cur = ref.read(workoutControllerProvider)?.current;
    if (cur == null) return;
    setState(() => _submitting = true);
    try {
      final duracao = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              TimedExerciseOverlay(alvoSegundos: alvoSeg, nomeExercicio: nome),
        ),
      );
      if (duracao == null || !mounted) return;
      final entrada =
          double.tryParse(_cargaCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final carga = ref.read(weightUnitProvider).toKg(entrada);
      await ref
          .read(workoutControllerProvider.notifier)
          .confirmSet(cargaKg: carga, duracaoSegundos: duracao, rpe: _rpe);
      await _maybeRest(cur);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    if (_submitting) return;
    final scheme = Theme.of(context).colorScheme;
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Por que pular?',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
            ),
            for (final m in const [
              ('equipamento_ocupado', 'Equipamento ocupado'),
              ('fadiga', 'Fadiga'),
              ('lesao', 'Lesão'),
              ('dor', 'Dor'),
              ('outro', 'Outro'),
            ])
              ListTile(
                title: Text(
                  m.$2,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => Navigator.of(context).pop(m.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (motivo == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(workoutControllerProvider.notifier).skipSet(motivo);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _substitute() async {
    final s = ref.read(workoutControllerProvider);
    final cur = s?.current;
    if (cur == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => SubstituteSheet(originalExerciseId: cur.exerciseId),
    );
    _lastSlotId = '';
  }

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar treino?'),
        content: const Text('Você pode finalizar mesmo sem completar tudo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workoutControllerProvider.notifier).finish();
    if (mounted) context.go('/history');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(workoutControllerProvider);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Treino')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sem treino em andamento.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/routines'),
                  child: const Text('VOLTAR PARA ROTINAS'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    _hydrateFromCurrent(s);

    final cur = s.current;
    if (cur == null) return _FinishedView(onFinish: _finish);

    final repo = ref.watch(libraryRepositoryProvider);
    final exercise = repo.findBySlug(
      ExerciseId.parse(cur.exerciseId).librarySlug,
    );
    final totalSeries = s.slots
        .where((sl) => sl.ordemNoTreino == cur.ordemNoTreino)
        .length;
    final unit = ref.watch(weightUnitProvider);
    // Exercicio medido por tempo: o input de reps vira um timer regressivo.
    final timed = (exercise?.medidaPorTempo ?? false) || cur.planned.porTempo;
    final alvoSeg = cur.planned.duracaoAlvoSegundos ?? 45;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
          titleSpacing: 20,
          title: Row(
            children: [
              _LiveDot(color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'EM TREINO',
                style: AppTheme.label(11, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                '${s.completedCount}/${s.slots.length} séries',
                style: AppTheme.mono(
                  11,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() => _listView = !_listView),
              icon: Icon(
                _listView ? Icons.crop_square : Icons.format_list_bulleted,
              ),
              tooltip: _listView ? 'Modo série' : 'Ver treino completo',
            ),
            IconButton(
              onPressed: s.cursor > 0
                  ? ref.read(workoutControllerProvider.notifier).goBackOneSet
                  : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Editar série anterior',
            ),
            IconButton(
              onPressed: _substitute,
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Substituir exercício',
            ),
            IconButton(
              onPressed: _finish,
              icon: const Icon(Icons.stop),
              tooltip: 'Finalizar treino',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressBar(state: s),
              if (_listView)
                Expanded(
                  child: _WorkoutListView(
                    state: s,
                    unit: unit,
                    onTapSlot: (slotId) {
                      ref
                          .read(workoutControllerProvider.notifier)
                          .jumpToSlot(slotId);
                      setState(() => _listView = false);
                    },
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tag superior — qual exercicio. Nome primeiro, largura
                        // inteira; a thumb desce pra linha do numero da serie.
                        Text(
                          'EXERCICIO',
                          style: AppTheme.label(
                            10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exercise?.nome ?? 'Exercício',
                          style: Theme.of(context).textTheme.headlineSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (cur.grupoId != null) ...[
                          const SizedBox(height: 12),
                          _GrupoBadge(state: s, cur: cur),
                        ],
                        const SizedBox(height: 20),
                        // Hero: thumb a esquerda; contador da serie alinhado ao
                        // canto direito.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (exercise != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ExerciseThumb(
                                  exercise: exercise,
                                  size: 72,
                                  expandable: true,
                                ),
                              ),
                            const Spacer(),
                            if (cur.planned.aquecimento)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  'AQUECIMENTO',
                                  style: AppTheme.label(
                                    10,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            if (cur.planned.aquecimento)
                              const SizedBox(width: 12),
                            // Fade sutil ao trocar de serie — confirma que o
                            // numero mudou mesmo num relance rapido (§8:
                            // movimento e feedback, nao decoracao).
                            AnimatedSwitcher(
                              duration: AppTheme.motionBase,
                              switchInCurve: AppTheme.easingStandard,
                              switchOutCurve: AppTheme.easingStandard,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Text(
                                '${cur.numeroSerie}',
                                key: ValueKey(cur.id),
                                style: AppTheme.mono(
                                  120,
                                  weight: FontWeight.w800,
                                ).copyWith(color: scheme.primary, height: 0.85),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '/$totalSeries',
                                style:
                                    AppTheme.mono(
                                      28,
                                      weight: FontWeight.w400,
                                    ).copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'SÉRIE',
                            style: AppTheme.label(
                              10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Visao geral das series do exercicio atual
                        _SeriesOverview(state: s, unit: unit, timed: timed),
                        const SizedBox(height: 12),
                        // O que foi feito na ultima sessao deste exercicio
                        _LastTimeRow(unit: unit),
                        const SizedBox(height: 12),
                        // Sugestao de progressao de carga (sessao anterior)
                        _ProgressionCard(unit: unit, onApply: _applyCargaKg),
                        // Alvo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(color: scheme.outline),
                            boxShadow: AppTheme.cardShadow(scheme),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'ALVO',
                                style: AppTheme.label(
                                  10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timed
                                    ? _fmtMmss(alvoSeg)
                                    : '${cur.planned.repsAlvoMin}–${cur.planned.repsAlvoMax}',
                                style: AppTheme.mono(
                                  15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timed ? 'tempo' : 'reps',
                                style: AppTheme.label(
                                  11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (cur.planned.cargaAlvo != null) ...[
                                Text(
                                  unit.format(cur.planned.cargaAlvo!),
                                  style: AppTheme.mono(
                                    15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  unit.suffix,
                                  style: AppTheme.label(
                                    11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (timed)
                          // Exercicio por tempo: reps viram timer. Carga continua
                          // (prancha com peso, farmer carry) e e opcional.
                          _NumberInput(
                            label:
                                'CARGA (${unit.suffix.toUpperCase()}) · OPC.',
                            controller: _cargaCtrl,
                            allowDecimal: true,
                            step: unit.step,
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _NumberInput(
                                  label: 'REPS',
                                  controller: _repsCtrl,
                                  step: 1,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _NumberInput(
                                  label: 'CARGA (${unit.suffix.toUpperCase()})',
                                  controller: _cargaCtrl,
                                  allowDecimal: true,
                                  step: unit.step,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _RpeRow(
                          value: _rpe,
                          onChanged: (v) => setState(() => _rpe = v),
                        ),
                      ],
                    ),
                  ),
                ),
              // Bottom actions (so no modo foco; a lista navega por toque)
              if (!_listView)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 64,
                        child: FilledButton(
                          onPressed: _submitting
                              ? null
                              : timed
                              ? () => _confirmTimed(alvoSeg, exercise?.nome)
                              : _confirm,
                          child: _submitting
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      timed
                                          ? Icons.play_arrow_rounded
                                          : Icons.check_rounded,
                                      color: scheme.onPrimary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timed
                                          ? 'INICIAR (${_fmtMmss(alvoSeg)})'
                                          : 'CONCLUIR SÉRIE',
                                      style: AppTheme.label(
                                        15,
                                      ).copyWith(color: scheme.onPrimary),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting ? null : _skip,
                              child: const Text('PULAR'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: ref
                                  .read(workoutControllerProvider.notifier)
                                  .jumpToNextExercise,
                              child: const Text('PRÓX. EXERCÍCIO'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
