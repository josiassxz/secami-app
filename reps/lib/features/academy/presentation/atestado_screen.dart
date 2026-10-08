import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/cadastro_models.dart' show ufsBrasil;
import '../data/atestado_api.dart';
import 'atestado_widgets.dart';

/// Largura máxima do conteúdo: é uma tela cheia (fora do `HomeShell`), então
/// sem isto o formulário esticaria de borda a borda numa janela larga (web).
const _larguraMaxima = 720.0;

/// Envio de um atestado médico novo pelo aluno (`/academia/atestado`): a
/// situação atual no topo e o formulário (data de emissão, médico, CRM/UF e
/// PDF). O envio vai pra fila de validação da academia; com um envio já em
/// análise, a tela mostra o andamento no lugar do formulário.
class AtestadoScreen extends ConsumerStatefulWidget {
  const AtestadoScreen({super.key});

  @override
  ConsumerState<AtestadoScreen> createState() => _AtestadoScreenState();
}

class _AtestadoScreenState extends ConsumerState<AtestadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicoNomeCtrl = TextEditingController();
  final _medicoCrmCtrl = TextEditingController();
  String? _uf;
  DateTime? _emissao;
  ArquivoPdf? _arquivo;
  String? _erroArquivo;

  /// Depois da 1ª tentativa de envio, data e PDF faltando aparecem em
  /// vermelho (os campos de texto já se validam pelo `Form`).
  bool _tentouEnviar = false;
  bool _enviando = false;
  bool _enviado = false;
  String? _erroEnvio;

  @override
  void dispose() {
    _medicoNomeCtrl.dispose();
    _medicoCrmCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _emissao ?? hoje,
      // Atestado com mais de 1 ano não é aceito (regra do backend).
      firstDate: DateTime(hoje.year, hoje.month, hoje.day - 365),
      lastDate: hoje,
      helpText: 'Data de emissão do atestado',
    );
    if (picked != null && mounted) setState(() => _emissao = picked);
  }

  Future<void> _selecionarArquivo() async {
    setState(() => _erroArquivo = null);
    final ArquivoPdf? arquivo;
    try {
      arquivo = await ref.read(selecionarPdfProvider)();
    } on ArquivoIlegivelException {
      if (mounted) {
        setState(
          () => _erroArquivo = 'Não foi possível ler o arquivo selecionado.',
        );
      }
      return;
    } on Object {
      if (mounted) {
        setState(
          () => _erroArquivo = 'Não foi possível abrir o seletor de arquivos.',
        );
      }
      return;
    }
    if (arquivo == null || !mounted) return;
    if (!arquivo.nome.toLowerCase().endsWith('.pdf')) {
      setState(() => _erroArquivo = 'Selecione um arquivo em PDF.');
      return;
    }
    if (arquivo.tamanho > maxAtestadoBytes) {
      setState(() => _erroArquivo = 'O arquivo deve ter no máximo 10MB.');
      return;
    }
    setState(() => _arquivo = arquivo);
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final camposOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _tentouEnviar = true;
      _erroEnvio = null;
    });
    final emissao = _emissao;
    final arquivo = _arquivo;
    final uf = _uf;
    if (!camposOk || emissao == null || arquivo == null || uf == null) return;

    setState(() => _enviando = true);
    try {
      await ref
          .read(atestadoApiProvider)
          .enviar(
            emissaoData: emissao,
            medicoNome: _medicoNomeCtrl.text.trim(),
            medicoCrm: _medicoCrmCtrl.text.trim(),
            medicoCrmUf: uf,
            arquivo: arquivo,
          );
      if (!mounted) return;
      ref.invalidate(atestadoStatusProvider);
      setState(() => _enviado = true);
    } catch (e) {
      if (!mounted) return;
      // 409 = já existe um envio em análise: recarrega a situação, que
      // passa a mostrar o andamento no lugar do formulário.
      if (e is ApiException && e.status == 409) {
        ref.invalidate(atestadoStatusProvider);
      }
      setState(
        () => _erroEnvio = mensagemDeErro(
          e,
          fallback:
              'Não foi possível enviar o atestado agora. Tente de novo em '
              'instantes.',
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _voltar() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go('/academia');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa sempre (inclusive no estado de sucesso) pra situação recarregar
    // logo depois do envio e as telas por baixo já verem "em análise".
    final statusAsync = ref.watch(atestadoStatusProvider);

    final Widget corpo;
    if (_enviado) {
      corpo = _SucessoView(onVoltar: _voltar);
    } else {
      corpo = statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _conteudo([
          _ErroSituacao(
            onTentarDeNovo: () => ref.invalidate(atestadoStatusProvider),
          ),
          const SizedBox(height: AppTheme.space24),
          _formulario(),
        ]),
        data: (status) {
          if (!status.aplicavel) {
            return _conteudo([
              const _Mensagem(
                icone: Icons.info_outline,
                texto: 'O atestado médico não é exigido para o seu perfil.',
              ),
            ]);
          }
          return _conteudo([
            AtestadoResumoCard(status: status, mostrarBotao: false),
            const SizedBox(height: AppTheme.space24),
            if (status.envioPendente)
              _EmAnalise(status: status, onVoltar: _voltar)
            else
              _formulario(),
          ]);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Atestado médico')),
      body: SafeArea(child: corpo),
    );
  }

  Widget _conteudo(List<Widget> children) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _larguraMaxima),
        // Coluna inteira construída (não um ListView preguiçoso): o
        // formulário não perde estado de validação ao rolar.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _rotulo(String texto) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Text(
        texto,
        style: AppTheme.label(11, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _formulario() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enviar novo atestado', style: textTheme.titleLarge),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Anexe o atestado médico declarando que você está apto(a) para a '
            'prática de exercícios físicos. A academia vai conferir e '
            'validar.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          _rotulo('DATA DE EMISSÃO'),
          _CampoData(
            data: _emissao,
            erro: _tentouEnviar && _emissao == null
                ? 'Informe a data de emissão do atestado.'
                : null,
            onTap: _enviando ? null : _selecionarData,
          ),
          const SizedBox(height: AppTheme.space16),
          _rotulo('NOME DO MÉDICO'),
          TextFormField(
            key: const ValueKey('atestado-medico-nome'),
            controller: _medicoNomeCtrl,
            enabled: !_enviando,
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
                    _rotulo('CRM'),
                    TextFormField(
                      key: const ValueKey('atestado-medico-crm'),
                      controller: _medicoCrmCtrl,
                      enabled: !_enviando,
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
                    _rotulo('UF'),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('atestado-medico-uf'),
                      initialValue: _uf,
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'UF'),
                      items: [
                        for (final uf in ufsBrasil)
                          DropdownMenuItem(value: uf, child: Text(uf)),
                      ],
                      onChanged: _enviando
                          ? null
                          : (v) => setState(() => _uf = v),
                      validator: (v) => v == null ? 'Selecione' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          _rotulo('ATESTADO MÉDICO (PDF, até 10MB)'),
          _CampoArquivo(
            arquivo: _arquivo,
            erro:
                _erroArquivo ??
                (_tentouEnviar && _arquivo == null
                    ? 'Anexe o atestado médico em PDF.'
                    : null),
            onSelecionar: _enviando ? null : _selecionarArquivo,
            onRemover: _enviando ? null : () => setState(() => _arquivo = null),
          ),
          if (_erroEnvio != null) ...[
            const SizedBox(height: AppTheme.space20),
            _ErroBanner(mensagem: _erroEnvio!),
          ],
          const SizedBox(height: AppTheme.space24),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.onLimeAccent,
                    ),
                  )
                : const Text('Enviar atestado'),
          ),
        ],
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({required this.data, required this.erro, this.onTap});

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

