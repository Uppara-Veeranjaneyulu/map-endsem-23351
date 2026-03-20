import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'main.dart'; // To get the Plant class

class AppNotifications {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _plugin.initialize(initializationSettings);

    _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleWatering(Plant plant) async {
    await _plugin.cancel(plant.id.hashCode);
    final DateTime lastW = plant.lastWateredDate ?? DateTime.now();
    final DateTime nextW = lastW.add(Duration(days: plant.wateringFrequencyDays));
    if (nextW.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        plant.id.hashCode,
        'Watering Reminder',
        'It is time to water your ${plant.name}!',
        tz.TZDateTime.from(nextW, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'plant_care',
            'Plant Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancel(String id) async {
    await _plugin.cancel(id.hashCode);
  }
}
