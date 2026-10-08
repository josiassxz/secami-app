import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/atestado_api.dart';

/// Tela de envio de um atestado novo (aluno).
const rotaEnvioAtestado = '/academia/atestado';

/// Abre a tela de envio por cima da tela atual.
void abrirEnvioAtestado(BuildContext context) {
  GoRouter.of(context).push<void>(rotaEnvioAtestado).ignore();
}

String formatarData(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// "vence hoje", "vence amanhã", "vence em 12 dias" (sem a data).
String _venceEmDias(int? dias) {
  if (dias == null) return 'vence em breve';
  if (dias <= 0) return 'vence hoje';
  if (dias == 1) return 'vence amanhã';
  return 'vence em $dias dias';
}

/// "vence hoje (30/03/2027)", "vence amanhã (…)", "vence em 12 dias (…)".
String _venceEm(AtestadoStatus s) {
  final venc = s.vencimento;
  final texto = _venceEmDias(s.diasAteVencer());
  return venc == null ? texto : '$texto (${formatarData(venc)})';
}

/// Situação em palavras, pro cartão de status ("Em dia", "Vence em 12
/// dias", "Vencido — acesso bloqueado"…).
String textoSituacaoAtestado(AtestadoStatus s) {
  if (s.bloqueado) return 'Vencido — acesso bloqueado';
  switch (s.situacao) {
    case SituacaoAtestado.vencido:
      return 'Vencido';
    case SituacaoAtestado.vencendo:
      final texto = _venceEmDias(s.diasAteVencer());
      return texto[0].toUpperCase() + texto.substring(1);
    case SituacaoAtestado.ok:
      return 'Em dia';
  }
}

/// "Seu último envio foi recusado: `motivo`." (sem ponto duplicado).
String? textoRecusaAtestado(AtestadoStatus s) {
  final envio = s.envio;
  if (envio == null || !envio.recusado) return null;
  final motivo = envio.motivoRecusa?.trim() ?? '';
  if (motivo.isEmpty) return 'Seu último envio foi recusado.';
  final fim = RegExp(r'[.!?]$').hasMatch(motivo) ? '' : '.';
  return 'Seu último envio foi recusado: $motivo$fim';
}

/// "Seu novo atestado foi enviado em 08/10/2026 e está em análise pela
/// academia."
String textoEmAnaliseAtestado(AtestadoStatus s) {
  final enviadoEm = s.envio?.enviadoEm;
  final quando = enviadoEm == null ? '' : ' em ${formatarData(enviadoEm)}';
  return 'Seu novo atestado foi enviado$quando e está em análise pela '
      'academia.';
}

const _textoBloqueioAteAprovar =
    'Seu acesso continua bloqueado até a aprovação.';

enum _Variante { emAnalise, vencendo, bloqueado }

_Variante _varianteDe(AtestadoStatus s) {
  if (s.envioPendente) return _Variante.emAnalise;
  if (s.situacao == SituacaoAtestado.vencendo && !s.bloqueado) {
    return _Variante.vencendo;
  }
  return _Variante.bloqueado;
}

/// A janela do atestado ao entrar no app (perto de vencer, vencido/bloqueado
/// ou novo atestado em análise). Fecha devolvendo `true` quando o aluno quer
/// ir pra tela de envio.
///
/// Sem "Não mostrar novamente": enquanto a situação pedir, ela volta a cada
/// entrada no app.
class AtestadoJanela extends StatelessWidget {
  const AtestadoJanela({required this.status, super.key});

  final AtestadoStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final variante = _varianteDe(status);
    final recusa = textoRecusaAtestado(status);

    final (icone, cor, titulo) = switch (variante) {
      _Variante.emAnalise => (
        Icons.hourglass_top_outlined,
        scheme.tertiary,
        'Atestado em análise',
      ),
      _Variante.vencendo => (
        Icons.event_busy_outlined,
        scheme.secondary,
        'Seu atestado está perto de vencer',
      ),
      _Variante.bloqueado => (
        Icons.lock_outline,
        scheme.error,
        'Acesso bloqueado',
      ),
    };

    final paragrafos = <String>[
      ...switch (variante) {
        _Variante.emAnalise => [
          textoEmAnaliseAtestado(status),
          if (status.bloqueado) _textoBloqueioAteAprovar,
        ],
        _Variante.vencendo => [
          'Seu atestado ${_venceEm(status)}.',
          'Depois dessa data seu acesso à academia será bloqueado até a '
              'academia validar um novo atestado.',
        ],
        _Variante.bloqueado => [
          status.situacao == SituacaoAtestado.vencido &&
                  status.vencimento != null
              ? 'Seu atestado venceu em ${formatarData(status.vencimento!)}. '
                    'Envie um novo atestado para a academia validar e '
                    'liberar seu acesso.'
              : 'Seu acesso à academia está bloqueado por causa do '
                    'atestado. Envie um novo atestado para a academia '
                    'validar e liberar seu acesso.',
        ],
      },
      if (variante != _Variante.emAnalise && recusa != null) recusa,
    ];

    return AlertDialog(
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: cor.withValues(alpha: 0.12),
        foregroundColor: cor,
        child: Icon(icone),
      ),
      title: Text(titulo, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, p) in paragrafos.indexed) ...[
                if (i > 0) const SizedBox(height: AppTheme.space12),
                Text(
                  p,
                  style: p == recusa
                      ? TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (variante == _Variante.emAnalise)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Entendi'),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enviar novo atestado'),
              ),
              const SizedBox(height: AppTheme.space8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  variante == _Variante.vencendo ? 'Agora não' : 'Fechar',
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Cartão "Atestado médico": vencimento, situação, envio em análise ou
/// recusado e (opcional) o botão pra tela de envio. Usado no Meu Perfil e
/// no topo da tela de envio.
class AtestadoResumoCard extends StatelessWidget {
  const AtestadoResumoCard({
    required this.status,
    this.mostrarBotao = true,
    super.key,
  });

  final AtestadoStatus status;
  final bool mostrarBotao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final urgente =
        status.bloqueado || status.situacao == SituacaoAtestado.vencido;
    final (icone, cor) = urgente
        ? (Icons.lock_outline, scheme.error)
        : status.situacao == SituacaoAtestado.vencendo
        ? (Icons.event_busy_outlined, scheme.secondary)
        : (Icons.verified_outlined, scheme.primary);
    final recusa = textoRecusaAtestado(status);
    final vencimento = status.vencimento;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: status.exigeAtencao ? cor : scheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cor.withValues(alpha: 0.12),
                  foregroundColor: cor,
                  child: Icon(icone, size: 20),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Atestado médico', style: textTheme.titleMedium),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Vencimento: '
                        '${vencimento == null ? 'não informado' : formatarData(vencimento)}',
                        style: textTheme.bodyMedium,
                      ),
                      Text(
                        'Situação: ${textoSituacaoAtestado(status)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: urgente ? scheme.error : null,
                          fontWeight: status.exigeAtencao
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                      if (status.base == 'CADASTRO') ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Validade contada a partir do seu cadastro.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (status.envioPendente) ...[
              const SizedBox(height: AppTheme.space12),
              _Nota(
                icone: Icons.hourglass_top_outlined,
                texto: textoEmAnaliseAtestado(status),
                cor: scheme.tertiary,
              ),
            ] else if (recusa != null) ...[
              const SizedBox(height: AppTheme.space12),
              _Nota(
                icone: Icons.error_outline,
                texto: recusa,
                cor: scheme.error,
              ),
            ],
            if (mostrarBotao) ...[
              const SizedBox(height: AppTheme.space16),
              _BotaoEnvio(status: status, destaque: status.exigeAtencao),
            ],
          ],
        ),
      ),
    );
  }
}

