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
      version: 1,
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
  page INTEGER, chapter TEXT, note TEXT, tags TEXT, created_at TEXT NOT NULL)''');
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
}
