import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:math';

extension DatabaseExceptionExtensions on DatabaseException {
  bool isUniqueConstraintError() {
    return toString().contains('UNIQUE constraint failed') ||
        toString().contains('SQLITE_CONSTRAINT_UNIQUE');
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'user_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        first_name TEXT NOT NULL,
        course_id INTEGER NOT NULL,
        exam_year INTEGER NOT NULL,
        logged_in INTEGER DEFAULT 0,
        FOREIGN KEY (course_id) REFERENCES courses(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_subjects(
        user_id INTEGER NOT NULL,
        subject TEXT NOT NULL,
        level TEXT NOT NULL CHECK(level IN ('SL', 'HL')),
        PRIMARY KEY (user_id, subject),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        goal TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE exams(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('predefined', 'custom')),
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        description TEXT,
        CHECK(start_date <= end_date)
      )
    ''');

    await db.execute(''' 
      CREATE TABLE studysesh(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        time TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        focus_duration INTEGER NOT NULL,
        break_duration INTEGER NOT NULL,
        total_cycles INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
    ''');

    await db.execute('''
      CREATE TABLE syllabus (
        syllabus_id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        course_id TEXT NOT NULL,
        level TEXT NOT NULL,
        chapter TEXT NOT NULL,
        FOREIGN KEY(course_id) REFERENCES courses(id),
        UNIQUE(subject, course_id, level, chapter)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_syllabus_progress (
        progress_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        syllabus_id INTEGER NOT NULL,
        is_completed BOOLEAN DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (syllabus_id) REFERENCES syllabus(syllabus_id) ON DELETE CASCADE,
        UNIQUE(user_id, syllabus_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_time (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_time INTEGER NOT NULL
      )
    ''');

    await db.execute('''
    INSERT OR IGNORE INTO courses (name) VALUES 
      ('IB'),
      ('A-Level'),
      ('O-Level'),
      ('AdvancedPlacement')
    ''');

    // Inside _onCreate(), after table creation:
// Add sample syllabus data
    await db.execute('''
  INSERT OR IGNORE INTO syllabus (subject, course_id, level, chapter) VALUES 
    ('Mathematics', '1', 'HL', 'Algebra'),
    ('Mathematics', '1', 'HL', 'Calculus'),
    ('Physics', '1', 'SL', 'Mechanics')
''');

// Add sample progress for default user (id=1)
    await db.execute('''
  INSERT OR IGNORE INTO user_syllabus_progress (user_id, syllabus_id, is_completed) VALUES 
    (1, 1, 0),
    (1, 2, 1),
    (1, 3, 0)
''');

    // Insert default course if none exists
    final courseQuery = await db.query('courses', where: 'name = ?', whereArgs: ['Default Course']);
    if (courseQuery.isEmpty) {
    } else {
    }

    // Insert default user if none exists
    final userQuery = await db.query('users', where: 'username = ?', whereArgs: ['default']);
    if (userQuery.isEmpty) {
      await db.insert('users', {
        'username': 'default',
        'password_hash': 'default',
        'first_name': 'Default',
        'course_id': 1,
        'exam_year': 2025,
        'logged_in': 1
      });
    }
    final examQuery = await db.query('exams');
    if (examQuery.isEmpty) {
      await db.insert('exams', {
        'name': 'IB May Session 2024',
        'type': 'predefined',
        'start_date': '2024-04-25',
        'end_date': '2024-05-17',
        'description': null
      });

      await db.insert('exams', {
        'name': 'IB November Session 2024',
        'type': 'predefined',
        'start_date': '2024-10-21',
        'end_date': '2024-11-11',
        'description': null
      });

      await db.insert('exams', {
        'name': 'A-Levels 2024',
        'type': 'predefined',
        'start_date': '2024-07-03',
        'end_date': '2024-11-07',
        'description': 'Oral is in July, Written papers start in October'
      });

      await db.insert('exams', {
        'name': 'O-Levels 2024',
        'type': 'predefined',
        'start_date': '2024-07-03',
        'end_date': '2024-11-11',
        'description': 'Oral and Mother Tongue Listening is in July, Written papers start in October'
      });

    }

  }
// Add your CRUD methods here...



  Future<int> insertUser({
    required String username,
    required String passwordHash,
    required String firstName,
    required String course,
    required int examYear,
    required List<String> subjects,
    required List<String> levels,
    required List<String> messages,
    required List<String> goals,
  }) async {
    final db = await database;

    // Validate input lengths match
    if (subjects.length != levels.length) {
      throw ArgumentError('Subjects and levels lists must be the same length');
    }

    return await db.transaction((txn) async {
      try {
        // Get or create course
        int courseId;
        final courseQuery = await txn.query(
          'courses',
          where: 'name = ?',
          whereArgs: [course],
        );

        if (courseQuery.isEmpty) {
          courseId = await txn.insert(
            'courses',
            {'name': course},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          // If the course already existed but we used IGNORE, query again
          if (courseId == 0) {
            final existingCourse = await txn.query(
              'courses',
              where: 'name = ?',
              whereArgs: [course],
            );
            courseId = existingCourse.first['id'] as int;
          }
        } else {
          courseId = courseQuery.first['id'] as int;
        }

        // Insert user with error handling for duplicate username
        final userId = await txn.insert(
          'users',
          {
            'username': username,
            'password_hash': passwordHash,
            'first_name': firstName,
            'course_id': courseId,
            'exam_year': examYear,
            'logged_in': 1, // Automatically log in the new user
          },
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        // Insert subjects
        for (int i = 0; i < subjects.length; i++) {
          await txn.insert(
            'user_subjects',
            {
              'user_id': userId,
              'subject': subjects[i],
              'level': levels[i],
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        // Insert messages
        for (final message in messages) {
          await txn.insert(
            'user_messages',
            {
              'user_id': userId,
              'message': message,
            },
          );
        }

        // Insert goals
        for (final goal in goals) {
          await txn.insert(
            'user_goals',
            {
              'user_id': userId,
              'goal': goal,
            },
          );
        }

        // Initialize syllabus progress for this user
        final syllabusItems = await txn.query(
          'syllabus',
          where: 'course_id = ?',
          whereArgs: [courseId.toString()],
        );

        for (final item in syllabusItems) {
          await txn.insert(
            'user_syllabus_progress',
            {
              'user_id': userId,
              'syllabus_id': item['syllabus_id'],
              'is_completed': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        return userId;
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError()) {
          throw Exception('Username already exists');
        } else {
          rethrow;
        }
      }
    });
  }

  Future<bool> authenticateUser(String username, String passwordHash) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );
    return result.isNotEmpty;
  }

  Future<int> updateUserLoginStatus(int userId, bool isLoggedIn) async {
    final db = await database;
    return await db.update(
      'users',
      {'logged_in': isLoggedIn ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }


  Future<List<Map<String, dynamic>>> getAllExams() async {
    final db = await database;
    return await db.query('exams', orderBy: 'start_date ASC');
  }

// Get exams filtered by type ('predefined' or 'custom')
  Future<List<Map<String, dynamic>>> getExamsByType(String type) async {
    final db = await database;
    return await db.query(
      'exams',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'start_date ASC',
    );
  }

// Add or update an exam (works for both types)
  Future<int> saveExam({
    int? id,
    required String name,
    required String type,
    required String startDate,
    required String endDate,
    String? description,
  }) async {
    final db = await database;

    if (id == null) {
      return await db.insert('exams', {
        'name': name,
        'type': type,
        'start_date': startDate,
        'end_date': endDate,
        'description': description,
      });
    } else {
      return await db.update(
        'exams',
        {
          'name': name,
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'description': description,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

// Delete an exam (works for both types)
  Future<int> deleteExam(int id) async {
    final db = await database;
    return await db.delete(
      'exams',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// Get upcoming exams (both types)
  Future<List<Map<String, dynamic>>> getUpcomingExams() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'exams',
      where: 'end_date >= ?',
      whereArgs: [now],
      orderBy: 'start_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> fetchProfile(int userId) async {
    final db = await database;

    // Fetch user details
    final userData = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userData.isEmpty) return [];

    // Fetch subjects and levels
    final subjects = await db.query('user_subjects', where: 'user_id = ?', whereArgs: [userId]);

    // Fetch messages and explicitly convert to String
    final messages = await db.query('user_messages', where: 'user_id = ?', whereArgs: [userId]);
    final messageList = messages.map((m) => m['message'].toString()).toList();

    // Fetch goals and explicitly convert to String
    final goals = await db.query('user_goals', where: 'user_id = ?', whereArgs: [userId]);
    final goalList = goals.map((g) => g['goal'].toString()).toList();

    return [
      {
        'user': userData.first,
        'subjects': subjects,
        'messages': messageList,
        'goals': goalList,
      }
    ];
  }

  Future<Map<String, String?>> fetchRandomMessageAndGoal(userID) async {
    final db = await database;
    int? userId = userID;
    final messages = await db.query('user_messages', where: 'user_id = ?', whereArgs: [userId]);
    final goals = await db.query('user_goals', where: 'user_id = ?', whereArgs: [userId]);

    if (messages.isEmpty || goals.isEmpty) return {'message': null, 'goal': null};

    return {
      'message': messages[Random().nextInt(messages.length)]['message'] as String?,
      'goal': goals[Random().nextInt(goals.length)]['goal'] as String?,
    };
  }

  Future<int?> getLoggedInUserId() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      columns: ['id'], // Change 'user_id' to your actual column name
      where: 'logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first['id'] : null;
  }


  /*
  Future<void> insertCustomExam({
    required String name,
    required String startDate,
    required String endDate,
    String? description,
  }) async {
    final db = await database;
    await db.insert('exams', {
      'name': name,
      'type': 'custom',
      'start_date': startDate,
      'end_date': endDate,
      'description': description ?? '',
    });
  }
  */

  Future<void> insertStudySession(String startDate, String endDate, String time, String description) async {
    final db = await database;
    await db.insert('studysesh', {
      'start_date': startDate,
      'end_date': endDate,
      'time': time,
      'description': description,
    });
  }


  Future<List<Map<String, dynamic>>> fetchStudySessions() async {
    final db = await database;
    return await db.query('studysesh');
  }

  Future<int> updateStudySession(int id, String startDate, String endDate, String time, String description) async {
    final db = await database;
    return await db.update(
      'studysesh',
      {
        'start_date': startDate,
        'end_date': endDate,
        'time': time,
        'description': description,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> logStudyTime(int durationInSeconds) async {
    final db = await database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    final result = await db.query(
      'study_time',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (result.isEmpty) {
      await db.insert('study_time', {'date': today, 'total_time': durationInSeconds});
    } else {
      int currentTotal = result.first['total_time'] as int;
      await db.update(
        'study_time',
        {'total_time': currentTotal + durationInSeconds},
        where: 'date = ?',
        whereArgs: [today],
      );
    }
  }

  Future<int> getTotalStudyTime() async {
    final db = await database;
    String today = DateTime.now().toIso8601String().split('T')[0];

    final result = await db.query(
      'study_time',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (result.isEmpty) return 0;
    return result.first['total_time'] as int;
  }

  Future<void> logPomodoroSession({
    required int userId,
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
  })
  async {
    final db = await database;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.insert('pomodoro_sessions', {
      'user_id': userId,
      'date': dateStr,
      'focus_duration': focusDuration,
      'break_duration': breakDuration,
      'total_cycles': totalCycles,
    });
  }

  Future<int?> getUserId() async {
    final db = await database;
    final result = await db.query('users', limit: 1);
    if (result.isNotEmpty) {
      return result.first['id'] as int?;
    }
    return null;
  }

// In DatabaseHelper.dart
  Future<List<Map<String, dynamic>>> fetchUserSyllabus(int userId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT 
      usp.progress_id, 
      usp.is_completed,
      s.subject, 
      s.chapter,
      s.level
    FROM user_syllabus_progress usp
    JOIN syllabus s ON usp.syllabus_id = s.syllabus_id
    WHERE usp.user_id = ?
  ''', [userId]);
  }

  Future<int> updateSyllabusCompletion(int progressId, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'user_syllabus_progress',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'progress_id = ?',
      whereArgs: [progressId],
    );
  }

  /*Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId'); // Clear user session
    await prefs.clear(); // Optional: clear all preferences
    // Navigate to login screen
  }*/


}
