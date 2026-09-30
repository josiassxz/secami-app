import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/erro_amigavel.dart';
import '../../../core/theme/app_theme.dart';
import '../data/instructor_api.dart';
import 'widgets/instructor_widgets.dart';

/// Lista de alunos da academia para o instrutor escolher de quem vai
/// prescrever a ficha. Busca por nome/CPF (com debounce) e paginação.
class AlunosInstrutorScreen extends ConsumerStatefulWidget {
  const AlunosInstrutorScreen({super.key});

  /// Espera o usuário parar de digitar antes de ir à rede.
  static const debounce = Duration(milliseconds: 350);

  @override
  ConsumerState<AlunosInstrutorScreen> createState() =>
      _AlunosInstrutorScreenState();
}

class _AlunosInstrutorScreenState extends ConsumerState<AlunosInstrutorScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _termo = '';
  List<StudentSummary> _alunos = const [];
  int _proximaPagina = 0;
  bool _temMais = false;
  bool _carregando = true;
  bool _carregandoMais = false;

  /// Depois de uma falha ao paginar, o carregamento automático por rolagem
  /// para (senão cada pixel rolado dispararia outra tentativa + SnackBar); o
  /// botão "Carregar mais" continua disponível.
  bool _falhouAoPaginar = false;
  Object? _erro;

  /// Número da busca corrente: resposta de uma busca antiga (termo anterior)
  /// que chegar atrasada é descartada.
  int _busca = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_aoRolar);
    unawaited(_buscar());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (_falhouAoPaginar || !_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.extentAfter < 320) unawaited(_carregarMais());
  }

  void _aoDigitar(String valor) {
    // Atualiza o botão "limpar" do campo na hora; a busca espera o debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      AlunosInstrutorScreen.debounce,
      () => _aplicarTermo(valor),
    );
  }

  void _aplicarTermo(String valor) {
    _debounce?.cancel();
    final termo = valor.trim();
    if (termo == _termo) return;
    _termo = termo;
    unawaited(_buscar());
  }

  void _limparBusca() {
    _searchCtrl.clear();
    setState(() {});
    _aplicarTermo('');
  }

  /// Carrega a primeira página do termo atual. [silencioso] = puxar pra
  /// atualizar (o RefreshIndicator já mostra o progresso).
  Future<void> _buscar({bool silencioso = false}) async {
    final busca = ++_busca;
    setState(() {
      _carregando = !silencioso;
      _carregandoMais = false;
      _falhouAoPaginar = false;
      // No modo silencioso a tela atual (lista ou erro) fica como está até a
      // resposta chegar — sem piscar o estado vazio no meio.
      if (!silencioso) _erro = null;
    });
    try {
      final page = await ref
          .read(instructorApiProvider)
          .students(q: _termo, page: 0);
      if (!mounted || busca != _busca) return;
      setState(() {
        _erro = null;
        _alunos = page.content;
        _proximaPagina = 1;
        _temMais = !page.last && page.content.isNotEmpty;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted || busca != _busca) return;
      setState(() {
        _alunos = const [];
        _temMais = false;
        _erro = e;
        _carregando = false;
      });
    }
  }

  Future<void> _carregarMais() async {
    if (_carregando || _carregandoMais || !_temMais) return;
    final busca = _busca;
    setState(() {
      _carregandoMais = true;
      _falhouAoPaginar = false;
    });
    try {
      final page = await ref
          .read(instructorApiProvider)
          .students(q: _termo, page: _proximaPagina);
      if (!mounted || busca != _busca) return;
      // Se a lista mudou no servidor entre uma página e outra, um aluno pode
      // vir repetido — não duplica na tela.
      final vistos = {for (final a in _alunos) a.id};
      setState(() {
        _alunos = [..._alunos, ...page.content.where((a) => vistos.add(a.id))];
        _proximaPagina++;
        _temMais = !page.last && page.content.isNotEmpty;
        _carregandoMais = false;
      });
    } catch (e) {
      if (!mounted || busca != _busca) return;
      setState(() {
        _carregandoMais = false;
        _falhouAoPaginar = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(
              e,
              fallback: 'Não foi possível carregar mais alunos.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alunos')),
      body: InstructorContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space16,
                AppTheme.space8,
                AppTheme.space16,
                AppTheme.space8,
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _aoDigitar,
                onSubmitted: _aplicarTermo,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou CPF',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Limpar busca',
                          onPressed: _limparBusca,
                        ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _buscar(silencioso: true),
                child: _corpo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return _ListaDeEstado(
        child: InstructorMessage(
          icon: Icons.error_outline,
          isError: true,
          message: mensagemDeErro(
            _erro,
            fallback: 'Não foi possível carregar os alunos.',
          ),
          actionLabel: 'Tentar novamente',
          onAction: _buscar,
        ),
      );
    }
    if (_alunos.isEmpty) {
      return _ListaDeEstado(
        child: InstructorMessage(
          icon: Icons.person_search_outlined,
          message: 'Nenhum aluno encontrado.',
          hint: _termo.isEmpty ? null : 'Confira o nome ou o CPF digitado.',
        ),
      );
    }
    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space8,
        AppTheme.space16,
        AppTheme.space24,
      ),
      itemCount: _alunos.length + (_temMais ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space8),
      itemBuilder: (context, i) {
        if (i >= _alunos.length) return _rodape();
        final aluno = _alunos[i];
        return _AlunoTile(
          aluno: aluno,
          onTap: () => context.push(
            '/instrutor/aluno/${aluno.id}',
            extra: aluno.fullName,
          ),
        );
      },
    );
  }

  /// Último item enquanto há mais páginas: progresso ou botão (a rolagem já
  /// carrega sozinha; o botão cobre tela larga, onde a 1ª página pode caber
  /// inteira sem rolar, e a retomada depois de uma falha).
  Widget _rodape() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Center(
        child: _carregandoMais
            ? const SizedBox(
                height: 48,
                width: 48,
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.space12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _carregarMais,
                child: const Text('Carregar mais'),
              ),
      ),
    );
  }
}

/// Envolve um estado (vazio/erro) numa lista rolável pra que o gesto de
/// "puxar pra atualizar" continue funcionando sem itens.
class _ListaDeEstado extends StatelessWidget {
  const _ListaDeEstado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [child],
    );
  }
}

class _AlunoTile extends StatelessWidget {
  const _AlunoTile({required this.aluno, required this.onTap});

  final StudentSummary aluno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secretaria = aluno.departmentName?.trim() ?? '';
    final subtitulo = secretaria.isEmpty
        ? aluno.studentType
        : '${aluno.studentType} · $secretaria';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            iniciais(aluno.fullName),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        title: Text(
          aluno.fullName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(subtitulo),
            if (!aluno.isAtivo)
              InstructorBadge(
                label: _rotuloSituacao(aluno.situacao),
                color: aluno.situacao == 'BLOQUEADO' ? scheme.error : null,
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

String _rotuloSituacao(String situacao) => switch (situacao) {
  'INATIVO' => 'Inativo',
  'BLOQUEADO' => 'Bloqueado',
  _ =>
    situacao.isEmpty
        ? 'Indefinido'
        : situacao[0].toUpperCase() + situacao.substring(1).toLowerCase(),
};
