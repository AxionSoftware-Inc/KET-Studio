import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/editor_service.dart';
import 'tutorial_model.dart';

class TutorialWidget extends StatefulWidget {
  const TutorialWidget({super.key});

  @override
  State<TutorialWidget> createState() => _TutorialWidgetState();
}

class _TutorialWidgetState extends State<TutorialWidget> {
  Tutorial? _selectedTutorial;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _selectedTutorial != null
          ? _TutorialDetailView(
              key: ValueKey(_selectedTutorial!.id),
              tutorial: _selectedTutorial!,
              onBack: () => setState(() => _selectedTutorial = null),
            )
          : _buildGridView(),
    );
  }

  Widget _buildGridView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LEARNING LAB",
                style: KetTheme.headerStyle.copyWith(
                  color: KetTheme.accent,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Master Quantum Computation",
                style: KetTheme.headerStyle.copyWith(
                  fontSize: 22,
                  color: KetTheme.textMain,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 180,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: quantumTutorials.length,
            itemBuilder: (context, index) {
              final tutorial = quantumTutorials[index];
              return _TutorialCard(
                tutorial: tutorial,
                onTap: () => setState(() => _selectedTutorial = tutorial),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final Tutorial tutorial;
  final VoidCallback onTap;

  const _TutorialCard({required this.tutorial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diffColor = _getDifficultyColor(tutorial.difficulty);

    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final isHovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHovered ? (Matrix4.identity()..scale(1.02, 1.02)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isHovered ? KetTheme.bgHover : KetTheme.bgSidebar,
            borderRadius: KetTheme.radiusLg,
            border: Border.all(
              color: isHovered ? KetTheme.accent.withValues(alpha: 0.5) : KetTheme.border,
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: isHovered ? KetTheme.softShadow : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(tutorial.icon, color: KetTheme.accent, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tutorial.difficulty.name.toUpperCase(),
                      style: TextStyle(
                        color: diffColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                tutorial.title,
                style: KetTheme.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(FluentIcons.clock, size: 12, color: KetTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    tutorial.duration,
                    style: KetTheme.descriptionStyle.copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  Icon(FluentIcons.chevron_right_med, size: 12, color: KetTheme.textMuted),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getDifficultyColor(Difficulty diff) {
    switch (diff) {
      case Difficulty.beginner:
        return KetTheme.success;
      case Difficulty.intermediate:
        return KetTheme.warning;
      case Difficulty.advanced:
        return KetTheme.danger;
    }
  }
}

class _TutorialDetailView extends StatelessWidget {
  final Tutorial tutorial;
  final VoidCallback onBack;

  const _TutorialDetailView({
    super.key,
    required this.tutorial,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Premium App Bar
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(bottom: BorderSide(color: KetTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.back),
                onPressed: onBack,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tutorial.title,
                    style: KetTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${tutorial.difficulty.name.toUpperCase()} • ${tutorial.duration}",
                    style: KetTheme.descriptionStyle.copyWith(fontSize: 10, letterSpacing: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            itemCount: tutorial.sections.length,
            itemBuilder: (context, index) {
              final section = tutorial.sections[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 500 + (index * 150)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _SectionWidget(section: section),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final TutorialSection section;

  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: KetTheme.headerStyle.copyWith(
            color: KetTheme.accent,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          section.subtitle,
          style: KetTheme.bodyStyle.copyWith(
            color: KetTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        _buildRichContent(section.content),
        if (section.codeSnippet != null) ...[
          const SizedBox(height: 20),
          _CodeBlock(
            code: section.codeSnippet!,
            filename: "lab_${section.title.toLowerCase().replaceAll(' ', '_')}.py",
          ),
        ],
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRichContent(String content) {
    final parts = content.split('\$');
    List<Widget> inlineParts = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        if (parts[i].isNotEmpty) {
          inlineParts.add(
            Text(
              parts[i],
              style: KetTheme.bodyStyle.copyWith(
                height: 1.6,
                color: KetTheme.textMain.withValues(alpha: 0.9),
              ),
            ),
          );
        }
      } else {
        if (parts[i].isNotEmpty) {
          inlineParts.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Math.tex(
                parts[i],
                mathStyle: MathStyle.text,
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
          );
        }
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: inlineParts,
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  final String filename;

  const _CodeBlock({required this.code, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KetTheme.bgActivityBar,
        borderRadius: KetTheme.radiusLg,
        border: Border.all(color: KetTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KetTheme.bgHeader,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: KetTheme.border)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.code, size: 12, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  filename,
                  style: KetTheme.descriptionStyle.copyWith(fontSize: 11),
                ),
                const Spacer(),
                Tooltip(
                  message: "Open in Editor",
                  child: HoverButton(
                    onPressed: () => EditorService().openFile(filename, code),
                    builder: (context, states) => Icon(
                      FluentIcons.open_file,
                      size: 14,
                      color: states.isHovered ? KetTheme.accent : KetTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'Cascadia Mono',
                fontSize: 11,
                color: Color(0xFFDCDCAA),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