class _CampoArquivo extends StatelessWidget {
  const _CampoArquivo({
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

/// Já existe um envio em análise: no lugar do formulário.
class _EmAnalise extends StatelessWidget {
  const _EmAnalise({required this.status, required this.onVoltar});

  final AtestadoStatus status;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: scheme.tertiary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.tertiary),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top_outlined, color: scheme.tertiary),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Atestado em análise', style: textTheme.titleMedium),
                    const SizedBox(height: AppTheme.space4),
                    Text(textoEmAnaliseAtestado(status)),
                    if (status.bloqueado) ...[
                      const SizedBox(height: AppTheme.space4),
                      const Text(
                        'Seu acesso continua bloqueado até a aprovação.',
                      ),
                    ],
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      'Você será avisado aqui no app quando a academia '
                      'concluir a análise.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space24),
        OutlinedButton(onPressed: onVoltar, child: const Text('Voltar')),
      ],
    );
  }
}

class _SucessoView extends StatelessWidget {
  const _SucessoView({required this.onVoltar});

  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              Text(
                'Atestado enviado!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                'A academia vai validar e você será avisado aqui no app.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onVoltar,
                  child: const Text('Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErroSituacao extends StatelessWidget {
  const _ErroSituacao({required this.onTentarDeNovo});

  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
        title: const Text(
          'Não foi possível carregar a situação do seu atestado.',
        ),
        subtitle: const Text('Você ainda pode enviar um atestado novo.'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Tentar novamente',
          onPressed: onTentarDeNovo,
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space32),
      child: Column(
        children: [
          Icon(icone, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppTheme.space12),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErroBanner extends StatelessWidget {
  const _ErroBanner({required this.mensagem});

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
