import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../data/routine_providers.dart';

class RoutineCreateSheet extends ConsumerStatefulWidget {
  const RoutineCreateSheet({super.key});

  @override
  ConsumerState<RoutineCreateSheet> createState() => _RoutineCreateSheetState();
}

class _RoutineCreateSheetState extends ConsumerState<RoutineCreateSheet> {
  static const _diasLabel = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

  final _nameCtrl = TextEditingController();
  String _tipo = 'fixo';
  final Set<int> _dias = {};
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nome = _nameCtrl.text.trim();
    if (nome.isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(routineServiceProvider)
          .create(
            nome: nome,
            tipo: _tipo,
            diasDaSemana: _dias.toList()..sort(),
          );
      await Observability.track('routine_created', {'tipo': _tipo});
      if (!mounted) return;
      Navigator.of(context).pop();
      // ?new=1 sinaliza pro RoutineBuilderScreen abrir o picker direto
      unawaited(context.push('/routines/$id?new=1'));
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
          Text('Nova rotina', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome (ex.: Peito e Triceps)',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
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
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('CRIAR E ESCOLHER EXERCÍCIOS'),
          ),
        ],
      ),
    );
  }
}
