import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../../application/workbench/command_registry.dart';

Future<void> showKetCommandPalette(
  BuildContext context,
  CommandRegistry registry,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CommandPaletteDialog(registry: registry),
  );
}

final class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.registry});
  final CommandRegistry registry;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

final class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  late final TextEditingController _query;
  late List<CommandDescriptor> _results;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _results = widget.registry.search('');
    _query.addListener(_refresh);
  }

  void _refresh() {
    setState(() => _results = widget.registry.search(_query.text));
  }

  Future<void> _invoke(CommandDescriptor command) async {
    Navigator.of(context).pop();
    await widget.registry.invoke(command.id);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
      title: const Text('Command Palette'),
      content: SizedBox(
        width: 580,
        height: 390,
        child: Column(
          children: <Widget>[
            TextBox(
              controller: _query,
              autofocus: true,
              placeholder: 'Type a command…',
              onSubmitted: (_) {
                if (_results.isNotEmpty) unawaited(_invoke(_results.first));
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final command = _results[index];
                  return GestureDetector(
                    onTap: () => unawaited(_invoke(command)),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF202A34))),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(command.title, style: const TextStyle(fontSize: 12)),
                                Text(
                                  command.category,
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF778391)),
                                ),
                              ],
                            ),
                          ),
                          if (command.keybinding != null)
                            Text(
                              command.keybinding!,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8D99A7)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        Button(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  @override
  void dispose() {
    _query.removeListener(_refresh);
    _query.dispose();
    super.dispose();
  }
}
