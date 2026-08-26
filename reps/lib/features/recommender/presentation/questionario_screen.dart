import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/exercise.dart';
import '../data/recommender_consent.dart';
import '../data/recommender_providers.dart';
import '../domain/questionario.dart';
import '../domain/triagem.dart';
import 'resultado_treino_screen.dart';

/// Questionario do recomendador (RF-003 / RNF-001). Dois modos: `simplificada`
/// (poucas perguntas) e `completa` (perfil + triagem PAR-Q+).
class QuestionarioScreen extends ConsumerStatefulWidget {
  const QuestionarioScreen({super.key, required this.completa});

  final bool completa;

  @override
  ConsumerState<QuestionarioScreen> createState() => _QuestionarioScreenState();
}

class _QuestionarioScreenState extends ConsumerState<QuestionarioScreen> {
  Objetivo? _objetivo;
  PrioridadeMuscular _prioridade = PrioridadeMuscular.corpoTodo;
  NivelExperiencia _experiencia = NivelExperiencia.iniciante;
  int _dias = 3;
  int _minutos = 45;
  LocalTreino? _local;
  final Set<Equipamento> _equipamentos = {};
  final Set<GrupoMuscular> _restricoes = {};

  // Triagem PAR-Q+ (modo completo).
  final Map<String, bool> _triagem = {};
  // Gatilho unico (modo simplificado).
  bool _simplesAlerta = false;
  bool _consentimento = false;
  bool _fadiga = false;
  bool _gerando = false;

  void _selecionarLocal(LocalTreino l) {
    setState(() {
      _local = l;
      _equipamentos
        ..clear()
        ..addAll(l.equipamentosPadrao);
    });
  }

  RespostasTriagem _montarTriagem() {
    if (!widget.completa) {
      // Gatilho unico encaminha por seguranca (tratado como restricao medica).
      return RespostasTriagem(restricaoMedica: _simplesAlerta);
    }
    return RespostasTriagem(
      condicaoCardiaca: _triagem['cardiaca'] ?? false,
      pressaoAltaNaoControlada: _triagem['pressao'] ?? false,
      dorNoPeito: _triagem['peito'] ?? false,
      tonturaDesmaio: _triagem['tontura'] ?? false,
      perdaEquilibrio: _triagem['equilibrio'] ?? false,
      doencaCronicaNaoAcompanhada: _triagem['cronica'] ?? false,
      usaMedicamentos: _triagem['medicamentos'] ?? false,
      lesaoRelevante: _triagem['lesao'] ?? false,
      gestacaoRisco: _triagem['gestacao'] ?? false,
      restricaoMedica: _triagem['restricao'] ?? false,
    );
  }

  String? _erroValidacao() {
    if (_objetivo == null) return 'Escolha o objetivo principal.';
    if (_local == null) return 'Escolha o local de treino.';
    if (_equipamentos.isEmpty) return 'Selecione ao menos um equipamento.';
    return null;
  }

