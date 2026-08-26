import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_api.dart';
import '../data/academy_providers.dart';

/// Perfil do aluno: dados pessoais, peso/altura/objetivo editáveis, status
/// do atestado. Upload de foto fica para uma fase futura (SPEC §13.5) — a
/// foto é pré-requisito para agendar (reconhecimento facial da catraca) e
/// hoje é cadastrada pela recepção/admin.
class MeuPerfilScreen extends ConsumerStatefulWidget {
  const MeuPerfilScreen({super.key});

  @override
  ConsumerState<MeuPerfilScreen> createState() => _MeuPerfilScreenState();
}

class _MeuPerfilScreenState extends ConsumerState<MeuPerfilScreen> {
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _telefoneCtrl.dispose();
    _objetivoCtrl.dispose();
    super.dispose();
  }

  void _fill(Map<String, dynamic> p) {
    if (_loaded) return;
    _pesoCtrl.text = p['weightKg']?.toString() ?? '';
    _alturaCtrl.text = p['heightCm']?.toString() ?? '';
    _telefoneCtrl.text = p['phone']?.toString() ?? '';
    _objetivoCtrl.text = p['goal']?.toString() ?? '';
    _loaded = true;
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      await ref.read(academyApiProvider).updateMyProfile({
        'weightKg': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')),
        'heightCm': double.tryParse(_alturaCtrl.text.replaceAll(',', '.')),
        'phone': _telefoneCtrl.text.trim().isEmpty
            ? null
            : _telefoneCtrl.text.trim(),
        'goal': _objetivoCtrl.text.trim().isEmpty
            ? null
            : _objetivoCtrl.text.trim(),
      });
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: scheme.error),
                const SizedBox(height: AppTheme.space12),
                Text('Erro: $e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (p) {
          _fill(p);
          final atestadoValido = p['atestadoValido'] == true;
          final studentType = p['studentType']?.toString() ?? 'Civil';
          return ListView(
            padding: const EdgeInsets.all(AppTheme.space16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.person_outline, size: 28),
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['fullName']?.toString() ?? '',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          '${p['cpf'] ?? ''} · $studentType'
                          '${p['departmentName'] != null ? ' · ${p['departmentName']}' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space24),
              if (studentType == 'Civil')
                Card(
                  color: atestadoValido ? null : scheme.errorContainer,
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      atestadoValido
                          ? Icons.check_circle_outline
                          : Icons.warning_amber,
                      color: atestadoValido ? scheme.primary : scheme.error,
                    ),
                    title: Text(
                      atestadoValido
                          ? 'Atestado médico válido'
                          : 'Atestado ausente ou vencido',
                    ),
                    subtitle: const Text(
                      'Obrigatório para civis agendarem horários (validade de 1 ano).',
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.space24),
              Text(
                'DADOS PESSOAIS',
                style: context.uppercaseLabel(
                  12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: TextField(
                      controller: _alturaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Altura (cm)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: _objetivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Objetivo',
                  hintText: 'Ex.: Hipertrofia, Emagrecimento...',
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: Text(
                      'Foto de perfil (obrigatória para agendar) é cadastrada pela recepção.',
                      style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _salvar,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar alterações'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
