import 'dart:async';

final class CommandDescriptor {
  const CommandDescriptor({
    required this.id,
    required this.title,
    required this.category,
    this.keybinding,
    this.keywords = const <String>[],
  });

  final String id;
  final String title;
  final String category;
  final String? keybinding;
  final List<String> keywords;
}

typedef CommandHandler = FutureOr<void> Function();

final class CommandRegistry {
  final Map<String, (CommandDescriptor, CommandHandler)> _commands =
      <String, (CommandDescriptor, CommandHandler)>{};

  List<CommandDescriptor> get commands => _commands.values
      .map((value) => value.$1)
      .toList(growable: false)
    ..sort((a, b) => a.title.compareTo(b.title));

  void register(CommandDescriptor descriptor, CommandHandler handler) {
    if (_commands.containsKey(descriptor.id)) {
      throw StateError('Command already registered: ${descriptor.id}');
    }
    _commands[descriptor.id] = (descriptor, handler);
  }

  void unregister(String id) => _commands.remove(id);

  Future<void> invoke(String id) async {
    final entry = _commands[id];
    if (entry == null) throw StateError('Unknown command: $id');
    await entry.$2();
  }

  List<CommandDescriptor> search(String query, {int limit = 20}) {
    final normalized = query.trim().toLowerCase();
    final scored = <(int, CommandDescriptor)>[];
    for (final entry in _commands.values) {
      final descriptor = entry.$1;
      final haystack = <String>[
        descriptor.title,
        descriptor.category,
        descriptor.id,
        ...descriptor.keywords,
        if (descriptor.keybinding != null) descriptor.keybinding!,
      ].join(' ').toLowerCase();
      final score = _score(normalized, descriptor.title.toLowerCase(), haystack);
      if (score >= 0) scored.add((score, descriptor));
    }
    scored.sort((a, b) {
      final score = b.$1.compareTo(a.$1);
      return score != 0 ? score : a.$2.title.compareTo(b.$2.title);
    });
    return scored.take(limit).map((item) => item.$2).toList(growable: false);
  }

  int _score(String query, String title, String haystack) {
    if (query.isEmpty) return 1;
    if (title == query) return 1000;
    if (title.startsWith(query)) return 800 - (title.length - query.length);
    final direct = haystack.indexOf(query);
    if (direct >= 0) return 600 - direct;

    var cursor = 0;
    var gaps = 0;
    for (final rune in query.runes) {
      final char = String.fromCharCode(rune);
      final next = haystack.indexOf(char, cursor);
      if (next < 0) return -1;
      gaps += next - cursor;
      cursor = next + 1;
    }
    return 300 - gaps;
  }
}
