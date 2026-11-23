import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

class LibraryScreen extends StatefulWidget {
  final AppStrings s;
  const LibraryScreen({super.key, required this.s});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? _filter;
  String _query = '';
  bool _grid = true;
  late Future<List<Book>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AppDatabase.instance.books(status: _filter, query: _query);
  }

  Future<void> _addOrEdit([Book? existing]) async {
    final s = widget.s;
    final title = TextEditingController(text: existing?.title ?? '');
    final author = TextEditingController(text: existing?.author ?? '');
    final pages = TextEditingController(
        text: existing?.pages?.toString() ?? '');
    String status = existing?.status ?? 'want';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? s.addBook : s.edit),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: s.title)),
              TextField(
                  controller: author,
                  decoration: InputDecoration(labelText: s.author)),
              TextField(
                  controller: pages,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.pages)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: InputDecoration(labelText: s.status),
                items: ['reading', 'want', 'finished', 'dnf', 'paused']
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text(s.statusLabel(v))))
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? 'want'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.save)),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (existing == null) {
      await AppDatabase.instance.insertBook(Book(
        title: title.text.trim(),
        author: author.text.trim(),
        status: status,
        pages: int.tryParse(pages.text.trim()),
        dateAdded: now,
        dateModified: now,
      ));
    } else {
      await AppDatabase.instance.updateBook(existing.copyWith(
        title: title.text.trim(),
        author: author.text.trim(),
        status: status,
        pages: int.tryParse(pages.text.trim()),
        dateModified: now,
      ));
    }
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.library), actions: [
        IconButton(
          icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _grid = !_grid),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: Text(s.addBook),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: s.searchLibrary,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _reload();
            }),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ChoiceChip(
                label: Text(s.allBooks),
                selected: _filter == null,
                onSelected: (_) => setState(() {
                  _filter = null;
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              for (final st in ['reading', 'want', 'finished', 'dnf', 'paused'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.statusLabel(st)),
                    selected: _filter == st,
                    onSelected: (_) => setState(() {
                      _filter = st;
                      _reload();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Book>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final books = snap.data!;
              if (books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s.emptyLibrary,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                );
              }
              if (_grid) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: books.length,
                  itemBuilder: (_, i) => _BookTile(
                    book: books[i],
                    s: s,
                    onTap: () => _showDetails(books[i]),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: Text(books[i].title),
                    subtitle: Text(
                        '${books[i].author} • ${s.statusLabel(books[i].status)}'),
                    trailing: books[i].favourite
                        ? const Icon(Icons.favorite, color: Colors.red)
                        : null,
                    onTap: () => _showDetails(books[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showDetails(Book b) {
    final s = widget.s;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(b.title, style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${b.author} • ${s.statusLabel(b.status)}'),
          if (b.pages != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: b.progress),
            const SizedBox(height: 4),
            Text('${b.currentPage} / ${b.pages}'),
          ],
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await AppDatabase.instance.deleteBook(b.id!);
                if (mounted) setState(_reload);
              },
              child: Text(s.delete),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addOrEdit(b);
              },
              child: Text(s.edit),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  final AppStrings s;
  final VoidCallback onTap;
  const _BookTile({required this.book, required this.s, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.menu_book, size: 32),
            const Spacer(),
            Text(book.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(book.author,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: book.progress),
          ],
        ),
      ),
    );
  }
}
