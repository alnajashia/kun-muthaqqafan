import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';
import 'epub_reader_screen.dart';
import 'pdf_reader_screen.dart';
import 'txt_reader_screen.dart';

class ReadScreen extends StatefulWidget {
  final AppStrings s;
  const ReadScreen({super.key, required this.s});
  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  String? _format;
  late Future<List<LocalDoc>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = AppDatabase.instance.docs(format: _format);

  Future<void> importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'txt'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      final file = File(f.path!);
      final stat = await file.stat();
      final ext = p.extension(f.name).replaceAll('.', '').toLowerCase();
      await AppDatabase.instance.insertDoc(LocalDoc(
        title: p.basenameWithoutExtension(f.name),
        filePath: f.path!,
        format: ext,
        fileSize: stat.size,
        dateModified: stat.modified,
        dateAdded: DateTime.now(),
      ));
    }
    if (mounted) setState(_reload);
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.localBooks)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: importFiles,
        icon: const Icon(Icons.file_upload),
        label: Text(s.importBook),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              ChoiceChip(
                  label: Text(s.allBooks),
                  selected: _format == null,
                  onSelected: (_) => setState(() {
                        _format = null;
                        _reload();
                      })),
              const SizedBox(width: 8),
              for (final f in ['pdf', 'epub', 'txt'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(f.toUpperCase()),
                      selected: _format == f,
                      onSelected: (_) => setState(() {
                            _format = f;
                            _reload();
                          })),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<LocalDoc>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data!.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(s.emptyRead,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snap.data!.length,
                itemBuilder: (_, i) {
                  final d = snap.data![i];
                  return Card(
                    child: ListTile(
                      leading: Icon(d.format == 'pdf'
                          ? Icons.picture_as_pdf
                          : d.format == 'epub'
                              ? Icons.book
                              : Icons.description),
                      title: Text(d.title),
                      subtitle: Text(
                          '${d.format.toUpperCase()} • ${_size(d.fileSize)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await AppDatabase.instance.deleteDoc(d.id!);
                          if (mounted) setState(_reload);
                        },
                      ),
                      onTap: () {
                        final Widget? screen = switch (d.format) {
                          'txt' => TxtReaderScreen(s: s, doc: d),
                          'pdf' => PdfReaderScreen(s: s, doc: d),
                          'epub' => EpubReaderScreen(s: s, doc: d),
                          _ => null,
                        };
                        if (screen != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => screen),
                          ).then((_) {
                            if (mounted) setState(_reload);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(s.isAr
                                    ? 'صيغة غير مدعومة بعد — الملف محفوظ في مكتبتك.'
                                    : 'Format not supported yet — your file is saved in your library.')),
                          );
                        }
                      },
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
