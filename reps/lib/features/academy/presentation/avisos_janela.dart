import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/rest_auth_service.dart';
import '../data/academy_api.dart';
import '../data/avisos_api.dart';

/// Abre os avisos do admin como janela quando o usuário entra no app (uma
/// vez por sessão, um aviso de cada vez). Cada janela tem "Não mostrar
/// novamente"; sem marcar, o aviso volta na próxima vez que ele entrar,
/// enquanto estiver no período de exibição.
///
/// Falha de rede aqui nunca bloqueia a entrada: sem avisos, segue normal.
class AvisosJanelaGate extends ConsumerStatefulWidget {
  const AvisosJanelaGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AvisosJanelaGate> createState() => _AvisosJanelaGateState();
}

class _AvisosJanelaGateState extends ConsumerState<AvisosJanelaGate> {
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificar());
  }

  Future<void> _verificar() async {
    if (!Env.hasRestApi || _verificando || !mounted) return;
    final user = ref.read(secamiCurrentUserProvider).valueOrNull;
    if (user == null) return;
    if (ref.read(avisosVerificadosParaProvider) == user.id) return;
    ref.read(avisosVerificadosParaProvider.notifier).state = user.id;

    _verificando = true;
    try {
      final api = ref.read(avisosApiProvider);
      final avisos = await api.janela();
      for (var i = 0; i < avisos.length; i++) {
        if (!mounted) return;
        final naoMostrar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AvisoJanela(
            aviso: avisos[i],
            posicao: i + 1,
            total: avisos.length,
          ),
        );
        if (naoMostrar ?? false) {
          // Não espera nem avisa erro: no pior caso o aviso reaparece na
          // próxima entrada.
          unawaited(api.dispensar(avisos[i].id).catchError((Object _) {}));
        }
      }
    } catch (_) {
      // Sem avisos (rede/servidor): segue a entrada normalmente.
    } finally {
      _verificando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Entrou (ou entrou de novo) com o app já aberto: verifica outra vez —
    // a marcação da sessão zera sozinha quando a sessão muda.
    ref.listen(secamiCurrentUserProvider, (_, next) {
      if (next.valueOrNull != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _verificar());
      }
    });
    return widget.child;
  }
}

/// A janela de um aviso. Fecha devolvendo `true` quando o usuário marcou
/// "Não mostrar novamente".
class AvisoJanela extends StatefulWidget {
  const AvisoJanela({
    required this.aviso,
    this.posicao = 1,
    this.total = 1,
    super.key,
  });

  final NoticeDto aviso;
  final int posicao;
  final int total;

  @override
  State<AvisoJanela> createState() => _AvisoJanelaState();
}

class _AvisoJanelaState extends State<AvisoJanela> {
  bool _naoMostrar = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icone, cor) = switch (widget.aviso.type) {
      'warning' => (Icons.warning_amber_outlined, scheme.secondary),
      'success' => (Icons.check_circle_outline, scheme.primary),
      _ => (Icons.campaign_outlined, scheme.tertiary),
    };
    return AlertDialog(
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: cor.withValues(alpha: 0.12),
        foregroundColor: cor,
        child: Icon(icone),
      ),
      title: Column(
        children: [
          if (widget.total > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space4),
              child: Text(
                'Aviso ${widget.posicao} de ${widget.total}',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
            ),
          Text(widget.aviso.title, textAlign: TextAlign.center),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.aviso.content),
              const SizedBox(height: AppTheme.space16),
              CheckboxListTile(
                value: _naoMostrar,
                onChanged: (v) => setState(() => _naoMostrar = v ?? false),
                title: const Text('Não mostrar novamente'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_naoMostrar),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
