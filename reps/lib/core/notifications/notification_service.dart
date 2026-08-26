import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servico de notificacoes locais — inicializa uma vez na subida do app.
///
/// Web retorna imediatamente sem erro (o plugin lida com kIsWeb internamente).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'reps_timer';
  static const _channelName = 'Timer de descanso';
  static const _timerNotifId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<void> requestPermissions() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// Agenda notificacao para daqui [seconds] segundos.
  /// Cancela qualquer notificacao de timer pendente antes de agendar.
  /// [title]/[body] permitem reaproveitar o canal para timers de execucao
  /// (o default descreve o fim do descanso).
  Future<void> scheduleTimerDone(
    int seconds, {
    String title = 'Hora de treinar!',
    String body = 'Descanso concluído — próxima série.',
  }) async {
    if (!_ready || kIsWeb) return;
    await cancelTimerDone();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
    );
    await _plugin.zonedSchedule(
      id: _timerNotifId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: seconds)),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancela notificacao pendente de timer (chama ao pular descanso ou fechar).
  Future<void> cancelTimerDone() async {
    if (!_ready || kIsWeb) return;
    await _plugin.cancel(id: _timerNotifId);
  }
}
