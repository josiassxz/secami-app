import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirmCtrl.text.trim() != 'EXCLUIR') {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).requestAccountDeletion();
      if (!mounted) {
        return;
      }
      context.go('/');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final confirmado = _confirmCtrl.text.trim() == 'EXCLUIR';
    return Scaffold(
      appBar: AppBar(title: const Text('Excluir conta')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Elemento dominante: selo de alerta — comunica "zona de perigo"
          // antes mesmo do texto, sem tingir a tela inteira de vermelho.
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: scheme.error,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            'Esta ação é permanente',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Agenda a exclusão completa dos seus dados em até 30 dias, em '
            'conformidade com a LGPD. Treinos, rotinas e histórico salvos na '
            'nuvem serão apagados.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space24),
          Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: scheme.error),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    'Para confirmar, digite EXCLUIR no campo abaixo.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _confirmCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Digite EXCLUIR'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTheme.space24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_busy || !confirmado) ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                disabledBackgroundColor: scheme.error.withValues(alpha: 0.38),
                disabledForegroundColor: scheme.onError.withValues(alpha: 0.7),
              ),
              child: _busy
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onError,
                      ),
                    )
                  : const Text('Confirmar exclusão'),
            ),
          ),
        ],
      ),
    );
  }
}
