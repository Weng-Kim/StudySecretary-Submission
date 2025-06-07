import 'package:flutter/material.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatefulWidget {
  final int userId;

  const Profile({super.key, required this.userId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<List<Map<String, dynamic>>> _loadProfile() async {
    try {
      final data = await dbHelper.fetchProfile(widget.userId);
      debugPrint('Profile data loaded: ${data.toString()}');
      return data;
    } catch (e) {
      debugPrint('Error loading profile: $e');
      return [];
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserId');
      await prefs.remove('username');
      await prefs.setBool('isLoggedIn', false);

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
            (Route<dynamic> route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    }
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['username']?.toString() ?? 'No username',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'First Name', user['first_name']?.toString() ?? 'Unknown'),
            _buildInfoRow(Icons.school, 'Course', _getCourseName(user['course_id'])),
            _buildInfoRow(Icons.calendar_today, 'Exam Year', user['exam_year']?.toString() ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  String _getCourseName(dynamic courseId) {
    if (courseId == 1) return 'IB';
    if (courseId == 2) return 'A-Level';
    if (courseId == 3) return 'O-Level';
    if (courseId == 4) return 'Advanced Placement';
    return 'Unknown';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, IconData icon) {
    if (items.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '• ${item.toString()}',
                style: const TextStyle(fontSize: 16),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsSection(List<Map<String, dynamic>> subjects) {
    if (subjects.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...subjects.map((subject) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${subject['subject']?.toString() ?? 'Unknown subject'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Level: ${subject['level']?.toString() ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            // ... (keep your error handling code)
          }

          try {
            final profileData = snapshot.data!.first;
            final user = (profileData['user'] as Map<String, dynamic>?) ?? {};
            final subjects = (profileData['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final messages = (profileData['messages'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final goals = (profileData['goals'] as List?)?.map((e) => e.toString()).toList() ?? [];

            return RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildProfileHeader(user),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSubjectsSection(subjects),
                          _buildSection('Motivation Messages', messages, Icons.message),
                          _buildSection('Goals', goals, Icons.flag),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } catch (e) {
            debugPrint('Error building UI: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Error displaying profile data'),
                  Text('Details: $e'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}