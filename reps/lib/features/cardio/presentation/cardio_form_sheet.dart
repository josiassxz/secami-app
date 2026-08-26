import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cardio_providers.dart';

class CardioFormSheet extends ConsumerStatefulWidget {
  const CardioFormSheet({super.key});

  @override
  ConsumerState<CardioFormSheet> createState() => _CardioFormSheetState();
}

class _CardioFormSheetState extends ConsumerState<CardioFormSheet> {
  static const _modalidades = <(String, String)>[
    ('esteira', 'Esteira'),
    ('bicicleta', 'Bicicleta'),
    ('escada', 'Escada'),
    ('corrida_ar_livre', 'Corrida ao ar livre'),
    ('remo', 'Remo'),
    ('eliptico', 'Eliptico'),
    ('outros', 'Outros'),
  ];

  String _modalidade = 'esteira';
  final _duracaoCtrl = TextEditingController(text: '20');
  final _distanciaCtrl = TextEditingController();
  int _intensidade = 6;
  final _fcMediaCtrl = TextEditingController();
  final _fcMaxCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _duracaoCtrl.dispose();
    _distanciaCtrl.dispose();
    _fcMediaCtrl.dispose();
    _fcMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final duracao = int.tryParse(_duracaoCtrl.text) ?? 0;
    if (duracao <= 0) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(cardioServiceProvider)
          .create(
            modalidade: _modalidade,
            duracaoMinutos: duracao,
            distanciaKm: double.tryParse(
              _distanciaCtrl.text.replaceAll(',', '.'),
            ),
            intensidade: _intensidade,
            fcMedia: int.tryParse(_fcMediaCtrl.text),
            fcMax: int.tryParse(_fcMaxCtrl.text),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Registrar cardio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _modalidade,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: [
                for (final m in _modalidades)
                  DropdownMenuItem(value: m.$1, child: Text(m.$2)),
              ],
              onChanged: (v) => setState(() => _modalidade = v ?? 'esteira'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duracaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Duração (min)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _distanciaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Distancia (km)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Intensidade: $_intensidade'),
            Slider(
              value: _intensidade.toDouble(),
              onChanged: (v) => setState(() => _intensidade = v.round()),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_intensidade',
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fcMediaCtrl,
                    decoration: const InputDecoration(labelText: 'FC media'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fcMaxCtrl,
                    decoration: const InputDecoration(labelText: 'FC max'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
