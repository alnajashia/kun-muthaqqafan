import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

/// Local-first backup: exports the user's library data (books, local docs
/// metadata, notes, highlights, bookmarks, review cards, summaries) to
/// JSON or CSV files in the app documents directory. Never touches the
/// user's original document files.
class BackupService {
  static const _tables = [
    'books',
    'local_docs',
    'notes',
    'highlights',
    'bookmarks',
    'review_cards',
    'summaries',
    'sessions',
  ];

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> exportJson() async {
    final db = await AppDatabase.instance.db;
    final data = <String, Object?>{
      'app': 'kun_muthaqqafan',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final t in _tables) {
      data[t] = await db.query(t);
    }
    final dir = await _dir();
    final name =
        'kun_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<String> exportBooksCsv() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('books', orderBy: 'title ASC');
    final buf = StringBuffer(
        'title,author,status,rating,pages,current_page,isbn,publisher,publication_year,genre,language,date_added\n');
    String esc(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(',') || s.contains('"')
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    for (final r in rows) {
      buf.writeln([
        r['title'],
        r['author'],
        r['status'],
        r['rating'],
        r['pages'],
        r['current_page'],
        r['isbn'],
        r['publisher'],
        r['publication_year'],
        r['genre'],
        r['language'],
        r['date_added'],
      ].map(esc).join(','));
    }
    final dir = await _dir();
    final name =
        'kun_books_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(buf.toString());
    return file.path;
  }

  /// Restores a JSON backup. Existing rows with the same id are replaced;
  /// original user documents on disk are never deleted.
  Future<int> restoreJson(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['app'] != 'kun_muthaqqafan') {
      throw const FormatException('Not a Kun Muthaqqafan backup');
    }
    final db = await AppDatabase.instance.db;
    var count = 0;
    for (final t in _tables) {
      final rows = decoded[t];
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is Map) {
          await db.insert(t, row.cast<String, Object?>(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        }
      }
    }
    return count;
  }

  Future<List<File>> listBackups() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
