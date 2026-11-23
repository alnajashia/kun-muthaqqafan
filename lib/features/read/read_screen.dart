import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/db/app_database.dart';
import '../../core/services/device_scanner.dart';
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


  bool _scanning = false;

  Future<void> scanDevice() async {
    final s = widget.s;
    final hasAccess = await DeviceScanner.hasAllFilesAccess();
    if (!hasAccess && mounted) {
      final grant = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s.isAr ? 'بحث تلقائي في الهاتف' : 'Automatic device scan'),
          content: Text(s.isAr
              ? 'للبحث في كل ملفات PDF وEPUB وTXT على هاتفك يحتاج التطبيق إذن «الوصول إلى كل الملفات». الملفات تبقى على جهازك ولا تُرفع لأي مكان. يمكنك المتابعة بدونه وسيبحث التطبيق في فهرس الوسائط فقط.'
              : 'To find every PDF, EPUB and TXT file on your phone, the app needs "All files access". Files stay on your device and are never uploaded. You can continue without it and the app will search the media index only.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s.isAr ? 'متابعة بدون الإذن' : 'Continue without'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s.isAr ? 'منح الإذن' : 'Grant access'),
            ),
          ],
        ),
      );
      if (grant == true) {
        await DeviceScanner.requestAllFilesAccess();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.isAr
                ? 'فعّل الإذن ثم ارجع واضغط زر البحث مرة أخرى.'
                : 'Enable the permission, come back, and tap scan again.')));
        return;
      }
    }
    setState(() => _scanning = true);
    try {
      final found = await DeviceScanner.scan();
      var added = 0;
      for (final f in found) {
        final path = f['path'] as String?;
        final name = f['name'] as String?;
        if (path == null || name == null) continue;
        final ext = p.extension(name).replaceAll('.', '').toLowerCase();
        if (!['pdf', 'epub', 'txt'].contains(ext)) continue;
        final id = await AppDatabase.instance.insertDoc(LocalDoc(
          title: p.basenameWithoutExtension(name),
          filePath: path,
          format: ext,
          fileSize: (f['size'] as num?)?.toInt() ?? 0,
          dateModified: DateTime.fromMillisecondsSinceEpoch(
              (f['modified'] as num?)?.toInt() ?? 0),
          dateAdded: DateTime.now(),
        ));
        if (id > 0) added++;
      }
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.isAr
                ? 'اكتمل البحث: وُجد ${found.length} ملفاً، أُضيف $added جديداً.'
                : 'Scan complete: ${found.length} files found, $added new added.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.isAr ? 'تعذّر البحث: $e' : 'Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
      appBar: AppBar(title: Text(s.localBooks), actions: [
        IconButton(
          icon: _scanning
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          tooltip: s.isAr ? 'بحث تلقائي في الهاتف' : 'Scan device',
          onPressed: _scanning ? null : scanDevice,
        ),
      ]),
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
