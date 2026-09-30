import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/cadastro_service.dart';
import '../domain/cadastro_models.dart';

const int _maxAtestadoBytes = 10 * 1024 * 1024; // 10MB

const List<String> _tituloDosPassos = [
  'Dados pessoais',
  'Questionário de saúde',
  'Termos',
  'Atestado médico',
];

/// Auto-cadastro publico de aluno civil/militar sem conta (backend
/// `POST /cadastro`). Fluxo em 4 passos + tela de confirmacao — o cadastro
/// fica pendente de aprovacao do admin apos o envio.
class CadastroScreen extends ConsumerStatefulWidget {
  const CadastroScreen({super.key});

  @override
  ConsumerState<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends ConsumerState<CadastroScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  bool _success = false;
  String? _erroEnvio;

  // ---- Passo 1: dados pessoais ----
  final _step1FormKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  DateTime? _nascimento;
  String? _departamentoId;
  final Set<String> _objetivosSelecionados = {};
  bool _obscureSenha = true;
  bool _obscureConfirma = true;

  // ---- Passo 2: PAR-Q ----
  final Map<String, bool?> _parQ = {
    for (final p in parQPerguntas) p.chave: null,
  };

  // ---- Passo 3: termos ----
  bool _termoResponsabilidade = false;
  bool _termoCiencia = false;

  // ---- Passo 4: atestado ----
  final _step4FormKey = GlobalKey<FormState>();
  final _medicoNomeCtrl = TextEditingController();
  final _medicoCrmCtrl = TextEditingController();
  String? _medicoCrmUf;
  DateTime? _atestadoData;
  PlatformFile? _arquivo;
  String? _erroArquivo;

  @override
  void dispose() {
    _pageController.dispose();
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _medicoNomeCtrl.dispose();
    _medicoCrmCtrl.dispose();
    super.dispose();
  }

  // ---- Navegacao entre passos ----

  void _goToStep(int step) {
    setState(() => _step = step);
    unawaited(
      _pageController.animateToPage(
        step,
        duration: AppTheme.motionBase,
        curve: AppTheme.easingStandard,
      ),
    );
  }

  void _voltar() {
    if (_step > 0) {
      _goToStep(_step - 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sign-in');
    }
  }

  void _continuar() {
    final erro = _validarPasso(_step);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    if (_step == _tituloDosPassos.length - 1) {
      unawaited(_enviar());
      return;
    }
    _goToStep(_step + 1);
  }

  String? _validarPasso(int step) {
    switch (step) {
      case 0:
        if (!_step1FormKey.currentState!.validate()) {
          return 'Confira os campos destacados.';
        }
        if (_nascimento == null) return 'Informe a data de nascimento.';
        if (_departamentoId == null) {
          return 'Selecione a secretaria/órgão.';
        }
        return null;
      case 1:
        if (_parQ.values.any((v) => v == null)) {
          return 'Responda todas as 10 perguntas do questionário.';
        }
        return null;
      case 2:
        if (!_termoResponsabilidade || !_termoCiencia) {
          return 'É necessário concordar com os dois termos para '
              'continuar.';
        }
        return null;
      case 3:
        if (!_step4FormKey.currentState!.validate()) {
          return 'Confira os campos destacados.';
        }
        if (_medicoCrmUf == null) return 'Selecione a UF do CRM.';
        if (_atestadoData == null) {
          return 'Informe a data de emissão do atestado.';
        }
        if (_arquivo == null) return 'Anexe o atestado médico em PDF.';
        return null;
      default:
        return null;
    }
  }

  // ---- Selecao de arquivo (file_picker — mobile e web) ----

  Future<void> _selecionarArquivo() async {
    setState(() => _erroArquivo = null);
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
    } on Object {
      setState(
        () => _erroArquivo = 'Não foi possível abrir o seletor de arquivos.',
      );
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      setState(
        () => _erroArquivo = 'Não foi possível ler o arquivo selecionado.',
      );
      return;
    }
    if (file.bytes!.lengthInBytes > _maxAtestadoBytes) {
      setState(() => _erroArquivo = 'O arquivo deve ter no máximo 10MB.');
      return;
    }
    setState(() {
      _arquivo = file;
      _erroArquivo = null;
    });
  }

