import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_secretary_flutter_final/PomodoroTimer.dart';
import 'package:study_secretary_flutter_final/ExamScheduleScreen.dart';
import 'package:study_secretary_flutter_final/Calendar.dart';
import 'package:study_secretary_flutter_final/Profile.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:study_secretary_flutter_final/SyllabusChecklist.dart';
import 'package:study_secretary_flutter_final/NotificationService.dart';
import 'Settings.dart';

class Home extends StatelessWidget {
  Home({super.key});
  final DatabaseHelper dbHelper = DatabaseHelper();
  Future<int?> get userId async => await dbHelper.getLoggedInUserId();

  Future<void> _showMotivation() async {
    final id = await userId;
    if (id != null) {
      await NotificationService().showMotivationalBanner(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMotivation();
    });
    return FutureBuilder(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          // Show loading while checking login status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Handle error case
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
          }

          // If not logged in, redirect to login
          if (snapshot.data == false) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // If logged in, show home screen
          return Scaffold(
            appBar: AppBar(
              title: const Text('Home'),
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.pink,
              ),
              child: Text(
                'Navigation Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Home(),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Profile'),
              onTap: () async {
                Navigator.pop(context); // Close drawer first
                try {
                  final userId = await dbHelper.getLoggedInUserId();
                  if (userId == null) {
                    _redirectToLogin(context);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Profile(userId: userId)),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Database error: ${e.toString()}')),
                  );
                  debugPrint('Profile access error: $e');
                  _redirectToLogin(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Settings()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        //Mainpage
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to the Study Secretary!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PomodoroTimer()),
                );
              },
              child: const Text('Study Now.'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Calendar()),
                );
              },
              child: const Text('Calendar'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExamScheduleScreen()),
                );
              },
              child: const Text('See your Exams'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final userId = await dbHelper.getLoggedInUserId();
                if (userId == null) {
                  _redirectToLogin(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SyllabusChecklist(userId: userId)),
                  );
                }
              },
              child: const Text('See your Study Progress'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    });
}
Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> _redirectToLogin(BuildContext context) async {
    Navigator.pushReplacementNamed(context, '/login');
  }

}
