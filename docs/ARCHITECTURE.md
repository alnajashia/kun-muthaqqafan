# Architecture — Kun Muthaqqafan

Clean-room original Flutter app inspired by Openreads (GPL-2.0, attribution in About/README). No copied code.

- `lib/core/theme` — sky-blue flat design system (no gradients), light/dark.
- `lib/core/l10n` — AR/EN strings, Arabic default, RTL via MaterialApp locale.
- `lib/core/db` — sqflite local-first store (books, local_docs, notes, highlights, bookmarks, sessions, review_cards, summaries).
- `lib/models` — Book, LocalDoc.
- `lib/features/{home,library,read,discover,profile,shell}` — 5-tab shell.

Batches: 1 shell+library core (done), 2 local import hardening, 3 readers (PDF/EPUB/TXT), 4 notes/highlights/review SM-2, 5 AI abstraction + stats + backup/export. AI ships as provider abstraction with honest unconfigured state; no hardcoded keys.
