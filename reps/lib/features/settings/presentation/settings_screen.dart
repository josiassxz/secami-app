import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/health/health_service.dart';
import '../../../core/logging/observability.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/units/weight_unit.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_service.dart';
import '../data/export_service.dart';
import '../data/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat fmt,
  ) async {
    try {
      final n = await ref.read(exportServiceProvider).share(fmt);
      await Observability.track('data_exported', {
        'formato': fmt.name,
        'num_sessoes': n,
      });
    } on Exception catch (e, st) {
      await Observability.captureError(e, st, hint: 'export');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    }
  }

  Future<void> _testHealthExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Testando exportação...')),
    );
    final err = await ref.read(healthServiceProvider).testExport();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? 'Treino de teste gravado! Veja em Health Connect → Atividade.'
              : 'Falha: $err',
        ),
        duration: Duration(seconds: err == null ? 4 : 8),
      ),
    );
  }

  /// Forca um sync imediato (push + pull). Puxa os treinos que ja existem na
  /// conta no banco, sem esperar o tick de 5 min. Usa engine.status (sincrono)
  /// pra reportar o resultado logo apos o runOnce.
  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final engine = ref.read(syncEngineProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Sincronizando...')));
    await engine.runOnce();
    if (!context.mounted) return;
    final s = engine.status;
    final falhou = s.phase == SyncPhase.error || s.lastError != null;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          falhou
              ? 'Não deu pra sincronizar agora. Seus dados estão salvos no '
                    'aparelho; tentaremos de novo automaticamente.'
              : 'Tudo sincronizado.',
        ),
        duration: Duration(seconds: falhou ? 6 : 3),
        // Sem Sentry configurado o erro real ficaria invisível no release.
        // Deixa o detalhe a um toque pra diagnosticar sync que falha.
        action: falhou && s.lastError != null
            ? SnackBarAction(
                label: 'DETALHES',
                onPressed: () => _showSyncError(context, s.lastError!),
              )
            : null,
      ),
    );
  }

  void _showSyncError(BuildContext context, String erro) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erro de sincronização'),
        content: SingleChildScrollView(child: SelectableText(erro)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _syncSubtitle(SyncStatus? s) {
    if (s == null || s.isRunning) {
      return s?.isRunning ?? false
          ? 'Sincronizando...'
          : 'Baixa seus treinos e mantém tudo na nuvem';
    }
    if (s.lastError != null) return 'Offline — toque para tentar de novo';
    if (s.lastSuccessAt != null) {
      final quando = DateFormat(
        'dd/MM HH:mm',
      ).format(s.lastSuccessAt!.toLocal());
      final pend = s.pendingPush > 0 ? ' · ${s.pendingPush} pendente(s)' : '';
      return 'Última: $quando$pend';
    }
    return 'Baixa seus treinos e mantém tudo na nuvem';
  }

  Future<void> _showHealthHelp(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _HealthHelpSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerSettingsProvider);
    final unit = ref.watch(weightUnitProvider);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final syncStatus = ref.watch(syncStatusProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(user?.email ?? ''),
              subtitle: const Text('Gerenciar conta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/account'),
            ),
          if (isGuest)
            ListTile(
              leading: const Icon(Icons.no_accounts_outlined),
              title: const Text('Modo convidado'),
              subtitle: const Text(
                'Crie conta pra sincronizar entre dispositivos',
              ),
              trailing: TextButton(
                onPressed: () => context.push('/sign-up'),
                child: const Text('Criar conta'),
              ),
            ),
          const Divider(),
          if (!isGuest) ...[
            const _SectionLabel('Sincronização'),
            ListTile(
              leading: (syncStatus?.isRunning ?? false)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: const Text('Sincronizar agora'),
              subtitle: Text(_syncSubtitle(syncStatus)),
              onTap: (syncStatus?.isRunning ?? false)
                  ? null
                  : () => _syncNow(context, ref),
            ),
            const Divider(),
            const _SectionLabel('Treinador'),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Meus alunos'),
              subtitle: const Text('Acompanhe quem você treina'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/alunos'),
            ),
            ListTile(
              leading: const Icon(Icons.sports_outlined),
              title: const Text('Meu treinador'),
              subtitle: const Text('Vincule-se com um código de convite'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/treinador'),
            ),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Minha academia'),
              subtitle: const Text('Reúna professores sob a mesma marca'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/academia'),
            ),
            const Divider(),
          ],
          const _SectionLabel('Timer de descanso'),
          SwitchListTile(
            title: const Text('Som ao iniciar treino'),
            subtitle: const Text('Toca um alerta quando o treino começa'),
            value: timer.alertaInicio,
            onChanged: ref.read(timerSettingsProvider.notifier).setAlertaInicio,
          ),
          SwitchListTile(
            title: const Text('Alerta sonoro ao terminar descanso'),
            subtitle: const Text('Toca um som quando o timer zera'),
            value: timer.bipe,
            onChanged: ref.read(timerSettingsProvider.notifier).setBipe,
          ),
          SwitchListTile(
            title: const Text('Vibrar quando zerar'),
            value: timer.vibracao,
            onChanged: ref.read(timerSettingsProvider.notifier).setVibracao,
          ),
          const Divider(),
          const _SectionLabel('Unidade de peso'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {unit},
              onSelectionChanged: (s) =>
                  ref.read(weightUnitProvider.notifier).set(s.first),
            ),
          ),
          if (!kIsWeb) ...[
            const Divider(),
            const _SectionLabel('Integrações'),
            SwitchListTile(
              secondary: const Icon(Icons.favorite_border),
              title: const Text('Health Connect / Apple Health'),
              subtitle: const Text(
                'Exporta treinos automaticamente ao finalizar',
              ),
              value: ref.watch(healthIntegrationProvider),
              onChanged: (v) async {
                await ref.read(healthIntegrationProvider.notifier).toggle(v);
                // Se tentou ligar e nao conseguiu (permissao negada ou Health
                // Connect ausente), abre o passo a passo.
                if (v &&
                    !ref.read(healthIntegrationProvider) &&
                    context.mounted) {
                  await _showHealthHelp(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Testar exportação'),
              subtitle: const Text(
                'Grava um treino de teste no Health Connect',
              ),
              onTap: () => _testHealthExport(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Como ativar o Health Connect'),
              subtitle: const Text('Passo a passo se o botão não funcionar'),
              onTap: () => _showHealthHelp(context),
            ),
          ],
          const Divider(),
          const _SectionLabel('Dados'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Exportar para CSV'),
            subtitle: const Text('Compartilha um arquivo .csv com tudo'),
            onTap: () => _export(context, ref, ExportFormat.csv),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Exportar para JSON'),
            subtitle: const Text('Estrutura aninhada por sessao'),
            onTap: () => _export(context, ref, ExportFormat.json),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Recordes'),
            onTap: () => context.push('/records'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Resumo semanal'),
            onTap: () => context.push('/insights/weekly'),
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Cardio'),
            onTap: () => context.push('/cardio'),
          ),
          const Divider(),
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/');
              },
            ),
          if (!isGuest)
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Excluir conta',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => context.push('/settings/delete-account'),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Rótulo de seção da lista de ajustes — mesmo padrão editorial (caixa alta,
/// peso 600, cor secundária) usado nos cabeçalhos de seção do resto do app.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.label(
          11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Passo a passo pra habilitar a exportação de treinos via Health Connect
/// (Android) / Apple Saúde (iOS). Aberto pelo botão "Como ativar" ou
/// automaticamente quando o toggle falha em conseguir permissão.
class _HealthHelpSheet extends StatelessWidget {
  const _HealthHelpSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = <(String, String)>[
      (
        'Instale o Health Connect',
        'No Android 14+ já vem no sistema. No Android 13 ou anterior, '
            'instale o app "Health Connect" pela Play Store.',
      ),
      (
        'Abra o Health Connect uma vez',
        'Abra o app Health Connect e conclua a configuração inicial '
            '(aceite os termos). Isso registra o reps como app disponível.',
      ),
      (
        'Volte ao reps e ligue o botão',
        'Aqui em Ajustes → Integrações, ligue "Health Connect / Apple Health". '
            'Deve abrir uma tela de permissão.',
      ),
      (
        'Conceda a permissão de Exercício',
        'Na tela do Health Connect, permita que o reps GRAVE dados de '
            'Exercício/Treino. Sem isso, nada é exportado.',
      ),
      (
        'Finalize um treino',
        'Ao concluir um treino no reps, a sessão é enviada automaticamente. '
            'Confira em Health Connect → Dados → Atividade.',
      ),
      (
        'Conecte o app que vai ler (ex.: Gymrats)',
        'No outro app, ative a leitura do Health Connect. Ele passa a '
            'importar os treinos que o reps gravou.',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_border, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Como ativar o Health Connect',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Serve pra exportar seus treinos pra apps como Gymrats, '
                'Google Fit e afins.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              steps[i].$2,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se o botão ainda não abrir a permissão, abra o app '
                        'Health Connect → Permissões de apps → reps e habilite '
                        'manualmente.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
