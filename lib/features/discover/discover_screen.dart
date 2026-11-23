import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

class OlBook {
  final String title;
  final String author;
  final String? olid;
  final String? coverUrl;
  final int? year;
  const OlBook(
      {required this.title, required this.author, this.olid, this.coverUrl, this.year});
}

class DiscoverScreen extends StatefulWidget {
  final AppStrings s;
  const DiscoverScreen({super.key, required this.s});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<OlBook> _results = const [];

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.https('openlibrary.org', '/search.json',
          {'q': q, 'limit': '20', 'fields': 'title,author_name,cover_i,first_publish_year,key'});
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final docs = (data['docs'] as List? ?? const []);
      setState(() {
        _results = docs.map((d) {
          final m = d as Map<String, dynamic>;
          final cover = m['cover_i'] as int?;
          return OlBook(
            title: (m['title'] ?? '') as String,
            author: ((m['author_name'] as List?)?.firstOrNull ?? '') as String,
            olid: m['key'] as String?,
            coverUrl: cover == null
                ? null
                : 'https://covers.openlibrary.org/b/id/$cover-M.jpg',
            year: m['first_publish_year'] as int?,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = widget.s.offlineError;
      });
    }
  }

  Future<void> _add(OlBook b) async {
    final now = DateTime.now();
    await AppDatabase.instance.insertBook(Book(
      title: b.title,
      author: b.author,
      status: 'want',
      olid: b.olid,
      coverUrl: b.coverUrl,
      publicationYear: b.year,
      dateAdded: now,
      dateModified: now,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.s.addToLibrary)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.discover)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                    hintText: s.searchDiscover,
                    border: const OutlineInputBorder()),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _search, child: const Icon(Icons.search)),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: _results.isEmpty && !_loading
              ? Center(child: Text(s.noResults))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final b = _results[i];
                    return ListTile(
                      leading: b.coverUrl == null
                          ? const Icon(Icons.book)
                          : Image.network(b.coverUrl!, width: 40,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.book)),
                      title: Text(b.title),
                      subtitle:
                          Text('${b.author}${b.year == null ? '' : ' • ${b.year}'}'),
                      trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _add(b)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
