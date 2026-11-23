import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/book.dart';

/// Local-first SQLite store. Schema v1 covers books, local docs, notes,
/// highlights, bookmarks, sessions, review cards and summaries so later
/// reader/review batches extend without breaking migrations.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'kun_muthaqqafan.db');
    return openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE highlights ADD COLUMN rect TEXT');
        }
      },
      onCreate: (db, v) async {
        await db.execute('''
CREATE TABLE books(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL, subtitle TEXT, author TEXT NOT NULL,
  description TEXT, status TEXT NOT NULL, favourite INTEGER NOT NULL DEFAULT 0,
  rating INTEGER, pages INTEGER, current_page INTEGER NOT NULL DEFAULT 0,
  publisher TEXT, publication_year INTEGER, isbn TEXT, olid TEXT,
  cover_url TEXT, tags TEXT, my_review TEXT, language TEXT, genre TEXT,
  date_added TEXT NOT NULL, date_modified TEXT NOT NULL,
  start_date TEXT, finish_date TEXT)''');
        await db.execute('''
CREATE TABLE local_docs(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL, file_path TEXT NOT NULL UNIQUE, format TEXT NOT NULL,
  file_size INTEGER NOT NULL DEFAULT 0, date_modified TEXT NOT NULL,
  date_added TEXT NOT NULL, last_opened TEXT, last_page INTEGER NOT NULL DEFAULT 0,
  progress REAL NOT NULL DEFAULT 0, favourite INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('''
CREATE TABLE notes(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER, doc_id INTEGER, title TEXT, content TEXT NOT NULL,
  page INTEGER, chapter TEXT, highlighted_text TEXT, tags TEXT,
  favourite INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, modified_at TEXT NOT NULL)''');
        await db.execute('''
CREATE TABLE highlights(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER, doc_id INTEGER, text TEXT NOT NULL, color TEXT NOT NULL DEFAULT 'yellow',
  page INTEGER, chapter TEXT, note TEXT, tags TEXT, rect TEXT, created_at TEXT NOT NULL)''');
        await db.execute('''
CREATE TABLE bookmarks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_id INTEGER NOT NULL, page INTEGER NOT NULL, label TEXT, created_at TEXT NOT NULL)''');
        await db.execute('''
CREATE TABLE sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER, doc_id INTEGER, started_at TEXT NOT NULL, ended_at TEXT,
  minutes INTEGER NOT NULL DEFAULT 0, pages_read INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('''
CREATE TABLE review_cards(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  front TEXT NOT NULL, back TEXT NOT NULL, book_id INTEGER, doc_id INTEGER,
  ease REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0,
  repetitions INTEGER NOT NULL DEFAULT 0, due_date TEXT NOT NULL,
  created_at TEXT NOT NULL)''');
        await db.execute('''
CREATE TABLE summaries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER, doc_id INTEGER, style TEXT NOT NULL, content TEXT NOT NULL,
  created_at TEXT NOT NULL, modified_at TEXT NOT NULL)''');
      },
    );
  }

  Future<int> insertBook(Book b) async =>
      (await db).insert('books', b.toMap()..remove('id'));

  Future<void> updateBook(Book b) async => (await db)
      .update('books', b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> deleteBook(int id) async =>
      (await db).delete('books', where: 'id = ?', whereArgs: [id]);

  Future<List<Book>> books({String? status, String? query}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (query != null && query.isNotEmpty) {
      where.add('(title LIKE ? OR author LIKE ? OR tags LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    final rows = await d.query(
      'books',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_modified DESC',
    );
    return rows.map(Book.fromMap).toList();
  }

  Future<int> insertDoc(LocalDoc doc) async => (await db).insert(
        'local_docs',
        doc.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<List<LocalDoc>> docs({String? format, String? query}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (format != null) {
      where.add('format = ?');
      args.add(format);
    }
    if (query != null && query.isNotEmpty) {
      where.add('title LIKE ?');
      args.add('%$query%');
    }
    final rows = await d.query(
      'local_docs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'last_opened DESC, date_added DESC',
    );
    return rows.map(LocalDoc.fromMap).toList();
  }

  Future<void> deleteDoc(int id) async =>
      (await db).delete('local_docs', where: 'id = ?', whereArgs: [id]);

  Future<void> updateDocProgress(int id, double progress) async =>
      (await db).update(
        'local_docs',
        {
          'progress': progress.clamp(0, 1),
          'last_opened': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateDocPage(int id, int page, int totalPages) async =>
      (await db).update(
        'local_docs',
        {
          'last_page': page,
          'progress': totalPages > 0 ? (page / totalPages).clamp(0, 1) : 0,
          'last_opened': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> addBookmark(int docId, int page, String? label) async =>
      (await db).insert('bookmarks', {
        'doc_id': docId,
        'page': page,
        'label': label,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Map<String, Object?>>> bookmarks(int docId) async =>
      (await db).query('bookmarks',
          where: 'doc_id = ?', whereArgs: [docId], orderBy: 'page ASC');

  Future<void> deleteBookmark(int id) async =>
      (await db).delete('bookmarks', where: 'id = ?', whereArgs: [id]);

  // ---- Notes ----
  Future<int> addNote(Map<String, Object?> note) async =>
      (await db).insert('notes', note);

  Future<List<Map<String, Object?>>> notes({String query = ''}) async {
    final d = await db;
    if (query.trim().isEmpty) {
      return d.query('notes', orderBy: 'created_at DESC');
    }
    return d.query('notes',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC');
  }

  Future<void> deleteNote(int id) async =>
      (await db).delete('notes', where: 'id = ?', whereArgs: [id]);

  // ---- Review cards (SM-2) ----
  Future<int> addCard(String front, String back) async =>
      (await db).insert('review_cards', {
        'front': front,
        'back': back,
        'due_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Map<String, Object?>>> dueCards() async => (await db).query(
        'review_cards',
        where: 'due_date <= ?',
        whereArgs: [DateTime.now().toIso8601String()],
        orderBy: 'due_date ASC',
      );

  Future<int> cardCount() async {
    final r = await (await db).rawQuery('SELECT COUNT(*) AS c FROM review_cards');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Simplified SM-2 grading. quality: 0 = again, 3 = hard, 4 = good, 5 = easy.
  Future<void> gradeCard(Map<String, Object?> card, int quality) async {
    var ease = (card['ease'] as num).toDouble();
    var interval = card['interval_days'] as int;
    var reps = card['repetitions'] as int;
    if (quality < 3) {
      reps = 0;
      interval = 1;
    } else {
      reps += 1;
      interval = reps == 1
          ? 1
          : reps == 2
              ? 6
              : (interval * ease).round().clamp(1, 365);
    }
    ease = (ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, 2.8);
    final due = DateTime.now().add(Duration(days: interval));
    await (await db).update(
      'review_cards',
      {
        'ease': ease,
        'interval_days': interval,
        'repetitions': reps,
        'due_date': due.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [card['id']],
    );
  }

  Future<void> deleteCard(int id) async =>
      (await db).delete('review_cards', where: 'id = ?', whereArgs: [id]);

  // ---- Summaries ----
  Future<int> saveSummary(String style, String content) async {
    final now = DateTime.now().toIso8601String();
    return (await db).insert('summaries', {
      'style': style,
      'content': content,
      'created_at': now,
      'modified_at': now,
    });
  }

  Future<List<Map<String, Object?>>> summaries() async =>
      (await db).query('summaries', orderBy: 'created_at DESC');

  Future<void> deleteSummary(int id) async =>
      (await db).delete('summaries', where: 'id = ?', whereArgs: [id]);

  // ---- Statistics (real user data only) ----
  Future<Map<String, Object?>> stats() async {
    final d = await db;
    Future<int> count(String sql, [List<Object?> args = const []]) async {
      final r = await d.rawQuery(sql, args);
      return (r.first.values.first as int?) ?? 0;
    }

    final totalBooks = await count('SELECT COUNT(*) FROM books');
    final finished =
        await count("SELECT COUNT(*) FROM books WHERE status = 'finished'");
    final reading =
        await count("SELECT COUNT(*) FROM books WHERE status = 'reading'");
    final want =
        await count("SELECT COUNT(*) FROM books WHERE status = 'want'");
    final docs = await count('SELECT COUNT(*) FROM local_docs');
    final notesCount = await count('SELECT COUNT(*) FROM notes');
    final ratingRow = await d.rawQuery(
        'SELECT AVG(rating) AS a FROM books WHERE rating IS NOT NULL AND rating > 0');
    final avgRating = (ratingRow.first['a'] as num?)?.toDouble() ?? 0;
    final pagesRow =
        await d.rawQuery('SELECT COALESCE(SUM(pages),0) AS p FROM books');
    final totalPages = (pagesRow.first['p'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final finishedThisMonth = await count(
        "SELECT COUNT(*) FROM books WHERE status = 'finished' AND finish_date >= ?",
        [monthStart]);
    final sessionsRow = await d.rawQuery(
        'SELECT COALESCE(SUM(minutes),0) AS s FROM sessions');
    final sessionSec = ((sessionsRow.first['s'] as num?)?.toInt() ?? 0) * 60;
    final topAuthors = await d.rawQuery(
        'SELECT author, COUNT(*) AS c FROM books WHERE author IS NOT NULL AND author != \'\' GROUP BY author ORDER BY c DESC LIMIT 5');
    return {
      'totalBooks': totalBooks,
      'finished': finished,
      'reading': reading,
      'want': want,
      'docs': docs,
      'notes': notesCount,
      'avgRating': avgRating,
      'totalPages': totalPages,
      'finishedThisMonth': finishedThisMonth,
      'sessionSec': sessionSec,
      'topAuthors': topAuthors,
    };
  }

  Future<int> addHighlightRect({
    required int docId,
    required int page,
    required String color,
    required String rectJson,
  }) async {
    final database = await db;
    return database.insert('highlights', {
      'doc_id': docId,
      'text': '',
      'color': color,
      'page': page,
      'rect': rectJson,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> highlightsForDoc(int docId) async {
    final database = await db;
    return database.query('highlights',
        where: 'doc_id = ?', whereArgs: [docId], orderBy: 'page ASC, id ASC');
  }

  Future<void> deleteHighlight(int id) async {
    final database = await db;
    await database.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }
}
