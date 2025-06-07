import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_secretary_flutter_final/Home.dart';
import 'DatabaseHelper.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class UserDataForm extends StatelessWidget {
  const UserDataForm({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Collection Form',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const UserDataFormScreen(),
    );
  }
}

class UserDataFormScreen extends StatefulWidget {
  const UserDataFormScreen({super.key});

  @override
  _UserDataFormScreenState createState() => _UserDataFormScreenState();
}

class _UserDataFormScreenState extends State<UserDataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper(); // Initialize database helper

  // Text input controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();

  // State variables
  String? selectedCourse;
  int? selectedExamYear;
  List<String?> subjects = List.filled(8, null);
  List<String?> levels = List.filled(8, null);
  List<String?> motivationMessages = List.filled(3, null);
  List<String?> goals = List.filled(3, null);

  // Dropdown options
  final List<String> courseOptions = ['IB', 'A-Level', 'O-Level', 'AdvancedPlacement'];
  final List<int> examYearOptions = [2024, 2025, 2026, 2027];
  final List<String> subjectOptions = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'English Literature',
    'English Language and Literature',
    'Art',
    'Music',
  ];
  final List<String> levelOptions = ['HL', 'SL', 'H1', 'H2', 'H3', 'AP'];
  bool _isSaving = false;
  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      try {
        String username = _usernameController.text;
        String password = _passwordController.text;
        String firstName = _firstNameController.text;
        String course = selectedCourse!;
        int examYear = selectedExamYear!;
        List<String> nonNullSubjects = subjects.whereType<String>().toList();
        List<String> nonNullLevels = levels.whereType<String>().toList();
        List<String> nonNullMessages = motivationMessages.whereType<String>()
            .toList();
        List<String> nonNullGoals = goals.whereType<String>().toList();

        // Hash password using SHA-256
        String passwordHash = sha256.convert(utf8.encode(password)).toString();
        //String hashedPassword = sha256.convert(utf8.encode(plainPassword)).toString();

        await dbHelper.insertUser(
          username: username,
          passwordHash: passwordHash,
          // Store hashed password
          firstName: firstName,
          course: course,
          examYear: examYear,
          subjects: nonNullSubjects,
          levels: nonNullLevels,
          messages: nonNullMessages,
          goals: nonNullGoals,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', username);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Home()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving data: $e')),
          );
          setState(() => _isSaving = false);
        }else {
          setState(() => _isSaving = false);
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Data Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Username field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter username';
                    }
                    return null;
                  },
                ),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                ),
                // First name field
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                // Course dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Course'),
                  value: selectedCourse,
                  items: courseOptions.map((course) => DropdownMenuItem(value: course, child: Text(course))).toList(),
                  onChanged: (value) => setState(() {
                    selectedCourse = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a course';
                    }
                    return null;
                  },
                ),
                // Exam Year dropdown
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Exam Year'),
                  value: selectedExamYear,
                  items: examYearOptions.map((year) => DropdownMenuItem(value: year, child: Text(year.toString()))).toList(),
                  onChanged: (value) => setState(() {
                    selectedExamYear = value;
                  }),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select an exam year';
                    }
                    return null;
                  },
                ),
                // Subject and Level dropdowns
                for (int i = 0; i < 8; i++)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Subject ${i + 1}'),
                          items: subjectOptions.map((subject) => DropdownMenuItem(value: subject, child: Text(subject))).toList(),
                          onChanged: (value) => setState(() {
                            subjects[i] = value;
                          }),
                          validator: (value) {
                            if (i < 4 && (value == null || value.isEmpty)) {
                              return 'This field is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Level ${i + 1}'),
                          items: levelOptions.map((level) => DropdownMenuItem(value: level, child: Text(level))).toList(),
                          onChanged: (value) => setState(() {
                            levels[i] = value;
                          }),
                          validator: (value) {
                            if (i < 4 && (value == null || value.isEmpty)) {
                              return 'This field is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                // Motivation messages
                for (int i = 0; i < 3; i++)
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Motivation Message ${i + 1}'),
                    onChanged: (value) => motivationMessages[i] = value,
                  ),
                // Goals
                for (int i = 0; i < 3; i++)
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Goal ${i + 1}'),
                    onChanged: (value) => goals[i] = value,
                  ),
                // Submit button
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    setState(() => _isSaving = true);
                    await _saveUserData();
                    if (mounted) setState(() => _isSaving = false);
                  },
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Submit and login'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}