/// Faixa no topo da Minha Agenda quando o acesso está bloqueado pelo
/// atestado vencido.
class AtestadoBloqueadoBanner extends StatelessWidget {
  const AtestadoBloqueadoBanner({required this.status, super.key});

  final AtestadoStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: scheme.error),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seu acesso está bloqueado: atestado vencido.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      status.envioPendente
                          ? textoEmAnaliseAtestado(status)
                          : 'Envie um novo atestado para a academia validar '
                                'e liberar seu acesso.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          _BotaoEnvio(status: status, destaque: !status.envioPendente),
        ],
      ),
    );
  }
}

/// "Enviar novo atestado" (ou, com um envio já em análise, "Ver atestado em
/// análise" — a tela de envio mostra o andamento no lugar do formulário).
class _BotaoEnvio extends StatelessWidget {
  const _BotaoEnvio({required this.status, required this.destaque});

  final AtestadoStatus status;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(
      status.envioPendente ? 'Ver atestado em análise' : 'Enviar novo atestado',
    );
    void abrir() => abrirEnvioAtestado(context);
    return destaque
        ? FilledButton.icon(
            onPressed: abrir,
            icon: const Icon(Icons.upload_file_outlined),
            label: rotulo,
          )
        : OutlinedButton.icon(
            onPressed: abrir,
            icon: Icon(
              status.envioPendente
                  ? Icons.hourglass_top_outlined
                  : Icons.upload_file_outlined,
            ),
            label: rotulo,
          );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icone, required this.texto, required this.cor});

  final IconData icone;
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
