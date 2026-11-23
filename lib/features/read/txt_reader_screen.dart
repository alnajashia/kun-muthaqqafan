import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

/// TXT reader: encoding fallback, font size, reading themes, in-text
/// search (match count + jump), bookmarks, progress persistence.
class TxtReaderScreen extends StatefulWidget {
  final AppStrings s;
  final LocalDoc doc;
  const TxtReaderScreen({super.key, required this.s, required this.doc});
  @override
  State<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends State<TxtReaderScreen> {
  final _scroll = ScrollController();
  String? _text;
  String? _error;
  double _fontSize = 18;
  int _themeIdx = 0; // 0 light, 1 sepia, 2 dark
  bool _rtl = true;
  final _searchCtrl = TextEditingController();
  int _matchCount = 0;

  static const _themes = [
    (bg: Color(0xFFFFFFFF), fg: Color(0xFF0F172A)),
    (bg: Color(0xFFF5EFE0), fg: Color(0xFF3E3428)),
    (bg: Color(0xFF0B1220), fg: Color(0xFFE2E8F0)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveProgress();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.doc.filePath).readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      if (!mounted) return;
      setState(() {
        _text = text;
        // Auto-detect direction: Arabic chars present -> RTL.
        _rtl = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && widget.doc.progress > 0) {
          _scroll.jumpTo(
              _scroll.position.maxScrollExtent * widget.doc.progress);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  double get _progress {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent == 0) {
      return widget.doc.progress;
    }
    return (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0, 1);
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  Future<void> _saveProgress() async {
    if (widget.doc.id == null) return;
    await AppDatabase.instance.updateDocProgress(widget.doc.id!, _progress);
  }

  void _runSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty || _text == null) {
      setState(() => _matchCount = 0);
      return;
    }
    final count = q.allMatches(_text!).length;
    setState(() => _matchCount = count);
    if (count > 0 && _scroll.hasClients) {
      final idx = _text!.indexOf(q);
      final ratio = idx / _text!.length;
      _scroll.animateTo(_scroll.position.maxScrollExtent * ratio,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  Future<void> _addBookmark() async {
    final page = (_progress * 100).round();
    await AppDatabase.instance.addBookmark(widget.doc.id!, page, null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.s.isAr
              ? 'حُفظت علامة عند $page%'
              : 'Bookmark saved at $page%')));
    }
  }

  Future<void> _showBookmarks() async {
    final items = await AppDatabase.instance.bookmarks(widget.doc.id!);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: items.isEmpty
            ? [ListTile(title: Text(widget.s.noResults))]
            : items
                .map((b) => ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text('${b['page']}%'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (_scroll.hasClients) {
                          _scroll.jumpTo(_scroll.position.maxScrollExtent *
                              ((b['page'] as int) / 100));
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await AppDatabase.instance
                              .deleteBookmark(b['id'] as int);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ))
                .toList(),
      ),
    );
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
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _addBookmark),
          IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: _showBookmarks),
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
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('RTL')),
                        ButtonSegment(value: false, label: Text('LTR')),
                      ],
                      selected: {_rtl},
                      onSelectionChanged: (v) {
                        setLocal(() => _rtl = v.first);
                        setState(() => _rtl = v.first);
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _text == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: s.isAr ? 'ابحث داخل النص…' : 'Search in text…',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _runSearch(),
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.search), onPressed: _runSearch),
                      if (_matchCount > 0) Text('$_matchCount'),
                    ]),
                  ),
                  LinearProgressIndicator(value: _progress),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(20),
                      child: Directionality(
                        textDirection:
                            _rtl ? TextDirection.rtl : TextDirection.ltr,
                        child: SelectableText(
                          _text!,
                          style: TextStyle(
                            fontSize: _fontSize,
                            height: 1.8,
                            color: theme.fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
    );
  }
}
