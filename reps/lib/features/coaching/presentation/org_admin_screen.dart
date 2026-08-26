import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_providers.dart';
import '../data/coach_providers.dart';
import '../data/coach_repository.dart';
import '../domain/coach_models.dart';
import 'convite_sheet.dart';
import 'coach_widgets.dart';

/// Gerenciar academia (org): criar, ver professores, convidar professores.
class OrgAdminScreen extends ConsumerWidget {
  const OrgAdminScreen({super.key});

  Future<void> _criarOrg(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova academia'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da academia'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (nome == null || nome.trim().isEmpty) return;
    try {
      await ref.read(coachRepositoryProvider).criarOrg(nome);
      ref.invalidate(minhasOrgsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Academia criada.')));
    } on CoachException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(minhasOrgsProvider);
    final uid = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Minha academia')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _criarOrg(context, ref),
        icon: const Icon(Icons.add_business),
        label: const Text('Nova academia'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(minhasOrgsProvider),
        child: coachSwitcher(
          stateKey: orgs.when(
            loading: () => 'loading',
            error: (_, _) => 'error',
            data: (l) => l.isEmpty ? 'empty' : 'data-${l.length}',
          ),
          child: orgs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => coachCenteredList(
              CoachErrorBox(
                mensagem: e is CoachException
                    ? e.mensagem
                    : 'Erro ao carregar.',
                onRetry: () => ref.invalidate(minhasOrgsProvider),
              ),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return coachCenteredList(
                  const CoachEmptyBox(
                    icone: Icons.business_outlined,
                    texto:
                        'Você ainda não tem uma academia.\nCrie uma para '
                        'reunir professores sob a mesma marca.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space12,
                  AppTheme.space12,
                  AppTheme.space12,
                  96,
                ),
                itemCount: lista.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space8),
                itemBuilder: (context, i) {
                  final org = lista[i];
                  return _OrgCard(org: org, souDono: org.souDono(uid));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrgCard extends ConsumerWidget {
  const _OrgCard({required this.org, required this.souDono});
  final Organizacao org;
  final bool souDono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(membrosOrgProvider(org.id));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.business, size: 20),
        ),
        title: Text(org.nome, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: souDono
              ? _PapelBadge(scheme: scheme)
              : Text(
                  'Professor',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.space16,
          0,
          AppTheme.space16,
          AppTheme.space12,
        ),
        children: [
          membros.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppTheme.space12),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
              child: Text(
                'Erro ao carregar professores.',
                style: TextStyle(color: scheme.error),
              ),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space12,
                  ),
                  child: Text(
                    'Nenhum professor ainda.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in lista)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.surfaceContainerHigh,
                        foregroundColor: scheme.onSurface,
                        child: Text(
                          m.pessoa.exibicao.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(m.pessoa.exibicao),
                      subtitle: Text(
                        m.papel,
                        style: AppTheme.label(
                          11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (souDono) ...[
            const SizedBox(height: AppTheme.space8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ConviteSheet.mostrar(
                  context,
                  tipo: 'org_professor',
                  orgId: org.id,
                ),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Convidar professor'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selo "dono" — unico uso pontual de dourado nesta tela (design-system.md
/// §2: gold reservado a selos/badges, nunca decorativo).
class _PapelBadge extends StatelessWidget {
  const _PapelBadge({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('DONO', style: AppTheme.label(10, color: scheme.onSecondary)),
    );
  }
}
