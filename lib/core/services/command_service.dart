import 'package:fluent_ui/fluent_ui.dart';

class Command {
  final String id;
  final String title;
  final String? shortcut;
  final IconData? icon;
  final VoidCallback action;
  final bool Function()? isEnabled;

  Command({
    required this.id,
    required this.title,
    required this.action,
    this.shortcut,
    this.icon,
    this.isEnabled,
  });
}

class CommandService extends ChangeNotifier {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  final Map<String, Command> _commands = {};

  void registerCommand(Command cmd) {
    _commands[cmd.id] = cmd;
    notifyListeners();
  }

  void execute(String id) {
    final cmd = _commands[id];
    if (cmd != null) {
      if (cmd.isEnabled == null || cmd.isEnabled!()) {
        cmd.action();
      }
    }
  }

  Command? getCommand(String id) => _commands[id];

  List<Command> get allCommands => _commands.values.toList();
}
