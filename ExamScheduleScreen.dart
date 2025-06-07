import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:study_secretary_flutter_final/NotificationService.dart';
import 'AddYourExams.dart';

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  _ExamScheduleScreenState createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final int userId = 1; // Replace with actual user ID
  List<Map<String, dynamic>> exams = [];

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _loadExams();
  }

  Future<void> _loadExams() async {
    final loadedExams = await fetchExamSchedule();
    setState(() {
      exams = loadedExams;
    });
  }

  Future<void> _setupNotifications() async {
    await NotificationService().showMotivationalBanner(userId);
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('MMM d, y').format(date);
  }

  Future<void> _deleteExam(int id) async {
    try {
      await dbHelper.deleteExam(id);
      await _loadExams(); // Refresh the list after deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting exam: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Schedule'),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: scheduleExamReminders,
            tooltip: 'Schedule Reminders',
          ),
        ],
      ),
      body: exams.isEmpty
          ? const Center(
        child: Text('No exams found. Add your first exam!'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exams.length,
        itemBuilder: (context, index) {
          final exam = exams[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(exam['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_formatDate(exam['start_date'])} - ${_formatDate(exam['end_date'])}'),
                  if (exam['description'] != null)
                    Text(exam['description']!,
                        style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              trailing: PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Exam'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Exam'),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddYourExams(existingExam: exam),
                      ),
                    ).then((_) => _loadExams()); // Refresh after editing
                  } else if (value == 'delete') {
                    await _deleteExam(exam['id']);
                  }
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddYourExams()),
        ).then((_) => _loadExams()), // Refresh after adding new exam
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchExamSchedule() async {
    return await dbHelper.getAllExams();
  }

  Future<void> scheduleExamReminders() async {
    final exams = await fetchExamSchedule();
    for (var exam in exams) {
      final examName = exam['name'];
      final examDateStr = exam['start_date'];
      final examDate = DateTime.tryParse(examDateStr);

      if (examDate != null) {
        await NotificationService().scheduleExamReminder(examName, examDate);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminders scheduled successfully')),
    );
  }
}