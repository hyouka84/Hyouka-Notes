import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _muted = Color(0xFFAAAAAA);
const _line = Color(0xFF292929);
const _panel = Color(0xFF080808);
const _storageKey = 'hyouka_notes_v1';
const _categories = <String>['Personal', 'Work', 'Ideas', 'Other'];
const _filters = <String>['All', 'Pinned', ..._categories];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyoukaNotesApp());
}

class HyoukaNotesApp extends StatelessWidget {
  const HyoukaNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyouka Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _black,
        canvasColor: _black,
        colorScheme: const ColorScheme.dark(
          primary: _white,
          onPrimary: _black,
          surface: _black,
          onSurface: _white,
          error: Color(0xFFFF6B6B),
        ),
        dividerColor: _line,
        appBarTheme: const AppBarTheme(
          backgroundColor: _black,
          foregroundColor: _white,
          surfaceTintColor: Colors.transparent,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _white,
          selectionColor: Color(0x55777777),
          selectionHandleColor: _white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _black,
          hintStyle: const TextStyle(color: _muted),
          labelStyle: const TextStyle(color: _muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _white, width: 1.2),
          ),
        ),
      ),
      home: const NotesHomePage(),
    );
  }
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Note.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return Note(
      id: map['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: map['category'] as String? ?? 'Personal',
      pinned: map['pinned'] == true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? now,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Note copyWith({
    String? title,
    String? body,
    String? category,
    bool? pinned,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Note> _notes = <Note>[];
  String _activeFilter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotes());
    _searchController.addListener(_refreshSearch);
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notes = decoded
            .map((item) => Note.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {
      _notes = <Note>[];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _persistNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_notes.map((note) => note.toMap()).toList());
      await prefs.setString(_storageKey, payload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save notes on this device.')),
      );
    }
  }

  Future<void> _upsertNote(Note note) async {
    setState(() {
      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index == -1) {
        _notes.add(note);
      } else {
        _notes[index] = note;
      }
    });
    await _persistNotes();
  }

  Future<void> _openEditor([Note? note]) async {
    final result = await Navigator.of(context).push<Note>(
      MaterialPageRoute<Note>(
        builder: (_) => NoteEditorPage(initialNote: note),
      ),
    );
    if (!mounted || result == null) return;
    await _upsertNote(result);
  }

  Future<void> _togglePinned(Note note) async {
    await _upsertNote(note.copyWith(
      pinned: !note.pinned,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete note?'),
        content: const Text('This note will be removed from this device.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: _white)),
          ),
          TextButton(
            key: const Key('confirm-delete-note'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF7777)),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _notes.removeWhere((item) => item.id == note.id));
    await _persistNotes();
  }

  List<Note> get _visibleNotes {
    final query = _searchController.text.trim().toLowerCase();
    final result = _notes.where((note) {
      final filterMatches = switch (_activeFilter) {
        'Pinned' => note.pinned,
        'All' => true,
        _ => note.category == _activeFilter,
      };
      final queryMatches = query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.body.toLowerCase().contains(query) ||
          note.category.toLowerCase().contains(query);
      return filterMatches && queryMatches;
    }).toList();
    result.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotes = _visibleNotes;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: <Widget>[
            Icon(Icons.sticky_note_2_outlined, color: _white, size: 25),
            SizedBox(width: 10),
            Text(
              'Hyouka Notes',
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.w700,
                fontSize: 19,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Your thoughts, kept on this device.',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('notes-search-input'),
                controller: _searchController,
                style: const TextStyle(color: _white),
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  prefixIcon: Icon(Icons.search, color: _muted),
                  suffixIcon: Icon(Icons.tune, color: _muted, size: 19),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final selected = filter == _activeFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _activeFilter = filter),
                        showCheckmark: false,
                        selectedColor: const Color(0xFF202020),
                        backgroundColor: _black,
                        side: BorderSide(
                          color: selected ? _white : _line,
                        ),
                        labelStyle: TextStyle(
                          color: selected ? _white : _muted,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _white),
                      )
                    : visibleNotes.isEmpty
                        ? _EmptyState(
                            hasSearch: _searchController.text.isNotEmpty ||
                                _activeFilter != 'All',
                          )
                        : ListView.separated(
                            key: const Key('notes-list'),
                            padding: const EdgeInsets.only(top: 4, bottom: 100),
                            itemCount: visibleNotes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final note = visibleNotes[index];
                              return _NoteTile(
                                note: note,
                                onTap: () => _openEditor(note),
                                onTogglePin: () =>
                                    unawaited(_togglePinned(note)),
                                onDelete: () => unawaited(_deleteNote(note)),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-note-button'),
        tooltip: 'New note',
        onPressed: _openEditor,
        backgroundColor: _white,
        foregroundColor: _black,
        icon: const Icon(Icons.add),
        label: const Text(
          'New note',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.sticky_note_2_outlined,
              color: _white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No matching notes' : 'No notes yet',
              style: const TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different search or filter.'
                  : 'Tap New note to write your first thought.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title =
        note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();
    return Material(
      color: _black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.pinned)
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 2),
                      child: Icon(Icons.push_pin, color: _white, size: 17),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    color: _panel,
                    icon: const Icon(Icons.more_vert, color: _muted),
                    onSelected: (value) {
                      if (value == 'pin') onTogglePin();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Text(note.pinned ? 'Unpin note' : 'Pin note'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.delete_outline, size: 20),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (note.body.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  note.body.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      note.category,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimestamp(note.updatedAt),
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.initialNote});

  final Note? initialNote;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final FocusNode _titleFocus = FocusNode();
  late String _category;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _category = note?.category ?? 'Personal';
    _pinned = note?.pinned ?? false;
  }

  void _save() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trimRight();
    if (title.isEmpty && body.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      _titleFocus.requestFocus();
      return;
    }
    final now = DateTime.now();
    final original = widget.initialNote;
    Navigator.of(context).pop(
      Note(
        id: original?.id ?? now.microsecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Untitled note' : title,
        body: body,
        category: _category,
        pinned: _pinned,
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.initialNote;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close editor',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(original == null ? 'New note' : 'Edit note'),
        actions: <Widget>[
          IconButton(
            key: const Key('pin-note-button'),
            tooltip: _pinned ? 'Unpin note' : 'Pin note',
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: Icon(
              _pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _white,
            ),
          ),
          TextButton(
            key: const Key('save-note-button'),
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('note-title-input'),
              controller: _titleController,
              focusNode: _titleFocus,
              style: const TextStyle(
                color: _white,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              dropdownColor: _black,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.sell_outlined, color: _muted),
              ),
              style: const TextStyle(color: _white),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                key: const Key('note-body-input'),
                controller: _bodyController,
                expands: true,
                minLines: null,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  color: _white,
                  fontSize: 16,
                  height: 1.55,
                ),
                decoration: const InputDecoration(
                  hintText: 'Start writing...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  if (isToday) {
    return 'Today • ' + hour.toString() + ':' + minute + ' ' + period;
  }
  return date.day.toString().padLeft(2, '0') +
      '/' +
      date.month.toString().padLeft(2, '0') +
      '/' +
      date.year.toString();
}
