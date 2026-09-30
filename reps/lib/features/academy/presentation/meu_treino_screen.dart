import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_api.dart';
import '../data/academy_providers.dart';
import '../data/workout_log_api.dart';
import '../../../core/network/erro_amigavel.dart';

/// Execução da ficha (A–D) prescrita pelo professor (SPEC §9.3 / §10.4).
/// Marca exercícios feitos com carga; salva no dia via /me/workout-logs.
class MeuTreinoScreen extends ConsumerStatefulWidget {
  const MeuTreinoScreen({super.key});

  @override
  ConsumerState<MeuTreinoScreen> createState() => _MeuTreinoScreenState();
}

class _MeuTreinoScreenState extends ConsumerState<MeuTreinoScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final Set<String> _feitos = {};
  final Map<String, String> _cargas = {};
  bool _saving = false;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(myWorkoutPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Treino')),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: mensagemDeErro(
            e,
            fallback: 'Não foi possível carregar seus treinos.',
          ),
        ),
        data: (plans) {
          final ativas = plans.where((p) => p.active).toList();
          if (ativas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.space24),
                child: _EmptyFicha(),
              ),
            );
          }
          _tabController ??= TabController(length: ativas.length, vsync: this);
          if (_tabController!.length != ativas.length) {
            _tabController = TabController(length: ativas.length, vsync: this);
          }
          return Column(
            children: [
              if (ativas.length > 1)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: [
                      for (final p in ativas)
                        Tab(text: 'Ficha ${p.sheetLabel}'),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final p in ativas) _FichaView(plan: p, screen: this),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _salvar(WorkoutPlanDto plan) async {
    setState(() => _saving = true);
    try {
      final exercises = plan.exercises
          .where((e) => _feitos.contains(e.exerciseName))
          .map(
            (e) => LoggedExercise(
              exerciseName: e.exerciseName,
              load: _cargas[e.exerciseName],
            ),
          )
          .toList();
      await ref
          .read(workoutLogApiProvider)
          .saveToday(
            workoutPlanId: plan.id,
            sheetLabel: plan.sheetLabel,
            exercises: exercises,
          );
      if (mounted) {
        final completo = exercises.length >= plan.exercises.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completo ? 'Treino concluído! 🎉' : 'Progresso salvo.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensagemDeErro(e, fallback: 'Não foi possível salvar o treino.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EmptyFicha extends StatelessWidget {
  const _EmptyFicha();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.assignment_late_outlined,
          size: 48,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppTheme.space16),
        Text(
          'Você ainda não tem uma ficha de treino prescrita.\n'
          'Fale com o instrutor da academia.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: AppTheme.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FichaView extends StatefulWidget {
  const _FichaView({required this.plan, required this.screen});

  final WorkoutPlanDto plan;
  final _MeuTreinoScreenState screen;

  @override
  State<_FichaView> createState() => _FichaViewState();
}

class _FichaViewState extends State<_FichaView> {
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final s = widget.screen;
    final scheme = Theme.of(context).colorScheme;
    final total = plan.exercises.length;
    final done = s._feitos.length;
    final progress = total > 0 ? done / total : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space8,
          ),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHigh,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                '$done/$total',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              AppTheme.space8,
              AppTheme.space16,
              AppTheme.space16,
            ),
            itemCount: plan.exercises.length,
            itemBuilder: (context, i) {
              final ex = plan.exercises[i];
              final feito = s._feitos.contains(ex.exerciseName);
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.space8),
                child: CheckboxListTile(
                  value: feito,
                  title: Text(
                    ex.exerciseName,
                    style: feito
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space4),
                    child: Wrap(
                      spacing: AppTheme.space8,
                      runSpacing: AppTheme.space4,
                      children: [
                        if (ex.sets != null) _MetaChip('${ex.sets}x'),
                        if (ex.reps != null) _MetaChip(ex.reps!),
                        if (ex.restSeconds != null)
                          _MetaChip('descanso ${ex.restSeconds}s'),
                      ],
                    ),
                  ),
                  secondary: feito
                      ? SizedBox(
                          width: 104,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'carga',
                              suffixText: 'kg',
                              isDense: true,
                            ),
                            onChanged: (v) => s._cargas[ex.exerciseName] = v,
                          ),
                        )
                      : null,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        s._feitos.add(ex.exerciseName);
                      } else {
                        s._feitos.remove(ex.exerciseName);
                        s._cargas.remove(ex.exerciseName);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: s._saving ? null : () => s._salvar(plan),
                child: s._saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar progresso do dia'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pílula compacta com metadado do exercício (séries, reps, descanso).
class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
