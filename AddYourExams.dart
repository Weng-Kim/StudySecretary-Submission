import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_secretary_flutter_final/ExamScheduleScreen.dart';
import 'DatabaseHelper.dart';

class AddYourExams extends StatefulWidget {
  final Map<String, dynamic>? existingExam;

  const AddYourExams({super.key, this.existingExam});

  @override
  _AddYourExamsState createState() => _AddYourExamsState();
}

class _AddYourExamsState extends State<AddYourExams> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();

  final TextEditingController _examNameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _examDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Pre-fill fields if editing existing exam
    if (widget.existingExam != null) {
      _examNameController.text = widget.existingExam!['name'];
      _startDateController.text = _formatDate(widget.existingExam!['start_date']);
      _endDateController.text = _formatDate(widget.existingExam!['end_date']);
      _examDescriptionController.text = widget.existingExam!['description'] ?? '';
    }
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _saveExamData() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Parse dates from dd/MM/yyyy format to ISO format
        final startDate = _parseDate(_startDateController.text);
        final endDate = _parseDate(_endDateController.text);

        if (endDate.isBefore(startDate)) {
          throw Exception('End date must be after start date');
        }

        if (widget.existingExam == null) {
          // Add new exam
          await dbHelper.saveExam(
            name: _examNameController.text,
            type: 'custom',
            startDate: startDate.toIso8601String(),
            endDate: endDate.toIso8601String(),
            description: _examDescriptionController.text.isNotEmpty
                ? _examDescriptionController.text
                : null,
          );
        } else {
          // Update existing exam
          await dbHelper.saveExam(
            id: widget.existingExam!['id'],
            name: _examNameController.text,
            type: 'custom',
            startDate: startDate.toIso8601String(),
            endDate: endDate.toIso8601String(),
            description: _examDescriptionController.text.isNotEmpty
                ? _examDescriptionController.text
                : null,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existingExam == null
              ? 'Exam added successfully!'
              : 'Exam updated successfully!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ExamScheduleScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  DateTime _parseDate(String dateString) {
    final parts = dateString.split('/');
    return DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _examDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingExam == null ? 'Add New Exam' : 'Edit Exam'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _examNameController,
                  decoration: const InputDecoration(
                    labelText: 'Exam Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the exam name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Start Date Field with Date Picker
                TextFormField(
                  controller: _startDateController,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context, _startDateController),
                    ),
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a start date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // End Date Field with Date Picker
                TextFormField(
                  controller: _endDateController,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context, _endDateController),
                    ),
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an end date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _examDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveExamData,
                    child: Text(
                      widget.existingExam == null
                          ? 'Save Exam'
                          : 'Update Exam',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}