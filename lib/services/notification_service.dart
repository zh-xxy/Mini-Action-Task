import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'db_service.dart';
import 'task_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Request permission on Android 13+
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );
    tz.initializeTimeZones();
  }

  Future<void> testNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      '测试提醒',
      channelDescription: '用于测试通知功能是否正常',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      999,
      '测试通知',
      '这是一条测试通知，说明提醒功能已生效！',
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleEfficiencyReminders(List<int> topHours) async {
    // 先取消之前的
    await _notificationsPlugin.cancelAll();

    if (topHours.isEmpty) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'efficiency_reminders',
      '高效率提醒',
      channelDescription: '在您的高效率时段提醒您处理重要任务',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    int count = 0;
    for (var hour in topHours) {
      if (count >= 3) break; // 每天最多提醒3次

      await _notificationsPlugin.zonedSchedule(
        count,
        '高能量时段开启',
        '当前是您的高效率时段（${hour}时），适合处理有挑战性的任务！',
        _nextInstanceOfHour(hour),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      count++;
    }
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
