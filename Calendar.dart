import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _events.clear();
    });

    await _loadExamDates();
    await _loadStudySessions();

    setState(() {
      _focusedDay = _focusedDay;
    });
  }

  Future<void> _loadExamDates() async {
    final exams = await dbHelper.getAllExams();
    Map<DateTime, List<String>> examEvents = {};

    for (var exam in exams) {
      try {
        DateTime examDate = DateTime.parse(exam['start_date']);
        DateTime normalizedDate = DateTime(examDate.year, examDate.month, examDate.day);
        String examName = exam['name'] ?? 'Exam';

        examEvents.putIfAbsent(normalizedDate, () => []).add(examName);
      } catch (e) {
        print('Error parsing exam date: ${exam['start_date']}');
      }
    }

    setState(() {
      _events.addAll(examEvents);
    });
  }

  Future<void> _loadStudySessions() async {
    final sessions = await dbHelper.fetchStudySessions();
    Map<DateTime, List<String>> studyEvents = {};

    for (var session in sessions) {
      try {
        DateTime studyDate = DateTime.parse(session['start_date']);
        DateTime normalizedDate = DateTime(studyDate.year, studyDate.month, studyDate.day);
        String time = session['time'];
        String description = session['description'] ?? 'Study Session';

        studyEvents.putIfAbsent(normalizedDate, () => []).add('$description at $time');
      } catch (e) {
        print('Error parsing study session date: ${session['start_date']}');
      }
    }

    setState(() {
      _events.addAll(studyEvents);
    });
  }

  void _showStudySessionsPopup(DateTime selectedDate) {
    List<String> events = _getEventsForDay(selectedDate);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Events on ${selectedDate.toLocal().toString().split(' ')[0]}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: events.isNotEmpty
                ? events.map((event) => ListTile(title: Text(event))).toList()
                : [const Text("No events")],
          ),
          actions: [
            TextButton(
              child: const Text("Add Study Session"),
              onPressed: () {
                Navigator.pop(context);
                _showAddStudySessionDialog(selectedDate);
              },
            ),
            TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showAddStudySessionDialog(DateTime selectedDate) {
    TextEditingController descriptionController = TextEditingController();
    TextEditingController timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Study Session"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Date: ${selectedDate.toLocal().toString().split(' ')[0]}"),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: "Time (HH:mm)",
                  hintText: "e.g. 14:30",
                ),
                keyboardType: TextInputType.datetime,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "What will you study?",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Save"),
              onPressed: () async {
                if (timeController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  try {
                    List<String> timeParts = timeController.text.split(':');
                    if (timeParts.length != 2) {
                      throw FormatException("Invalid time format");
                    }

                    int hour = int.parse(timeParts[0]);
                    int minute = int.parse(timeParts[1]);

                    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                      throw FormatException("Invalid time values");
                    }

                    DateTime scheduledTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      hour,
                      minute,
                    );

                    await dbHelper.insertStudySession(
                      selectedDate.toIso8601String(),
                      selectedDate.toIso8601String(),
                      timeController.text,
                      descriptionController.text,
                    );

                    if (_notificationsEnabled) {
                      await _scheduleNotification(
                        "Study Session Reminder",
                        descriptionController.text,
                        scheduledTime,
                      );
                    }

                    await _loadEvents();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  } on FormatException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid time format: ${e.message}')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving study session: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
      },
    );

    // Check and request notification permissions
    _notificationsEnabled = await _requestNotificationPermissions();
    if (!_notificationsEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications are disabled')),
      );
    }
  }

  Future<bool> _requestNotificationPermissions() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      try {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      } catch (e) {
        print('Error requesting notification permissions: $e');
        return false;
      }
    }
    return true;
  }

  Future<void> _scheduleNotification(String title, String body, DateTime scheduledTime) async {
    if (!_notificationsEnabled) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'study_reminder_channel',
        'Study Reminders',
        channelDescription: 'Reminders for study sessions and exams',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      );

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        tzScheduledTime,
        const NotificationDetails(android: androidDetails),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set reminder: ${e.toString()}')),
        );
      }
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    final formattedDay = DateTime(day.year, day.month, day.day);
    return _events[formattedDay] ?? [];
  }

  void _addStudyReminder(DateTime day) async {
    if (!_notificationsEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications are disabled')));
      }
      return;
    }

    final reminderTime = day.subtract(const Duration(hours: 1));
    await _scheduleNotification(
      "Study Reminder",
      "Prepare for exams scheduled on ${day.toLocal().toString().split(' ')[0]}",
      reminderTime,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for ${day.toLocal().toString().split(' ')[0]}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _showStudySessionsPopup(selectedDay);
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8.0),
              ),
              formatButtonTextStyle: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (_selectedDay != null)
                  ..._getEventsForDay(_selectedDay!).map((event) => ListTile(
                    title: Text(event),
                    subtitle: Text('Date: ${_selectedDay!.toLocal().toString().split(' ')[0]}'),
                    trailing: event.contains('Exam')
                        ? IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () => _addStudyReminder(_selectedDay!),
                    )
                        : null,
                  )),
                if (_selectedDay == null || _getEventsForDay(_selectedDay!).isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No events for the selected day'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}