import 'package:fluent_ui/fluent_ui.dart';
import '../../core/theme/ket_theme.dart';
import '../../core/services/editor_service.dart';
import '../../core/services/command_service.dart';
import '../templates/templates_service.dart';
import '../../config/demo_content.dart';

class WelcomeWidget extends StatelessWidget {
  const WelcomeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KetTheme.bgCanvas,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KetTheme.bgCanvas,
            KetTheme.bgCanvas,
            KetTheme.accent.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 80.0,
                horizontal: 40.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Title
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: KetTheme.accent.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/quantum.jpg',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DemoContent.welcomeTitle,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                            Text(
                              DemoContent.welcomeSubtitle,
                              style: TextStyle(
                                fontSize: 20,
                                color: KetTheme.textMuted,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),

                  // Actions Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Start Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(FluentIcons.play, "START"),
                            const SizedBox(height: 16),
                            _buildActionItem(
                              context,
                              FluentIcons.page_add,
                              "New File",
                              "Create a new quantum script",
                              () => EditorService().openFile("untitled.py", ""),
                            ),
                            _buildActionItem(
                              context,
                              FluentIcons.fabric_open_folder_horizontal,
                              "Open Folder",
                              "Open an existing project",
                              () => CommandService().execute("file.openFolder"),
                            ),
                            _buildActionItem(
                              context,
                              FluentIcons.test_beaker,
                              "Try Demo",
                              "See KET Studio in action",
                              () => EditorService().openFile(
                                "demo_visualizer.py",
                                DemoContent.demoScript,
                              ),
                              isHighlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      // Recent Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(FluentIcons.history, "RECENT"),
                            const SizedBox(height: 16),
                            Text(
                              "No recent projects yet.\nStart by creating a new file.",
                              style: TextStyle(
                                color: KetTheme.textMuted,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Templates Section
                  _buildSectionHeader(FluentIcons.library, "QUANTUM TEMPLATES"),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: TemplateService.templates.map((tpl) {
                      return _buildTemplateCard(tpl);
                    }).toList(),
                  ),

                  const SizedBox(height: 80),

                  // Footer
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildFooterLink(
                        "Learning Resources",
                        FluentIcons.reading_mode,
                      ),
                      const SizedBox(width: 24),
                      _buildFooterLink("Quantum Hardware", FluentIcons.iot),
                      const Spacer(),
                      Text(
                        "Alpha v1.0.0",
                        style: TextStyle(
                          color: KetTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: KetTheme.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: states.isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHighlight && !states.isHovered
                  ? Border.all(color: KetTheme.accent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isHighlight ? KetTheme.accent : KetTheme.textMuted,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isHighlight ? KetTheme.accent : Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: KetTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplateCard(QuantumTemplate tpl) {
    return HoverButton(
      onPressed: () => TemplateService.useTemplate(tpl),
      builder: (context, states) {
        return Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: states.isHovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: states.isHovered
                  ? KetTheme.accent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tpl.icon, size: 20, color: KetTheme.accent),
              const SizedBox(height: 8),
              Text(
                tpl.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tpl.description,
                style: TextStyle(color: KetTheme.textMuted, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterLink(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: KetTheme.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: KetTheme.textMuted,
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}
