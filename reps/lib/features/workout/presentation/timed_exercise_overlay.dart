import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/logging/observability.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/data/settings_providers.dart';

/// Timer regressivo para exercicios medidos por tempo (prancha, isometria,
/// farmer carry). Espelha o `RestTimerOverlay` mas, em vez de descanso, cronometra
/// a execucao da serie. Ao fechar, retorna via `Navigator.pop<int>` a duracao
/// efetivamente executada em segundos (alvo cheio se estourou, ou o tempo
/// decorrido se o usuario concluiu antes).
class TimedExerciseOverlay extends ConsumerStatefulWidget {
  const TimedExerciseOverlay({
    required this.alvoSegundos,
    this.nomeExercicio,
    super.key,
  });

  final int alvoSegundos;
  final String? nomeExercicio;

  @override
  ConsumerState<TimedExerciseOverlay> createState() =>
      _TimedExerciseOverlayState();
}

class _TimedExerciseOverlayState extends ConsumerState<TimedExerciseOverlay> {
  late int _restante;
  late int _total;
  Timer? _timer;
  bool _paused = false;
  final _player = AudioPlayer();
  bool _fired = false;

  /// Segundos efetivamente decorridos (clamp em _total).
  int get _decorrido => (_total - _restante).clamp(0, _total);

  @override
  void initState() {
    super.initState();
    _total = widget.alvoSegundos.clamp(5, 3600);
    _restante = _total;
    unawaited(WakelockPlus.enable());
    unawaited(
      NotificationService.instance.scheduleTimerDone(
        _total,
        title: 'Tempo concluído',
        body: 'Fim da série — registre a execução.',
      ),
    );
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(WakelockPlus.disable());
    unawaited(NotificationService.instance.cancelTimerDone());
    unawaited(_player.dispose());
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_paused) return;
      if (_restante <= 0) {
        t.cancel();
        _onComplete();
        return;
      }
      setState(() => _restante--);
    });
  }

  Future<void> _onComplete() async {
    if (_fired) return;
    setState(() => _fired = true);
    final settings = ref.read(timerSettingsProvider);
    if (settings.vibracao) {
      try {
        final ok = await Vibration.hasVibrator();
        if (ok) await Vibration.vibrate(duration: 1000);
      } on Exception catch (e, st) {
        await Observability.captureError(e, st, hint: 'vibration');
      }
    }
    if (settings.bipe) {
      try {
        final assetKey = 'assets/sounds/${settings.som}.mp3';
        final data = await rootBundle.load(assetKey);
        if (data.lengthInBytes > 0) {
          await _player.play(AssetSource('sounds/${settings.som}.mp3'));
        }
      } catch (_) {
        // Asset ausente ou erro de playback — vibracao ja avisou.
      }
    }
    await Observability.track('timed_set_completed', {'duracao': _total});
  }

  void _adjust(int delta) {
    setState(() {
      _restante = (_restante + delta).clamp(0, 3600);
      _total = (_total + delta).clamp(5, 3600);
    });
    _reschedule();
  }

  /// Realinha a notificacao local com o tempo restante real. Cancela quando
  /// pausado; reagenda a partir de [_restante] quando rodando.
  void _reschedule() {
    unawaited(NotificationService.instance.cancelTimerDone());
    if (!_paused && !_fired) {
      unawaited(
        NotificationService.instance.scheduleTimerDone(
          _restante,
          title: 'Tempo concluído',
          body: 'Fim da série — registre a execução.',
        ),
      );
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _reschedule();
  }

  /// Conclui a serie retornando a duracao executada. Se estourou o alvo,
  /// registra o alvo cheio; senao, o tempo decorrido ate aqui.
  void _concluir() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop<int>(_fired ? _total : _decorrido);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mm = (_restante ~/ 60).toString().padLeft(2, '0');
    final ss = (_restante % 60).toString().padLeft(2, '0');
    final progress = _total == 0 ? 0.0 : (_total - _restante) / _total;
    final accent = _fired ? scheme.secondary : scheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Botao voltar tambem conclui a serie com o tempo decorrido.
        Navigator.of(context).pop<int>(_fired ? _total : _decorrido);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      color: accent,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    Text(
                      _fired ? 'TEMPO CONCLUÍDO' : 'EM EXECUÇÃO',
                      style: AppTheme.label(11, color: accent),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (widget.nomeExercicio != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.nomeExercicio!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                mm,
                                style:
                                    AppTheme.mono(
                                      160,
                                      weight: FontWeight.w800,
                                    ).copyWith(
                                      color: scheme.onSurface,
                                      height: 0.9,
                                    ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  ':',
                                  style: AppTheme.mono(
                                    110,
                                    weight: FontWeight.w300,
                                  ).copyWith(color: accent, height: 0.9),
                                ),
                              ),
                              Text(
                                ss,
                                style:
                                    AppTheme.mono(
                                      160,
                                      weight: FontWeight.w800,
                                    ).copyWith(
                                      color: scheme.onSurface,
                                      height: 0.9,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 6,
                          child: Stack(
                            children: [
                              Container(color: scheme.surfaceContainerHigh),
                              FractionallySizedBox(
                                widthFactor: progress.clamp(0, 1).toDouble(),
                                child: Container(color: accent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DECORRIDO',
                              style: AppTheme.label(
                                10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'ALVO ${_total ~/ 60}:${(_total % 60).toString().padLeft(2, '0')}',
                              style: AppTheme.label(
                                10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_fired)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjust(-15),
                          child: const Text('−15s'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _togglePause,
                          child: Text(_paused ? 'RETOMAR' : 'PAUSAR'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _adjust(15),
                          child: const Text('+15s'),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 72,
                  width: double.infinity,
                  child: FilledButton(
                    style: _fired
                        ? FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          )
                        : null,
                    onPressed: _concluir,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _fired ? 'CONCLUIR SÉRIE' : 'CONCLUIR AGORA',
                          style: AppTheme.label(15).copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.check, size: 20, color: scheme.onPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
