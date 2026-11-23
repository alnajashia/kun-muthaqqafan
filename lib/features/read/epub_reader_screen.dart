import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

/// EPUB reader: parses the book with epubx, chapter list (TOC), clean
/// text rendering (HTML stripped), font size, light/sepia/dark themes,
/// chapter-based progress persistence, bookmarks.
class EpubReaderScreen extends StatefulWidget {
  final AppStrings s;
  final LocalDoc doc;
  const EpubReaderScreen({super.key, required this.s, required this.doc});
  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  List<({String title, String text})> _chapters = [];
  int _chapter = 0;
  double _fontSize = 18;
  int _themeIdx = 0;
  String? _error;
  bool _loading = true;

  static const _themes = [
    (bg: Color(0xFFFFFFFF), fg: Color(0xFF0F172A)),
    (bg: Color(0xFFF5EFE0), fg: Color(0xFF3E3428)),
    (bg: Color(0xFF0B1220), fg: Color(0xFFE2E8F0)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), '')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li|br)>'), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.doc.filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapters = <({String title, String text})>[];
      void walk(List<EpubChapter>? list) {
        for (final ch in list ?? <EpubChapter>[]) {
          final text = _stripHtml(ch.HtmlContent ?? '');
          if (text.isNotEmpty) {
            chapters.add((title: ch.Title ?? '', text: text));
          }
          walk(ch.SubChapters);
        }
      }

      walk(book.Chapters);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _chapter = widget.doc.lastPage.clamp(
            0, chapters.isEmpty ? 0 : chapters.length - 1);
        _loading = false;
        if (chapters.isEmpty) {
          _error = widget.s.isAr
              ? 'تعذّر استخراج فصول من هذا الملف.'
              : 'Could not extract chapters from this file.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _go(int index) async {
    setState(() => _chapter = index);
    if (widget.doc.id != null && _chapters.isNotEmpty) {
      await AppDatabase.instance
          .updateDocPage(widget.doc.id!, index, _chapters.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = _themes[_themeIdx];
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        title: Text(widget.doc.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _chapters.isEmpty
                ? null
                : () => showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => ListView.builder(
                        itemCount: _chapters.length,
                        itemBuilder: (ctx, i) => ListTile(
                          title: Text(_chapters[i].title.isEmpty
                              ? '${s.isAr ? 'فصل' : 'Chapter'} ${i + 1}'
                              : _chapters[i].title),
                          selected: i == _chapter,
                          onTap: () {
                            Navigator.pop(ctx);
                            _go(i);
                          },
                        ),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setLocal) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text(s.isAr ? 'حجم الخط' : 'Font size'),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12,
                          max: 32,
                          onChanged: (v) {
                            setLocal(() => _fontSize = v);
                            setState(() => _fontSize = v);
                          },
                        ),
                      ),
                      Text('${_fontSize.round()}'),
                    ]),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                            value: 0, label: Text(s.isAr ? 'فاتح' : 'Light')),
                        ButtonSegment(
                            value: 1, label: Text(s.isAr ? 'ورقي' : 'Sepia')),
                        ButtonSegment(
                            value: 2, label: Text(s.isAr ? 'داكن' : 'Dark')),
                      ],
                      selected: {_themeIdx},
                      onSelectionChanged: (v) {
                        setLocal(() => _themeIdx = v.first);
                        setState(() => _themeIdx = v.first);
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(children: [
                  LinearProgressIndicator(
                      value: _chapters.isEmpty
                          ? 0
                          : (_chapter + 1) / _chapters.length),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        _chapters[_chapter].text,
                        style: TextStyle(
                            fontSize: _fontSize, height: 1.8, color: theme.fg),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: Text(s.isAr ? 'السابق' : 'Previous'),
                        onPressed:
                            _chapter > 0 ? () => _go(_chapter - 1) : null,
                      ),
                      Text('${_chapter + 1} / ${_chapters.length}'),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(s.isAr ? 'التالي' : 'Next'),
                        onPressed: _chapter < _chapters.length - 1
                            ? () => _go(_chapter + 1)
                            : null,
                      ),
                    ],
                  ),
                ]),
    );
  }
}
