import 'package:flutter/material.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:study_secretary_flutter_final/NotificationService.dart';

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({super.key});

    @override
  _PomodoroTimerState createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  int workDuration = 25; // Work duration in minutes
  int breakDuration = 5; // Break duration in minutes
  bool isWorking = true; // Track if it's work or break time
  bool isRunning = false; // Timer running state
  int remainingTime = 1500; // Time in seconds (25 minutes)

  late String timerText;

  @override
  void initState() {
    super.initState();
    updateTimerText();
    _loadTotalStudyTime();
  }

  void updateTimerText() {
    final minutes = (remainingTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingTime % 60).toString().padLeft(2, '0');
    timerText = '$minutes:$seconds';
  }

  void startTimer() {
    setState(() {
      isRunning = true;
    });
    Future.doWhile(() async {
      if (isRunning && remainingTime > 0) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          remainingTime--;
          updateTimerText();
        });
        return true;
      }
      if (remainingTime == 0) {
        toggleTimer();
      }
      return false;
    });
  }

  void stopTimer() {
    setState(() {
      isRunning = false;
    });
  }

  void resetTimer() {
    setState(() {
      remainingTime = isWorking ? workDuration * 60 : breakDuration * 60;
      updateTimerText();
      isRunning = false;
    });
  }

  void toggleTimer() async {
    setState(() {
      isWorking = !isWorking;
    });

    if (!isWorking) {
      await dbHelper.logStudyTime(workDuration * 60);
      await NotificationService().showStudySessionNotification(workDuration);
      _loadTotalStudyTime();

      // Insert into pomodoro_sessions (1 cycle)
      int? userId = await dbHelper.getUserId(); // You need to implement this method
      if (userId != null) {
        await dbHelper.logPomodoroSession(
          userId: userId,
          focusDuration: workDuration,
          breakDuration: breakDuration,
          totalCycles: 1,
        );
      }

      await NotificationService().showPomodoroNotification(true); // Time for a break!
      await NotificationService().showStudySessionNotification(workDuration);
    } else {
      await NotificationService().showPomodoroNotification(false); // Time for work!
    }

    resetTimer();
  }


  int totalStudyTime = 0;

  void _loadTotalStudyTime() async {
    totalStudyTime = await dbHelper.getTotalStudyTime(); // Use instance instead of static call
    setState(() {});
  }

  void showBreakNotification() {
    // Add a local notification here (e.g., with FlutterLocalNotificationsPlugin)
    print('Break time started!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isWorking ? 'Work Time' : 'Break Time',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              timerText,
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? null : startTimer,
                  child: const Text('Start'),
                ),
                ElevatedButton(
                  onPressed: isRunning ? stopTimer : null,
                  child: const Text('Stop'),
                ),
                ElevatedButton(
                  onPressed: resetTimer,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text('Break Duration:'),
            Slider(
              value: breakDuration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '$breakDuration minutes',
              onChanged: (value) {
                setState(() {
                  breakDuration = value.toInt();
                  if (!isWorking) resetTimer();
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Work Duration:',
              style: TextStyle(fontSize: 16),
            ),
            Slider(
              value: workDuration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: '$workDuration minutes',
              onChanged: (value) {
                setState(() {
                  workDuration = value.toInt();
                  if (isWorking) resetTimer();
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Total Study Time Today: ${totalStudyTime ~/ 60} min',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

          ],
        ),
      ),
    );
  }
}