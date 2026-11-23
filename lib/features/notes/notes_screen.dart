import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';

/// Notes library: searchable notes with optional book link, page, tags.
class NotesScreen extends StatefulWidget {
  final AppStrings s;
  const NotesScreen({super.key, required this.s});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Map<String, Object?>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.notes();
  }

  void _reload() => setState(() => _future = AppDatabase.instance.notes(query: _query));

  Future<void> _add() async {
    final s = widget.s;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final pageCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'ملاحظة جديدة' : 'New note'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: s.isAr ? 'العنوان (اختياري)' : 'Title (optional)')),
            TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration:
                    InputDecoration(labelText: s.isAr ? 'المحتوى' : 'Content')),
            TextField(
                controller: pageCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: s.isAr ? 'الصفحة (اختياري)' : 'Page (optional)')),
            TextField(
                controller: tagsCtrl,
                decoration: InputDecoration(
                    labelText: s.isAr ? 'وسوم (اختياري)' : 'Tags (optional)')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok == true && contentCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      await AppDatabase.instance.addNote({
        'title': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'page': int.tryParse(pageCtrl.text.trim()),
        'tags': tagsCtrl.text.trim().isEmpty ? null : tagsCtrl.text.trim(),
        'created_at': now,
        'modified_at': now,
      });
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.isAr ? 'ملاحظاتي' : 'My notes')),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: s.isAr ? 'ابحث في الملاحظات…' : 'Search notes…',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) {
              _query = v;
              _reload();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Center(
                    child: Text(s.isAr
                        ? 'لا ملاحظات بعد — اكتب أول ملاحظة.'
                        : 'No notes yet — write your first note.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final n = items[i];
                  return Card(
                    child: ListTile(
                      title: Text((n['title'] as String?)?.isNotEmpty == true
                          ? n['title'] as String
                          : (n['content'] as String).split('\n').first),
                      subtitle: Text(
                        [
                          if (n['page'] != null)
                            s.isAr ? 'صفحة ${n['page']}' : 'p. ${n['page']}',
                          if (n['tags'] != null) '#${n['tags']}',
                          (n['created_at'] as String).split('T').first,
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await AppDatabase.instance.deleteNote(n['id'] as int);
                          _reload();
                        },
                      ),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text((n['title'] as String?) ?? ''),
                          content: SingleChildScrollView(
                              child: Text(n['content'] as String)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(s.isAr ? 'إغلاق' : 'Close')),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
