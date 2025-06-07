import 'package:flutter/material.dart';
import 'package:study_secretary_flutter_final/DatabaseHelper.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class SyllabusChecklist extends StatefulWidget {
  final int userId;

  const SyllabusChecklist({super.key, required this.userId});

  @override
  _SyllabusChecklistState createState() => _SyllabusChecklistState();
}

class _SyllabusChecklistState extends State<SyllabusChecklist> {
  List<Map<String, dynamic>> _syllabus = [];
  final DatabaseHelper dbHelper = DatabaseHelper();
  double _completionPercentage = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for the add item dialog
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSyllabus();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _chapterController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _loadSyllabus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final syllabusData = await dbHelper.fetchUserSyllabus(widget.userId);
      if (syllabusData.isEmpty) {
        setState(() {
          _errorMessage = 'No syllabus data found for your course.';
        });
      } else {
        setState(() {
          _syllabus = syllabusData;
          _calculateCompletionPercentage();
        });
      }
    } catch (e) {
      debugPrint('Error loading syllabus: $e');
      setState(() {
        _errorMessage = 'Failed to load syllabus data. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateCompletionPercentage() {
    if (_syllabus.isEmpty) {
      setState(() {
        _completionPercentage = 0.0;
      });
      return;
    }

    final completedCount = _syllabus.where((item) => item['is_completed'] == 1).length;
    setState(() {
      _completionPercentage = (completedCount / _syllabus.length) * 100;
    });
  }

  Future<void> _toggleCompletion(int progressId, bool isCompleted) async {
    try {
      await dbHelper.updateSyllabusCompletion(progressId, isCompleted);
      await _loadSyllabus(); // Refresh the data
    } catch (e) {
      debugPrint('Error toggling completion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNewItem() async {
    final subject = _subjectController.text.trim();
    final chapter = _chapterController.text.trim();
    final level = _levelController.text.trim().toUpperCase();

    if (subject.isEmpty || chapter.isEmpty || level.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (level != 'SL' && level != 'HL') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Level must be either SL or HL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // First, check if the syllabus item exists in the syllabus table
      final db = await dbHelper.database;
      final syllabusItem = await db.query(
        'syllabus',
        where: 'subject = ? AND chapter = ? AND level = ?',
        whereArgs: [subject, chapter, level],
      );

      int syllabusId;
      if (syllabusItem.isEmpty) {
        // If it doesn't exist, insert it
        syllabusId = await db.insert('syllabus', {
          'subject': subject,
          'chapter': chapter,
          'level': level,
          'course_id': '1', // Assuming course_id 1 is IB (from your DB setup)
        });
      } else {
        syllabusId = syllabusItem.first['syllabus_id'] as int;
      }

      // Then add to user's progress
      await db.insert('user_syllabus_progress', {
        'user_id': widget.userId,
        'syllabus_id': syllabusId,
        'is_completed': 0,
      });

      // Clear the form
      _subjectController.clear();
      _chapterController.clear();
      _levelController.clear();

      // Refresh the list
      await _loadSyllabus();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      debugPrint('Error adding new item: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add item: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddItemDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Syllabus Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g. Mathematics',
                  ),
                ),
                TextField(
                  controller: _chapterController,
                  decoration: const InputDecoration(
                    labelText: 'Chapter/Topic',
                    hintText: 'e.g. Algebra',
                  ),
                ),
                TextField(
                  controller: _levelController,
                  decoration: const InputDecoration(
                    labelText: 'Level (SL or HL)',
                    hintText: 'e.g. HL',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: _addNewItem,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const Text(
                'Completion Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SfCircularChart(
                  series: <CircularSeries>[
                    PieSeries<Map<String, dynamic>, String>(
                      dataSource: [
                        {'category': 'Completed', 'value': _completionPercentage},
                        {'category': 'Remaining', 'value': 100 - _completionPercentage},
                      ],
                      xValueMapper: (data, _) => data['category'],
                      yValueMapper: (data, _) => data['value'],
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.inside,
                        textStyle: TextStyle(color: Colors.white),
                      ),
                      pointColorMapper: (data, _) =>
                      data['category'] == 'Completed'
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ],
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                ),
              ),
              Text(
                '${_completionPercentage.toStringAsFixed(1)}% Complete',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _syllabus.length,
      itemBuilder: (context, index) {
        final item = _syllabus[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: CheckboxListTile(
            title: Text(
              "${item['subject']} - ${item['chapter']}",
              style: TextStyle(
                decoration: item['is_completed'] == 1
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: item['level'] != null
                ? Text("Level: ${item['level']}")
                : null,
            value: item['is_completed'] == 1,
            onChanged: (bool? value) {
              if (value != null) {
                _toggleCompletion(item['progress_id'], value);
              }
            },
            secondary: item['is_completed'] == 1
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Syllabus Checklist"),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSyllabus,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressChart(),
          Expanded(
            child: _buildSubjectList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}