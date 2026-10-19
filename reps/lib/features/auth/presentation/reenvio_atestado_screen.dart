import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../academy/data/atestado_api.dart';
import '../../academy/presentation/atestado_form_campos.dart';
import '../data/cadastro_service.dart';

/// Rota pública do reenvio de atestado depois de um cadastro recusado.
const rotaReenvioAtestado = '/cadastro/reenvio';

/// O que a tela de login passa pra cá (via `GoRouterState.extra`, só em
/// memória — nunca persistido nem logado). Sem `extra` (refresh da página
/// no web) a tela pede pra voltar ao login.
class ReenvioAtestadoArgs {
  const ReenvioAtestadoArgs({
    required this.identificador,
    required this.senha,
    required this.mensagemRecusa,
  });

  final String identificador;
  final String senha;

  /// "Seu cadastro foi recusado: `motivo`", como veio do backend.
  final String mensagemRecusa;

  // Nunca expõe a senha num log/print acidental.
  @override
  String toString() => 'ReenvioAtestadoArgs($identificador)';
}

const _larguraMaxima = 720.0;

/// Aluno com cadastro recusado manda um atestado novo sem estar logado
/// (`POST /cadastro/reenvio`). Em sucesso o cadastro volta pra análise.
class ReenvioAtestadoScreen extends ConsumerStatefulWidget {
  const ReenvioAtestadoScreen({super.key, required this.args});

  final ReenvioAtestadoArgs? args;

  @override
  ConsumerState<ReenvioAtestadoScreen> createState() =>
      _ReenvioAtestadoScreenState();
}

class _ReenvioAtestadoScreenState extends ConsumerState<ReenvioAtestadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicoNomeCtrl = TextEditingController();
  final _medicoCrmCtrl = TextEditingController();
  String? _uf;
  DateTime? _emissao;
  ArquivoPdf? _arquivo;
  String? _erroArquivo;
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

  Future<void> _enviar(ReenvioAtestadoArgs args) async {
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
          .read(cadastroServiceProvider)
          .reenviarAtestado(
            identificador: args.identificador,
            senha: args.senha,
            medicoNome: _medicoNomeCtrl.text.trim(),
            medicoCrm: _medicoCrmCtrl.text.trim(),
            medicoCrmUf: uf,
            emissaoData: emissao,
            arquivo: arquivo,
          );
      if (!mounted) return;
      setState(() => _enviado = true);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _erroEnvio = e is CadastroApiException
            ? e.message
            : 'Não foi possível enviar o atestado agora. Tente de novo em '
                  'instantes.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Volta pro login avisando que o envio deu certo (o login limpa o erro
  /// de "cadastro recusado"); sem tela anterior, abre o login direto.
  void _voltarAoLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(_enviado);
    } else {
      GoRouter.of(context).go('/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final Widget corpo;
    if (args == null) {
      corpo = _Aviso(
        icone: Icons.login,
        titulo: 'Entre novamente',
        texto:
            'Para enviar um novo atestado, digite seu usuário e senha na tela '
            'de login.',
        botao: 'Ir para o login',
        onPressed: () => GoRouter.of(context).go('/sign-in'),
      );
    } else if (_enviado) {
      corpo = _Aviso(
        icone: Icons.check_circle_outline,
        titulo: 'Atestado enviado!',
        texto:
            'Seu cadastro voltou para análise. Você será avisado quando for '
            'aprovado.',
        botao: 'Voltar ao login',
        onPressed: _voltarAoLogin,
      );
    } else {
      corpo = _formulario(args);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo atestado médico'),
        // Depois do envio, a saída é só pelo "Voltar ao login".
        automaticallyImplyLeading: !_enviado,
      ),
      body: SafeArea(child: corpo),
    );
  }

  Widget _formulario(ReenvioAtestadoArgs args) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _larguraMaxima),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MotivoRecusa(mensagem: args.mensagemRecusa),
                const SizedBox(height: AppTheme.space24),
                Text('Enviar novo atestado', style: textTheme.titleLarge),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Anexe um atestado médico declarando que você está apto(a) '
                  'para a prática de exercícios físicos. Seu cadastro volta '
                  'para a análise da academia.',
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
                  onRemover: _enviando
                      ? null
                      : () => setState(() => _arquivo = null),
                ),
                if (_erroEnvio != null) ...[
                  const SizedBox(height: AppTheme.space20),
                  ErroBannerAtestado(mensagem: _erroEnvio!),
                ],
                const SizedBox(height: AppTheme.space24),
                BotaoEnviarAtestado(
                  enviando: _enviando,
                  onPressed: () => _enviar(args),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotivoRecusa extends StatelessWidget {
  const _MotivoRecusa({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.error),
          const SizedBox(width: AppTheme.space12),
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

/// Estado de tela inteira com ícone, título, texto e um botão.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.botao,
    required this.onPressed,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final String botao;
  final VoidCallback onPressed;

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
                child: Icon(icone, size: 48, color: scheme.primary),
              ),
              const SizedBox(height: AppTheme.space24),
              Text(
                titulo,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                texto,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onPressed, child: Text(botao)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
