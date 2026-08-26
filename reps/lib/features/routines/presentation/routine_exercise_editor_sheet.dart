import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/exercise_id.dart';
import '../../../domain/entities/planned_set.dart';
import '../../library/data/library_repository.dart';
import '../data/routine_providers.dart';

class RoutineExerciseEditorSheet extends ConsumerStatefulWidget {
  const RoutineExerciseEditorSheet({
    required this.routineExerciseId,
    required this.exerciseId,
    required this.initialSeries,
    required this.initialNotas,
    super.key,
  });

  final String routineExerciseId;
  final String exerciseId;
  final List<PlannedSet> initialSeries;
  final String? initialNotas;

  @override
  ConsumerState<RoutineExerciseEditorSheet> createState() =>
      _RoutineExerciseEditorState();
}

class _RoutineExerciseEditorState
    extends ConsumerState<RoutineExerciseEditorSheet> {
  late List<PlannedSet> _series;
  late TextEditingController _notasCtrl;
  late bool _timed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final exercise = ref
        .read(libraryRepositoryProvider)
        .findBySlug(_slugFromExerciseId(widget.exerciseId));
    _timed = exercise?.medidaPorTempo ?? false;
    final base = widget.initialSeries.isEmpty
        ? [const PlannedSet(numero: 1)]
        : List<PlannedSet>.from(widget.initialSeries);
    // Exercicio por tempo: garante um alvo de duracao explicito por serie.
    _series = _timed
        ? base
              .map(
                (s) => s.duracaoAlvoSegundos == null
                    ? s.copyWith(duracaoAlvoSegundos: 45)
                    : s,
              )
              .toList()
        : base;
    _notasCtrl = TextEditingController(text: widget.initialNotas ?? '');
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  void _addSerie() {
    setState(() {
      final last = _series.isEmpty ? const PlannedSet(numero: 0) : _series.last;
      _series.add(last.copyWith(numero: _series.length + 1));
    });
  }

  void _removeSerie(int index) {
    setState(() {
      _series.removeAt(index);
      for (var i = 0; i < _series.length; i++) {
        _series[i] = _series[i].copyWith(numero: i + 1);
      }
      if (_series.isEmpty) {
        _series.add(const PlannedSet(numero: 1));
      }
    });
  }

  void _applyFirstToAll() {
    if (_series.isEmpty) return;
    final base = _series.first;
    setState(() {
      _series = List.generate(
        _series.length,
        (i) => base.copyWith(numero: i + 1),
      );
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(routineServiceProvider)
          .updateExerciseSeries(
            routineExerciseId: widget.routineExerciseId,
            series: _series,
            notas: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(libraryRepositoryProvider);
    final exercise = repo.findBySlug(_slugFromExerciseId(widget.exerciseId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: ListView(
              controller: controller,
              children: [
                Text(
                  exercise?.nome ?? 'Exercicio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (exercise != null)
                  Text(
                    exercise.grupoPrimario.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${_series.length} serie${_series.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _applyFirstToAll,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Aplicar a 1a a todas'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _series.length; i++)
                  _SerieRow(
                    key: ValueKey('serie-$i'),
                    serie: _series[i],
                    timed: _timed,
                    onChanged: (s) => setState(() => _series[i] = s),
                    onRemove: () => _removeSerie(i),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addSerie,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar serie'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (cadencia, dicas, etc.)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  String _slugFromExerciseId(String id) => ExerciseId.parse(id).librarySlug;
}

class _SerieRow extends StatelessWidget {
  const _SerieRow({
    super.key,
    required this.serie,
    required this.timed,
    required this.onChanged,
    required this.onRemove,
  });

  final PlannedSet serie;
  final bool timed;
  final void Function(PlannedSet) onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${serie.numero}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: timed
                      ? _NumberField(
                          label: 'Duração (s)',
                          value: serie.duracaoAlvoSegundos ?? 45,
                          onChanged: (v) =>
                              onChanged(serie.copyWith(duracaoAlvoSegundos: v)),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _NumberField(
                                label: 'Reps min',
                                value: serie.repsAlvoMin,
                                onChanged: (v) =>
                                    onChanged(serie.copyWith(repsAlvoMin: v)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _NumberField(
                                label: 'Reps max',
                                value: serie.repsAlvoMax,
                                onChanged: (v) =>
                                    onChanged(serie.copyWith(repsAlvoMax: v)),
                              ),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _DoubleField(
                    label: 'Carga (kg)',
                    value: serie.cargaAlvo,
                    onChanged: (v) => onChanged(
                      serie.copyWith(cargaAlvo: v, clearCargaAlvo: v == null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    label: 'Descanso (s)',
                    value: serie.descansoSegundos,
                    onChanged: (v) =>
                        onChanged(serie.copyWith(descansoSegundos: v)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TipoSerie>(
                    initialValue: serie.tipoSerie,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: TipoSerie.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: (t) {
                      if (t != null) onChanged(serie.copyWith(tipoSerie: t));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Checkbox(
                      value: serie.aquecimento,
                      onChanged: (v) =>
                          onChanged(serie.copyWith(aquecimento: v ?? false)),
                    ),
                    const Text('Aquec.'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final void Function(int) onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // Sincroniza o campo so quando o valor vem de fora (ex.: "Aplicar a 1a a
    // todas"). Nao mexe enquanto o usuario digita (valor ja bate com o texto).
    if (widget.value != old.value && widget.value != int.tryParse(_ctrl.text)) {
      final s = '${widget.value}';
      _ctrl.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n >= 0) widget.onChanged(n);
      },
    );
  }
}

class _DoubleField extends StatefulWidget {
  const _DoubleField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final void Function(double?) onChanged;

  @override
  State<_DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<_DoubleField> {
  late final TextEditingController _ctrl;

  String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(1);

  double? _shown() {
    if (_ctrl.text.isEmpty) return null;
    return double.tryParse(_ctrl.text.replaceAll(',', '.'));
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(_DoubleField old) {
    super.didUpdateWidget(old);
    // Sincroniza so quando o valor vem de fora (ex.: "Aplicar a 1a a todas").
    if (widget.value != old.value && widget.value != _shown()) {
      final s = _fmt(widget.value);
      _ctrl.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        hintText: 'opcional',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        if (v.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final n = double.tryParse(v.replaceAll(',', '.'));
        widget.onChanged(n);
      },
    );
  }
}
