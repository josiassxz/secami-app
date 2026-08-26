import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/custom_exercise_providers.dart';
import '../../../domain/entities/exercise.dart';

class CustomExerciseFormSheet extends ConsumerStatefulWidget {
  const CustomExerciseFormSheet({this.editId, this.initialNome, super.key});

  final String? editId;
  final String? initialNome;

  @override
  ConsumerState<CustomExerciseFormSheet> createState() =>
      _CustomExerciseFormSheetState();
}

class _CustomExerciseFormSheetState
    extends ConsumerState<CustomExerciseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  GrupoMuscular _grupo = GrupoMuscular.peito;
  PadraoMovimento _padrao = PadraoMovimento.isolador;
  Equipamento _equipamento = Equipamento.peso_corporal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialNome != null) _nomeCtrl.text = widget.initialNome!;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(customExerciseServiceProvider)
          .save(
            id: widget.editId,
            nome: _nomeCtrl.text.trim(),
            descricao: _descCtrl.text.trim(),
            grupoPrimario: _grupo,
            padraoMovimento: _padrao,
            equipamento: _equipamento,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.editId == null ? 'NOVO EXERCÍCIO' : 'EDITAR EXERCÍCIO',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              _DropdownRow<GrupoMuscular>(
                label: 'GRUPO MUSCULAR',
                value: _grupo,
                items: GrupoMuscular.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _grupo = v),
              ),
              const SizedBox(height: 12),
              _DropdownRow<PadraoMovimento>(
                label: 'PADRÃO DE MOVIMENTO',
                value: _padrao,
                items: PadraoMovimento.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _padrao = v),
              ),
              const SizedBox(height: 12),
              _DropdownRow<Equipamento>(
                label: 'EQUIPAMENTO',
                value: _equipamento,
                items: Equipamento.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _equipamento = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SALVAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label(11, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: const InputDecoration(isDense: true),
          items: items
              .map(
                (v) => DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