  Future<void> _gerar() async {
    final erro = _erroValidacao();
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    setState(() => _gerando = true);
    try {
      final perfil = PerfilQuestionario(
        objetivo: _objetivo!,
        prioridade: _prioridade,
        experiencia: _experiencia,
        diasPorSemana: _dias,
        minutosPorSessao: _minutos,
        local: _local!,
        equipamentos: _equipamentos,
        restricoesGrupos: _restricoes,
        fadigaElevada: _fadiga,
      );
      // Consentimento controla armazenamento do dado de saude (RN-051).
      await ref.read(healthConsentProvider.notifier).set(_consentimento);
      final treino = await ref
          .read(recommenderServiceProvider)
          .gerar(perfil: perfil, triagem: _montarTriagem());
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultadoTreinoScreen(treino: treino),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao gerar: $e')));
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.completa ? 'Analise completa' : 'Analise rapida'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Secao(
            titulo: 'Objetivo principal',
            icon: Icons.flag_outlined,
            child: _Chips<Objetivo>(
              valores: Objetivo.values,
              selecionado: _objetivo,
              rotulo: (o) => o.label,
              onTap: (o) => setState(() => _objetivo = o),
            ),
          ),
          if (widget.completa)
            _Secao(
              titulo: 'Prioridade muscular',
              icon: Icons.fitness_center_outlined,
              child: _Chips<PrioridadeMuscular>(
                valores: PrioridadeMuscular.values,
                selecionado: _prioridade,
                rotulo: (p) => p.label,
                onTap: (p) => setState(() => _prioridade = p),
              ),
            ),
          if (widget.completa)
            _Secao(
              titulo: 'Experiencia',
              icon: Icons.trending_up,
              child: _Chips<NivelExperiencia>(
                valores: NivelExperiencia.values,
                selecionado: _experiencia,
                rotulo: (n) => n.label,
                onTap: (n) => setState(() => _experiencia = n),
              ),
            ),
          _Secao(
            titulo: 'Dias por semana',
            icon: Icons.calendar_today_outlined,
            child: _Chips<int>(
              valores: const [2, 3, 4, 5, 6],
              selecionado: _dias,
              rotulo: (d) => '$d',
              onTap: (d) => setState(() => _dias = d),
            ),
          ),
          _Secao(
            titulo: 'Minutos por sessao',
            icon: Icons.schedule_outlined,
            child: _Chips<int>(
              valores: const [30, 45, 60, 90],
              selecionado: _minutos,
              rotulo: (m) => '$m min',
              onTap: (m) => setState(() => _minutos = m),
            ),
          ),
          _Secao(
            titulo: 'Local de treino',
            icon: Icons.place_outlined,
            child: _Chips<LocalTreino>(
              valores: LocalTreino.values,
              selecionado: _local,
              rotulo: (l) => l.label,
              onTap: _selecionarLocal,
            ),
          ),
          if (_local != null)
            _Secao(
              titulo: 'Equipamentos disponiveis',
              icon: Icons.inventory_2_outlined,
              child: _ChipsMulti<Equipamento>(
                valores: Equipamento.values,
                selecionados: _equipamentos,
                rotulo: (e) => e.label,
                onToggle: (e) => setState(() {
                  _equipamentos.contains(e)
                      ? _equipamentos.remove(e)
                      : _equipamentos.add(e);
                }),
              ),
            ),
          if (widget.completa)
            _Secao(
              titulo: 'Evitar grupos (lesao/limitacao)',
              icon: Icons.block_outlined,
              child: _ChipsMulti<GrupoMuscular>(
                valores: GrupoMuscular.values,
                selecionados: _restricoes,
                rotulo: (g) => g.label,
                onToggle: (g) => setState(() {
                  _restricoes.contains(g)
                      ? _restricoes.remove(g)
                      : _restricoes.add(g);
                }),
              ),
            ),
          if (widget.completa)
            _Secao(
              titulo: 'Recuperacao',
              icon: Icons.bedtime_outlined,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fadiga,
                onChanged: (v) => setState(() => _fadiga = v),
                title: const Text('Estou com fadiga alta / dormindo mal'),
                subtitle: const Text(
                  'Reduz volume e intensidade temporariamente (RN-040).',
                ),
              ),
            ),
          if (widget.completa) _triagemSecao(scheme) else _gatilhoSimples(),
          const SizedBox(height: 8),
          _disclaimer(scheme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _gerando ? null : _gerar,
            child: _gerando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('GERAR TREINO'),
          ),
        ),
      ),
    );
  }

  Widget _gatilhoSimples() {
    return _Secao(
      titulo: 'Seguranca',
      icon: Icons.shield_outlined,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _simplesAlerta,
        onChanged: (v) => setState(() => _simplesAlerta = v),
        title: const Text(
          'Tenho condicao de saude, dor ou lesao que me preocupa',
        ),
        subtitle: const Text(
          'Se marcar, vamos orientar avaliacao antes de gerar um treino.',
        ),
      ),
    );
  }

  Widget _triagemSecao(ColorScheme scheme) {
    const perguntas = <(String, String)>[
      ('cardiaca', 'Tem alguma condicao cardiaca?'),
      ('pressao', 'Pressao alta nao controlada?'),
      ('peito', 'Sente dor no peito em atividade?'),
      ('tontura', 'Tem tontura ou ja desmaiou?'),
      ('equilibrio', 'Tem perda de equilibrio?'),
      ('cronica', 'Doenca cronica sem acompanhamento?'),
      ('medicamentos', 'Usa medicamentos continuos?'),
      ('lesao', 'Tem lesao relevante?'),
      ('gestacao', 'Gestacao de risco?'),
      ('restricao', 'Tem restricao medica para exercicio?'),
    ];
    return _Secao(
      titulo: 'Triagem de seguranca (PAR-Q+)',
      icon: Icons.health_and_safety_outlined,
      child: Column(
        children: [
          for (final (chave, texto) in perguntas)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _triagem[chave] ?? false,
              onChanged: (v) => setState(() => _triagem[chave] = v),
              title: Text(texto),
            ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consentimento,
            onChanged: (v) => setState(() => _consentimento = v ?? false),
            title: const Text('Autorizo guardar minhas respostas de saude'),
            subtitle: Text(
              'Dado sensivel. Sem isso, geramos o treino mas nao salvamos a '
              'triagem (RN-051).',
              style: AppTheme.label(11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimer(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.outline),
        boxShadow: AppTheme.cardShadow(scheme),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recomendacao educativa. Nao substitui avaliacao de profissional '
              'de Educacao Fisica ou de saude.',
              style: AppTheme.label(11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child, this.icon});

  final String titulo;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(
                titulo.toUpperCase(),
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({
    required this.valores,
    required this.selecionado,
    required this.rotulo,
    required this.onTap,
  });

  final List<T> valores;
  final T? selecionado;
  final String Function(T) rotulo;
  final void Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in valores)
          ChoiceChip(
            label: Text(rotulo(v)),
            selected: v == selecionado,
            onSelected: (_) => onTap(v),
          ),
      ],
    );
  }
}

class _ChipsMulti<T> extends StatelessWidget {
  const _ChipsMulti({
    required this.valores,
    required this.selecionados,
    required this.rotulo,
    required this.onToggle,
  });

  final List<T> valores;
  final Set<T> selecionados;
  final String Function(T) rotulo;
  final void Function(T) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in valores)
          FilterChip(
            label: Text(rotulo(v)),
            selected: selecionados.contains(v),
            onSelected: (_) => onToggle(v),
          ),
      ],
    );
  }
}
