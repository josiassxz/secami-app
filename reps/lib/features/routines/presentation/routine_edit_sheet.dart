import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../data/routine_providers.dart';

/// Editor de metadata da rotina (nome, tipo, dias da semana) com botao
/// explicito de Salvar. Aberto via lapis no AppBar do RoutineBuilderScreen.
class RoutineEditSheet extends ConsumerStatefulWidget {
  const RoutineEditSheet({required this.routine, super.key});

  final RoutineRow routine;

  @override
  ConsumerState<RoutineEditSheet> createState() => _RoutineEditSheetState();
}

class _RoutineEditSheetState extends ConsumerState<RoutineEditSheet> {
  static const _diasLabel = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

  late TextEditingController _nameCtrl;
  late String _tipo;
  late Set<int> _dias;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.routine.nome);
    _tipo = widget.routine.tipo;
    _dias = RoutineService.decodeDias(widget.routine.diasDaSemana).toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_nameCtrl.text.trim() != widget.routine.nome) return true;
    if (_tipo != widget.routine.tipo) return true;
    final original = RoutineService.decodeDias(widget.routine.diasDaSemana)
      ..sort();
    final current = _dias.toList()..sort();
    if (original.length != current.length) return true;
    for (var i = 0; i < original.length; i++) {
      if (original[i] != current[i]) return true;
    }
    return false;
  }

  Future<void> _salvar() async {
    final nome = _nameCtrl.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nome não pode ser vazio.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(routineServiceProvider);
      if (nome != widget.routine.nome) {
        await svc.rename(widget.routine.id, nome);
      }
      final originalDias = RoutineService.decodeDias(
        widget.routine.diasDaSemana,
      );
      final newDias = _dias.toList()..sort();
      final originalSorted = originalDias..sort();
      final diasChanged =
          originalSorted.length != newDias.length ||
          List.generate(
            newDias.length,
            (i) => originalSorted[i] != newDias[i],
          ).any((x) => x);
      if (diasChanged) {
        await svc.updateDias(widget.routine.id, newDias);
      }
      if (_tipo != widget.routine.tipo) {
        await svc.updateTipo(widget.routine.id, _tipo);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rotina atualizada.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Editar rotina', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fixo', label: Text('Fixa na semana')),
              ButtonSegment(value: 'avulso', label: Text('Avulsa')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          if (_tipo == 'fixo') ...[
            const SizedBox(height: 16),
            Text(
              'Dias da semana',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final selected = _dias.contains(i);
                return FilterChip(
                  label: Text(_diasLabel[i]),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _dias.remove(i);
                    } else {
                      _dias.add(i);
                    }
                  }),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('CANCELAR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: (_busy || !_hasChanges) ? null : _salvar,
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SALVAR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