  // ---- Datas ----

  Future<void> _selecionarNascimento() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _nascimento = picked);
  }

  Future<void> _selecionarDataAtestado() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Data de emissão do atestado',
    );
    if (picked != null) setState(() => _atestadoData = picked);
  }

  // ---- Envio ----

  double? _parseDouble(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _enviar() async {
    setState(() {
      _submitting = true;
      _erroEnvio = null;
    });
    try {
      final respostas = <String, bool>{
        for (final entry in _parQ.entries) entry.key: entry.value!,
      };
      final request = CadastroRequest(
        fullName: _nomeCtrl.text.trim(),
        cpf: _cpfCtrl.text.trim(),
        birthDate: _nascimento!,
        whatsapp: _whatsappCtrl.text.trim(),
        departmentId: _departamentoId!,
        email: _emailCtrl.text.trim(),
        password: _senhaCtrl.text,
        weightKg: _parseDouble(_pesoCtrl.text),
        heightCm: _parseDouble(_alturaCtrl.text),
        objetivos: _objetivosSelecionados.toList(),
        parQ: ParQRespostas(respostas: respostas),
        termoResponsabilidade: _termoResponsabilidade,
        termoCiencia: _termoCiencia,
        medicoNome: _medicoNomeCtrl.text.trim(),
        medicoCrm: _medicoCrmCtrl.text.trim(),
        medicoCrmUf: _medicoCrmUf!,
        atestadoEmissaoData: _atestadoData!,
      );
      await ref.read(cadastroServiceProvider).enviar(request, _arquivo!);
      if (!mounted) return;
      setState(() => _success = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroEnvio = _humanizarErro(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanizarErro(Object e) {
    if (e is CadastroApiException) return e.message;
    return 'Não foi possível enviar o cadastro agora. Tente de novo em '
        'instantes.';
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return _CadastroSucessoView(onVoltarLogin: () => context.go('/sign-in'));
    }
    final scheme = Theme.of(context).colorScheme;
    final ultimoPasso = _step == _tituloDosPassos.length - 1;

    return PopScope(
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goToStep(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cadastro de aluno'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _submitting ? null : _voltar,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressoHeader(
                passo: _step,
                total: _tituloDosPassos.length,
                titulo: _tituloDosPassos[_step],
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _passo1DadosPessoais(scheme),
                    _passo2ParQ(scheme),
                    _passo3Termos(scheme),
                    _passo4Atestado(scheme),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_erroEnvio != null) ...[
                  _ErroBanner(mensagem: _erroEnvio!),
                  const SizedBox(height: AppTheme.space12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : _voltar,
                        child: Text(_step == 0 ? 'Cancelar' : 'Voltar'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting ? null : _continuar,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.onLimeAccent,
                                ),
                              )
                            : Text(
                                ultimoPasso ? 'Enviar cadastro' : 'Continuar',
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoLabel(String texto, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Text(
        texto,
        style: AppTheme.label(11, color: scheme.onSurfaceVariant),
      ),
    );
  }

  String? _validarNumeroOpcional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final parsed = double.tryParse(t.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return 'Valor inválido';
    return null;
  }

  // ---- Passo 1 ----

  Widget _passo1DadosPessoais(ColorScheme scheme) {
    return SingleChildScrollView(
      key: const PageStorageKey('cadastro-passo-1'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campoLabel('NOME COMPLETO', scheme),
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Informe seu nome completo'
                  : null,
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('CPF', scheme),
            TextFormField(
              controller: _cpfCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(hintText: 'Somente números'),
              validator: (v) {
                final digitos = (v ?? '').trim();
                if (digitos.length != 11) return 'CPF deve ter 11 dígitos';
                if (!_cpfValido(digitos)) return 'CPF inválido';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('DATA DE NASCIMENTO', scheme),
            _DateField(
              data: _nascimento,
              dica: 'Toque para selecionar',
              onTap: _selecionarNascimento,
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('WHATSAPP', scheme),
            TextFormField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                hintText: 'DDD + número, só números',
              ),
              validator: (v) {
                final digitos = (v ?? '').trim();
                if (digitos.length < 10 || digitos.length > 11) {
                  return 'Informe DDD + número (10 ou 11 dígitos)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('SECRETARIA / ÓRGÃO', scheme),
            _DepartamentoField(
              valor: _departamentoId,
              onChanged: (v) => setState(() => _departamentoId = v),
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('E-MAIL', scheme),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'nome@goias.gov.br'),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Informe o e-mail';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'E-mail inválido';
                }
                if (!value.toLowerCase().endsWith('@goias.gov.br')) {
                  return 'O e-mail precisa ser do domínio @goias.gov.br';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('SENHA', scheme),
            TextFormField(
              controller: _senhaCtrl,
              obscureText: _obscureSenha,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                hintText: 'Mínimo de 8 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureSenha = !_obscureSenha),
                ),
              ),
              validator: (v) => (v == null || v.length < 8)
                  ? 'A senha deve ter no mínimo 8 caracteres'
                  : null,
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('CONFIRMAR SENHA', scheme),
            TextFormField(
              controller: _confirmaSenhaCtrl,
              obscureText: _obscureConfirma,
              decoration: InputDecoration(
                hintText: 'Repita a senha',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirma
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirma = !_obscureConfirma),
                ),
              ),
              validator: (v) =>
                  (v != _senhaCtrl.text) ? 'As senhas não conferem' : null,
            ),
            const SizedBox(height: AppTheme.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campoLabel('PESO (KG) — opcional', scheme),
                      TextFormField(
                        controller: _pesoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validarNumeroOpcional,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campoLabel('ALTURA (CM) — opcional', scheme),
                      TextFormField(
                        controller: _alturaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validarNumeroOpcional,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('OBJETIVOS — opcional', scheme),
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in cadastroObjetivos)
                  FilterChip(
                    label: Text(o),
                    selected: _objetivosSelecionados.contains(o),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _objetivosSelecionados.add(o);
                      } else {
                        _objetivosSelecionados.remove(o);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Passo 2: PAR-Q ----

  Widget _passo2ParQ(ColorScheme scheme) {
    return ListView(
      key: const PageStorageKey('cadastro-passo-2'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _InfoBox(
          icon: Icons.health_and_safety_outlined,
          texto:
              'Questionário de prontidão para atividade física (PAR-Q). '
              'Responda com atenção — todas as 10 perguntas são '
              'obrigatórias.',
        ),
        for (final p in parQPerguntas) ...[
          const SizedBox(height: AppTheme.space16),
          _ParQCard(
            texto: p.texto,
            valor: _parQ[p.chave],
            onChanged: (v) => setState(() => _parQ[p.chave] = v),
          ),
        ],
      ],
    );
  }

  // ---- Passo 3: termos ----

  Widget _passo3Termos(ColorScheme scheme) {
    return ListView(
      key: const PageStorageKey('cadastro-passo-3'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _TermoBloco(
          titulo: 'Termo de responsabilidade',
          texto:
              'Pelo presente instrumento, declaro que as informações '
              'prestadas neste questionário são a expressão da verdade e '
              'que não omiti qualquer fato sobre meu estado de saúde. '
              'Estou ciente de que a prática de atividades físicas envolve '
              'riscos e, para minha segurança, compreendo que a liberação '
              'do meu acesso à Academia Espaço Saúde está estritamente '
              'condicionada à apresentação de avaliação médica atualizada.',
          aceito: _termoResponsabilidade,
          rotuloCheckbox: 'Li e concordo com os termos acima.',
          onChanged: (v) => setState(() => _termoResponsabilidade = v),
        ),
        const SizedBox(height: AppTheme.space24),
        _TermoBloco(
          titulo: 'Termo de ciência',
          texto:
              'Comprometo-me a informar imediatamente à coordenação da '
              'Academia caso ocorra qualquer alteração em meu estado de '
              'saúde que possa limitar ou impedir a continuidade dos '
              'treinos. Declaro estar ciente de que o uso das dependências '
              'da academia sem a devida aptidão médica é de minha inteira '
              'e exclusiva responsabilidade. Autorizo a guarda digital '
              'deste documento pela administração para fins de comprovação '
              'técnica e fiscalização.',
          aceito: _termoCiencia,
          rotuloCheckbox: 'Li e estou ciente do exposto acima.',
          onChanged: (v) => setState(() => _termoCiencia = v),
        ),
      ],
    );
  }

  // ---- Passo 4: atestado ----

  Widget _passo4Atestado(ColorScheme scheme) {
    return SingleChildScrollView(
      key: const PageStorageKey('cadastro-passo-4'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _step4FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AvisoBox(
              texto:
                  'Conforme as normas de segurança desta unidade, é '
                  'obrigatória a anexação do atestado médico original, '
                  'emitido por cardiologista, devidamente registrado no '
                  'Conselho Regional de Medicina (CRM), declarando '
                  'expressamente que o(a) aluno(a) está APTO(A) para a '
                  'prática de exercícios físicos.',
            ),
            const SizedBox(height: AppTheme.space20),
            _campoLabel('NOME DO MÉDICO', scheme),
            TextFormField(
              controller: _medicoNomeCtrl,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campoLabel('CRM', scheme),
                      TextFormField(
                        controller: _medicoCrmCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campoLabel('UF', scheme),
                      DropdownButtonFormField<String>(
                        initialValue: _medicoCrmUf,
                        decoration: const InputDecoration(hintText: 'UF'),
                        items: [
                          for (final uf in ufsBrasil)
                            DropdownMenuItem(value: uf, child: Text(uf)),
                        ],
                        onChanged: (v) => setState(() => _medicoCrmUf = v),
                        validator: (v) => v == null ? 'Selecione' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            _campoLabel('DATA DE EMISSÃO DO ATESTADO', scheme),
            _DateField(
              data: _atestadoData,
              dica: 'Toque para selecionar',
              onTap: _selecionarDataAtestado,
            ),
            const SizedBox(height: AppTheme.space20),
            _campoLabel('ATESTADO MÉDICO (PDF, até 10MB)', scheme),
            _ArquivoField(
              arquivo: _arquivo,
              erro: _erroArquivo,
              onSelecionar: _selecionarArquivo,
              onRemover: () => setState(() => _arquivo = null),
            ),
          ],
        ),
      ),
    );
  }
}

bool _cpfValido(String cpf) {
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
  final digitos = cpf.split('').map(int.parse).toList();

  int digitoVerificador(List<int> base) {
    var peso = base.length + 1;
    var soma = 0;
    for (final d in base) {
      soma += d * peso;
      peso--;
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  final d1 = digitoVerificador(digitos.sublist(0, 9));
  final d2 = digitoVerificador([...digitos.sublist(0, 9), d1]);
  return d1 == digitos[9] && d2 == digitos[10];
}

class _ProgressoHeader extends StatelessWidget {
  const _ProgressoHeader({
    required this.passo,
    required this.total,
    required this.titulo,
  });

  final int passo;
  final int total;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PASSO ${passo + 1} DE $total',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              Text(titulo, style: AppTheme.label(11, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (passo + 1) / total,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.outline),
        boxShadow: AppTheme.cardShadow(scheme),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              texto,
              style: AppTheme.label(11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoBox extends StatelessWidget {
  const _AvisoBox({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 18, color: scheme.error),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(texto, style: AppTheme.label(11, color: scheme.error)),
          ),
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
        borderRadius: BorderRadius.circular(12),
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.data,
    required this.dica,
    required this.onTap,
  });

  final DateTime? data;
  final String dica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = data == null ? null : DateFormat('dd/MM/yyyy').format(data!);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
        child: Text(
          texto ?? dica,
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

class _DepartamentoField extends ConsumerWidget {
  const _DepartamentoField({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(departamentosProvider);
    final scheme = Theme.of(context).colorScheme;
    return async.when(
      loading: () => InputDecorator(
        decoration: const InputDecoration(hintText: 'Carregando…'),
        child: Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              'Carregando secretarias/órgãos…',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      error: (e, _) => InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => ref.invalidate(departamentosProvider),
        child: InputDecorator(
          decoration: InputDecoration(
            errorText:
                'Não foi possível carregar a lista. Toque para '
                'tentar de novo.',
            suffixIcon: Icon(Icons.refresh, color: scheme.error),
          ),
          child: const Text(''),
        ),
      ),
      data: (deps) {
        final valido = deps.any((d) => d.id == valor) ? valor : null;
        return DropdownButtonFormField<String>(
          initialValue: valido,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Selecione'),
          items: [
            for (final d in deps)
              DropdownMenuItem(
                value: d.id,
                child: Text(d.rotulo, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          validator: (v) => v == null ? 'Selecione a secretaria/órgão' : null,
        );
      },
    );
  }
}

class _ParQCard extends StatelessWidget {
  const _ParQCard({
    required this.texto,
    required this.valor,
    required this.onChanged,
  });

  final String texto;
  final bool? valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: _OpcaoSimNao(
                    label: 'Sim',
                    selecionado: valor == true,
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _OpcaoSimNao(
                    label: 'Não',
                    selecionado: valor == false,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoSimNao extends StatelessWidget {
  const _OpcaoSimNao({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: selecionado ? scheme.primary : Colors.transparent,
        foregroundColor: selecionado ? scheme.onPrimary : scheme.onSurface,
        side: BorderSide(color: selecionado ? scheme.primary : scheme.outline),
      ),
      child: Text(label),
    );
  }
}

class _TermoBloco extends StatelessWidget {
  const _TermoBloco({
    required this.titulo,
    required this.texto,
    required this.aceito,
    required this.rotuloCheckbox,
    required this.onChanged,
  });

  final String titulo;
  final String texto;
  final bool aceito;
  final String rotuloCheckbox;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.outline),
        boxShadow: AppTheme.cardShadow(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppTheme.space8),
          Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: aceito,
            onChanged: (v) => onChanged(v ?? false),
            title: Text(
              rotuloCheckbox,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArquivoField extends StatelessWidget {
  const _ArquivoField({
    required this.arquivo,
    required this.erro,
    required this.onSelecionar,
    required this.onRemover,
  });

  final PlatformFile? arquivo;
  final String? erro;
  final VoidCallback onSelecionar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (arquivo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onSelecionar,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Selecionar arquivo PDF'),
          ),
          if (erro != null) ...[
            const SizedBox(height: AppTheme.space8),
            Text(erro!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
        ],
      );
    }
    final tamanhoKb = (arquivo!.size / 1024).toStringAsFixed(0);
    return Container(
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
                  arquivo!.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '$tamanhoKb KB',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remover',
            onPressed: onRemover,
          ),
        ],
      ),
    );
  }
}

class _CadastroSucessoView extends StatelessWidget {
  const _CadastroSucessoView({required this.onVoltarLogin});

  final VoidCallback onVoltarLogin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Center(
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
                  'Cadastro enviado!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'Seu acesso ficará pendente até a administração da '
                  'academia analisar seus dados. Você vai poder entrar '
                  'assim que for aprovado.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onVoltarLogin,
                    child: const Text('Voltar ao login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
