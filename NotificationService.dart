import 'package:flutter/foundation.dart'; // Add this import
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _timeZonesInitialized = false;

  NotificationService._internal();

  Future<void> initNotifications() async {
    if (!_timeZonesInitialized) {
      tz.initializeTimeZones();
      _timeZonesInitialized = true;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap if needed
      },
    );
  }

  Future<bool> _areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificationsEnabled') ?? true;
  }

  Future<bool> _areDailyRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dailyRemindersEnabled') ?? true;
  }

  Future<bool> _areExamRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('examRemindersEnabled') ?? true;
  }

  Future<void> showMotivationalBanner(int userId) async {
    if (!await _areNotificationsEnabled() || !await _areDailyRemindersEnabled()) {
      return;
    }

    try {
      List<String> messages = [];
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, String?> messageMap = await dbHelper.fetchRandomMessageAndGoal(userId);

      String? message = messageMap['message'];
      if (message != null && message.isNotEmpty) {
        messages.add(message);
      }

      if (messages.isEmpty) {
        messages = _getDefaultMotivationalMessages();
      }

      await _showNotification(
        id: NotificationIds.motivational,
        title: "Study Motivation 💡",
        body: messages[Random().nextInt(messages.length)],
        channel: NotificationChannels.motivational,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing motivational banner: $e');
      }
      await _showFallbackMotivationalMessage();
    }
  }

  List<String> _getDefaultMotivationalMessages() {
    return [
      "Keep pushing forward! 💪",
      "Success is built one session at a time. ⏳",
      "Stay focused! You got this! 🚀",
      "Believe in yourself and stay consistent. 🌟"
    ];
  }

  Future<void> _showFallbackMotivationalMessage() async {
    if (!await _areNotificationsEnabled()) return;

    await _showNotification(
      id: NotificationIds.motivational,
      title: "Study Motivation 💡",
      body: _getDefaultMotivationalMessages()[0],
      channel: NotificationChannels.motivational,
    );
  }

  Future<void> showPomodoroNotification(bool isBreak) async {
    if (!await _areNotificationsEnabled()) return;

    await _showNotification(
      id: NotificationIds.pomodoro,
      title: isBreak ? "Break Time! ☕" : "Focus Time! 📚",
      body: isBreak ? "Take a short break and recharge!" : "Time to focus and get things done!",
      channel: NotificationChannels.pomodoro,
    );
  }

  Future<void> showStudySessionNotification(int minutes) async {
    if (!await _areNotificationsEnabled()) return;

    await _showNotification(
      id: NotificationIds.studySession,
      title: "Study Session Complete! ✅",
      body: "You studied for $minutes minutes! Great job! 🎉",
      channel: NotificationChannels.studySession,
    );
  }

  Future<void> scheduleExamReminder(String examName, DateTime examDate) async {
    if (!await _areNotificationsEnabled() || !await _areExamRemindersEnabled()) {
      return;
    }

    try {
      final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
          examDate.subtract(const Duration(days: 1)),
          tz.local
      );

      await _notificationsPlugin.zonedSchedule(
        NotificationIds.examReminder,
        "Upcoming Exam Reminder!",
        "Don't forget! Your exam '$examName' is tomorrow.",
        scheduledTime,
        _getNotificationDetails(NotificationChannels.examReminder),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling exam reminder: $e');
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> cancelMotivationalNotifications() async {
    await _notificationsPlugin.cancel(NotificationIds.motivational);
  }

  Future<void> cancelExamReminders() async {
    await _notificationsPlugin.cancel(NotificationIds.examReminder);
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channel,
  }) async {
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _getNotificationDetails(channel),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing notification: $e');
      }
    }
  }

  NotificationDetails _getNotificationDetails(String channelId) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: 'Channel for ${_getChannelName(channelId)}',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case NotificationChannels.motivational:
        return 'Motivational Banners';
      case NotificationChannels.pomodoro:
        return 'Pomodoro Timings';
      case NotificationChannels.studySession:
        return 'Study Sessions';
      case NotificationChannels.examReminder:
        return 'Exam Reminders';
      default:
        return 'General Notifications';
    }
  }
}

class NotificationChannels {
  static const String motivational = 'motivational_channel';
  static const String pomodoro = 'pomodoro_channel';
  static const String studySession = 'study_session_channel';
  static const String examReminder = 'exam_reminder_channel';
}

class NotificationIds {
  static const int motivational = 0;
  static const int pomodoro = 1;
  static const int studySession = 2;
  static const int examReminder = 3;
}