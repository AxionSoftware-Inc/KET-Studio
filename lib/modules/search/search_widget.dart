import 'package:fluent_ui/fluent_ui.dart';
import '../../core/theme/ket_theme.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _matchCase = false;
  bool _wholeWord = false;
  bool _useRegex = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextBox(
                controller: _searchController,
                placeholder: 'Search keywords...',
                onChanged: (v) => setState(() {}),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchOption(
                      icon: FluentIcons.lower_case,
                      active: _matchCase,
                      onPressed: () => setState(() => _matchCase = !_matchCase),
                      tooltip: 'Match Case',
                    ),
                    _SearchOption(
                      icon: FluentIcons.text_callout,
                      active: _wholeWord,
                      onPressed: () => setState(() => _wholeWord = !_wholeWord),
                      tooltip: 'Whole Word',
                    ),
                    _SearchOption(
                      icon: FluentIcons.embed,
                      active: _useRegex,
                      onPressed: () => setState(() => _useRegex = !_useRegex),
                      tooltip: 'Use Regular Expression',
                    ),
                  ],
                ),
                decoration: WidgetStateProperty.all(
                  BoxDecoration(
                    border: Border(bottom: BorderSide(color: KetTheme.border, width: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Results Placeholder
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.search_and_apps,
                  size: 32,
                  color: KetTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchController.text.isEmpty
                      ? "Start searching across your workspace"
                      : "No results for '${_searchController.text}'",
                  style: KetTheme.descriptionStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchOption extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final String tooltip;

  const _SearchOption({
    required this.icon,
    required this.active,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 14,
          color: active ? KetTheme.accent : KetTheme.textMuted,
        ),
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(
            active ? KetTheme.accentSoft : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
