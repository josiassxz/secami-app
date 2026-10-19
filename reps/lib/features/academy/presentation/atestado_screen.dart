import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../data/atestado_api.dart';
import 'atestado_form_campos.dart';
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
    final picked = await selecionarDataEmissaoAtestado(
      context,
      atual: _emissao,
    );
    if (picked != null && mounted) setState(() => _emissao = picked);
  }

  Future<void> _selecionarArquivo() async {
    setState(() => _erroArquivo = null);
    final escolha = await escolherPdfAtestado(ref.read(selecionarPdfProvider));
    if (!mounted) return;
    setState(() {
      _erroArquivo = escolha.erro;
      if (escolha.arquivo != null) _arquivo = escolha.arquivo;
    });
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
          const RotuloCampoAtestado('DATA DE EMISSÃO'),
          CampoDataAtestado(
            data: _emissao,
            erro: _tentouEnviar && _emissao == null
                ? 'Informe a data de emissão do atestado.'
                : null,
            onTap: _enviando ? null : _selecionarData,
          ),
          const SizedBox(height: AppTheme.space16),
          CamposMedicoAtestado(
            nomeController: _medicoNomeCtrl,
            crmController: _medicoCrmCtrl,
            uf: _uf,
            enabled: !_enviando,
            onUfChanged: (v) => setState(() => _uf = v),
          ),
          const SizedBox(height: AppTheme.space20),
          const RotuloCampoAtestado('ATESTADO MÉDICO (PDF, até 10MB)'),
          CampoArquivoAtestado(
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
            ErroBannerAtestado(mensagem: _erroEnvio!),
          ],
          const SizedBox(height: AppTheme.space24),
          BotaoEnviarAtestado(enviando: _enviando, onPressed: _enviar),
        ],
      ),
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
