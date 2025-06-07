import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:study_secretary_flutter_final/NotificationService.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _notificationsEnabled = true;
  bool _dailyRemindersEnabled = true;
  bool _examRemindersEnabled = true;
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initNotifications();
    _loadNotificationSettings();
  }

  Future<void> _initNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      await notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
        },
      );
      await _notificationService.initNotifications();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _dailyRemindersEnabled = prefs.getBool('dailyRemindersEnabled') ?? true;
      _examRemindersEnabled = prefs.getBool('examRemindersEnabled') ?? true;

      final timeString = prefs.getString('dailyReminderTime') ?? '20:00';
      final parts = timeString.split(':');
      _dailyReminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    });

    if (_dailyRemindersEnabled && _notificationsEnabled) {
      _scheduleDailyReminder();
    }
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('dailyRemindersEnabled', _dailyRemindersEnabled);
    await prefs.setBool('examRemindersEnabled', _examRemindersEnabled);
    await prefs.setString(
      'dailyReminderTime',
      '${_dailyReminderTime.hour}:${_dailyReminderTime.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _scheduleDailyReminder() async {
    await _cancelDailyReminder();

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Channel for daily study reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _dailyReminderTime.hour,
      _dailyReminderTime.minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await notificationsPlugin.zonedSchedule(
      1, // Daily reminder ID
      'Time to Study!',
      'Your daily study session is waiting!',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelDailyReminder() async {
    await notificationsPlugin.cancel(1);
    await _notificationService.cancelMotivationalNotifications();
  }

  Future<void> _cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
    await _notificationService.cancelAllNotifications();
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() {
      _notificationsEnabled = enabled;
      if (!enabled) {
        _dailyRemindersEnabled = false;
        _examRemindersEnabled = false;
      }
    });

    await _saveNotificationSettings();

    if (!enabled) {
      await _cancelAllNotifications();
    } else {
      if (_dailyRemindersEnabled) {
        await _scheduleDailyReminder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Notifications'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Daily Study Reminders'),
              value: _dailyRemindersEnabled && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) async {
                setState(() {
                  _dailyRemindersEnabled = value;
                });
                await _saveNotificationSettings();
                if (value) {
                  await _scheduleDailyReminder();
                } else {
                  await _cancelDailyReminder();
                }
              }
                  : null,
            ),
            ListTile(
              title: const Text('Daily Reminder Time'),
              subtitle: Text(_dailyReminderTime.format(context)),
              onTap: _notificationsEnabled && _dailyRemindersEnabled
                  ? () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _dailyReminderTime,
                );
                if (time != null) {
                  setState(() {
                    _dailyReminderTime = time;
                  });
                  await _saveNotificationSettings();
                  await _scheduleDailyReminder();
                }
              }
                  : null,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Exam Reminders'),
              value: _examRemindersEnabled && _notificationsEnabled,
              onChanged: _notificationsEnabled
                  ? (value) async {
                setState(() {
                  _examRemindersEnabled = value;
                });
                await _saveNotificationSettings();
                if (!value) {
                  await _notificationService.cancelExamReminders();
                }
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveNotificationSettings();
    super.dispose();
  }
}