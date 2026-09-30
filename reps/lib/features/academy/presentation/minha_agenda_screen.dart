import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/academy_api.dart';
import '../data/academy_providers.dart';
import '../../../core/network/erro_amigavel.dart';

/// Agendamento de horários pelo aluno (SPEC §9.4 / §10.4). Todas as regras
/// (janela de 48h, foto, atestado, capacidade) são validadas pelo backend —
/// esta tela só exibe o motivo quando um horário não está disponível.
class MinhaAgendaScreen extends ConsumerWidget {
  const MinhaAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(agendaSelectedDateProvider);
    final slotsAsync = ref.watch(availableSlotsProvider);
    final apptsAsync = ref.watch(myAppointmentsProvider);
    final df = DateFormat('EEEE, d MMM', 'pt_BR');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Minha Agenda')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableSlotsProvider);
          ref.invalidate(myAppointmentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.event_outlined),
                ),
                title: Text(_capitalize(df.format(selectedDate))),
                subtitle: const Text('Toque para escolher outra data'),
                trailing: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3)),
                  );
                  if (picked != null) {
                    ref.read(agendaSelectedDateProvider.notifier).state =
                        picked;
                  }
                },
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            const _SectionHeader(
              icon: Icons.access_time_outlined,
              label: 'Horários',
            ),
            const SizedBox(height: AppTheme.space8),
            slotsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.space24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
                child: Text(
                  mensagemDeErro(
                    e,
                    fallback: 'Não foi possível carregar os horários.',
                  ),
                ),
              ),
              data: (slots) {
                if (slots.isEmpty) {
                  return const _EmptyHint(
                    icon: Icons.event_busy_outlined,
                    text: 'Nenhum horário disponível para esta data.',
                  );
                }
                return Column(
                  children: [
                    for (final s in slots)
                      _SlotTile(
                        slot: s,
                        onBook: () async {
                          final confirmar = await _confirmarAgendamento(
                            context,
                            s,
                          );
                          if (confirmar != true || !context.mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(academyApiProvider)
                                .book(_iso(selectedDate), s.slotStart);
                            ref.invalidate(availableSlotsProvider);
                            ref.invalidate(myAppointmentsProvider);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Agendado com sucesso!'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(_humanize(e))),
                            );
                          }
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.space32),
            const _SectionHeader(
              icon: Icons.event_available_outlined,
              label: 'Meus agendamentos',
            ),
            const SizedBox(height: AppTheme.space8),
            apptsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.space24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                mensagemDeErro(
                  e,
                  fallback: 'Não foi possível carregar seus agendamentos.',
                ),
              ),
              data: (appts) {
                final ativos =
                    appts.where((a) => a.status != 'cancelado').toList()
                      ..sort((a, b) => a.date.compareTo(b.date));
                if (ativos.isEmpty) {
                  return const _EmptyHint(
                    icon: Icons.event_note_outlined,
                    text: 'Nenhum agendamento ativo.',
                  );
                }
                return Column(
                  children: [
                    for (final a in ativos)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppTheme.space8),
                        child: ListTile(
                          leading: Icon(
                            _statusIcon(a.status),
                            color: _statusColor(a.status, scheme),
                          ),
                          title: Text(
                            '${_formatDate(a.date)} · ${a.slotStart}',
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(
                              top: AppTheme.space4,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    a.status,
                                    scheme,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusLabel(a.status),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: _statusColor(a.status, scheme),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          trailing:
                              a.status == 'agendado' || a.status == 'confirmado'
                              ? IconButton(
                                  icon: Icon(Icons.close, color: scheme.error),
                                  tooltip: 'Cancelar',
                                  onPressed: () async {
                                    await ref
                                        .read(academyApiProvider)
                                        .cancelAppointment(a.id);
                                    ref.invalidate(myAppointmentsProvider);
                                    ref.invalidate(availableSlotsProvider);
                                  },
                                )
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho de seção com ícone + rótulo — mesmo peso visual (Title,
/// design-system.md §3) usado nas duas listas desta tela.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: AppTheme.space8),
        Text(label, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// Estado vazio compacto (lista de horários/agendamentos sem itens).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppTheme.space8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onBook});

  final AvailableSlot slot;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final occupancy = slot.maxCapacity > 0
        ? (slot.civilCount / slot.maxCapacity).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      child: ListTile(
        enabled: slot.available,
        leading: CircleAvatar(
          backgroundColor: slot.available
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          foregroundColor: slot.available
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
          child: const Icon(Icons.access_time, size: 18),
        ),
        title: Text('${slot.slotStart} – ${slot.slotEnd}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                slot.available
                    ? '${slot.civilCount}/${slot.maxCapacity} vagas ocupadas'
                    : (slot.reason ?? 'Indisponível'),
              ),
            ),
            if (slot.available && slot.maxCapacity > 0) ...[
              const SizedBox(height: AppTheme.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: occupancy,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHigh,
                  color: occupancy >= 1 ? scheme.error : scheme.primary,
                ),
              ),
            ],
          ],
        ),
        // SizedBox: o tema define FilledButton com Size.fromHeight (só fixa
        // altura), então sem largura limitada o botao tenta ocupar todo o
        // espaco do ListTile.trailing e quebra o layout ("trailing widget
        // consumes the entire tile width") — visto no teste de integracao.
        trailing: slot.available
            ? SizedBox(
                width: 96,
                height: 36,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onBook,
                  child: const Text('Agendar'),
                ),
              )
            : null,
      ),
    );
  }
}

Future<bool?> _confirmarAgendamento(BuildContext context, AvailableSlot s) {
  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar agendamento?'),
      content: Text('Agendar o horário ${s.slotStart} – ${s.slotEnd}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Não'),
        ),
        FilledButton(
          // O tema define FilledButton com minimumSize largura-infinita (pro
          // botão de CTA de tela cheia, ex. "Agendar") — sem essa sobrescrita
          // ele estica e desalinha ao lado do TextButton compacto num Row de
          // ações de dialog (mesma armadilha do botão "Agendar" do _SlotTile).
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Sim'),
        ),
      ],
    ),
  );
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDate(String iso) {
  try {
    return DateFormat('dd/MM').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

IconData _statusIcon(String status) => switch (status) {
  'confirmado' => Icons.check_circle_outline,
  'faltou' => Icons.error_outline,
  _ => Icons.schedule,
};

String _statusLabel(String status) => switch (status) {
  'agendado' => 'Agendado',
  'confirmado' => 'Confirmado (check-in feito)',
  'faltou' => 'Falta registrada',
  'cancelado' => 'Cancelado',
  _ => status,
};

/// Cor semântica do status (design-system.md §2 — só uso semântico, nunca
/// decorativo): info (agendado), sucesso (confirmado), perigo (faltou).
Color _statusColor(String status, ColorScheme scheme) => switch (status) {
  'confirmado' => scheme.primary,
  'faltou' => scheme.error,
  _ => scheme.tertiary,
};

String _humanize(Object e) {
  // ApiException já traz mensagem final em pt-BR do backend (SchedulingService
  // valida cada regra com uma mensagem pronta) — repassa direto. Qualquer
  // outro tipo de exceção (rede, parse etc.) nunca aparece pro usuário como
  // texto técnico bruto.
  if (e is! ApiException) {
    return 'Não foi possível agendar agora. Tente de novo em instantes.';
  }
  final msg = e.message;
  if (msg.contains('atestado')) return 'Atestado médico ausente ou vencido.';
  if (msg.contains('48h')) {
    return 'Só é possível agendar com até 48h de antecedência.';
  }
  if (msg.contains('2 agendamentos')) {
    return 'Você já possui 2 agendamentos ativos.';
  }
  if (msg.contains('cheio')) return 'Horário cheio para civis.';
  return msg;
}
