import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/cadastro_models.dart' show ufsBrasil;
import '../data/atestado_api.dart';
import 'atestado_widgets.dart' show formatarData;

/// Campos do formulário de envio de atestado médico, compartilhados pela
/// tela do aluno logado (`AtestadoScreen`) e pelo reenvio público depois de
/// um cadastro recusado (`ReenvioAtestadoScreen`).

/// Abre o calendário pra data de emissão: de hoje-365 dias até hoje
/// (atestado com mais de 1 ano não é aceito — regra do backend).
Future<DateTime?> selecionarDataEmissaoAtestado(
  BuildContext context, {
  DateTime? atual,
}) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  return showDatePicker(
    context: context,
    initialDate: atual ?? hoje,
    firstDate: DateTime(hoje.year, hoje.month, hoje.day - 365),
    lastDate: hoje,
    helpText: 'Data de emissão do atestado',
  );
}

/// Resultado da escolha do PDF: o arquivo aceito, um erro pra mostrar no
/// campo, ou nada (o aluno cancelou o seletor).
typedef EscolhaPdf = ({ArquivoPdf? arquivo, String? erro});

/// Abre o [selecionar] (seletor do aparelho) e confere o arquivo: precisa
/// ser `.pdf` e ter no máximo [maxAtestadoBytes].
Future<EscolhaPdf> escolherPdfAtestado(
  Future<ArquivoPdf?> Function() selecionar,
) async {
  final ArquivoPdf? arquivo;
  try {
    arquivo = await selecionar();
  } on ArquivoIlegivelException {
    return (arquivo: null, erro: 'Não foi possível ler o arquivo selecionado.');
  } on Object {
    return (
      arquivo: null,
      erro: 'Não foi possível abrir o seletor de arquivos.',
    );
  }
  if (arquivo == null) return (arquivo: null, erro: null);
  if (!arquivo.nome.toLowerCase().endsWith('.pdf')) {
    return (arquivo: null, erro: 'Selecione um arquivo em PDF.');
  }
  if (arquivo.tamanho > maxAtestadoBytes) {
    return (arquivo: null, erro: 'O arquivo deve ter no máximo 10MB.');
  }
  return (arquivo: arquivo, erro: null);
}

/// Rótulo em caixa alta acima de cada campo.
class RotuloCampoAtestado extends StatelessWidget {
  const RotuloCampoAtestado(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Text(
        texto,
        style: AppTheme.label(11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class CampoDataAtestado extends StatelessWidget {
  const CampoDataAtestado({
    super.key,
    required this.data,
    required this.erro,
    this.onTap,
  });

  final DateTime? data;
  final String? erro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = data == null ? null : formatarData(data!);
    return InkWell(
      key: const ValueKey('atestado-data-emissao'),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: erro,
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
        child: Text(
          texto ?? 'Toque para selecionar',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: texto == null
                ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Nome do médico, CRM e UF do CRM (validados pelo `Form` em volta).
class CamposMedicoAtestado extends StatelessWidget {
  const CamposMedicoAtestado({
    super.key,
    required this.nomeController,
    required this.crmController,
    required this.uf,
    required this.onUfChanged,
    this.enabled = true,
  });

  final TextEditingController nomeController;
  final TextEditingController crmController;
  final String? uf;
  final ValueChanged<String?> onUfChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloCampoAtestado('NOME DO MÉDICO'),
        TextFormField(
          key: const ValueKey('atestado-medico-nome'),
          controller: nomeController,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Informe o nome do médico'
              : null,
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RotuloCampoAtestado('CRM'),
                  TextFormField(
                    key: const ValueKey('atestado-medico-crm'),
                    controller: crmController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o CRM'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RotuloCampoAtestado('UF'),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('atestado-medico-uf'),
                    initialValue: uf,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'UF'),
                    items: [
                      for (final uf in ufsBrasil)
                        DropdownMenuItem(value: uf, child: Text(uf)),
                    ],
                    onChanged: enabled ? onUfChanged : null,
                    validator: (v) => v == null ? 'Selecione' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CampoArquivoAtestado extends StatelessWidget {
  const CampoArquivoAtestado({
    super.key,
    required this.arquivo,
    required this.erro,
    this.onSelecionar,
    this.onRemover,
  });

  final ArquivoPdf? arquivo;
  final String? erro;
  final VoidCallback? onSelecionar;
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final escolhido = arquivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (escolhido == null)
          OutlinedButton.icon(
            onPressed: onSelecionar,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Selecionar arquivo PDF'),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: scheme.primary),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        escolhido.nome,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${(escolhido.tamanho / 1024).ceil()} KB',
                        style: AppTheme.label(
                          11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remover arquivo',
                  onPressed: onRemover,
                ),
              ],
            ),
          ),
        if (erro != null) ...[
          const SizedBox(height: AppTheme.space8),
          Text(erro!, style: TextStyle(color: scheme.error, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Faixa vermelha com a mensagem de erro do envio.
class ErroBannerAtestado extends StatelessWidget {
  const ErroBannerAtestado({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        border: Border.all(color: scheme.error),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              mensagem,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão principal "Enviar atestado", com progresso durante o envio.
class BotaoEnviarAtestado extends StatelessWidget {
  const BotaoEnviarAtestado({
    super.key,
    required this.enviando,
    required this.onPressed,
  });

  final bool enviando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enviando ? null : onPressed,
      child: enviando
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.onLimeAccent,
              ),
            )
          : const Text('Enviar atestado'),
    );
  }
}
