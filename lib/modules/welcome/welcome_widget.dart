import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/demo_content.dart';
import '../../core/services/command_service.dart';
import '../../core/services/editor_service.dart';
import '../../core/theme/ket_theme.dart';
import '../templates/templates_service.dart';

class WelcomeWidget extends StatelessWidget {
  const WelcomeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KetTheme.bgCanvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverview(),
                const SizedBox(height: 18),
                _buildQuickActions(),
                const SizedBox(height: 18),
                _buildTemplates(),
                const SizedBox(height: 18),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: KetTheme.panelSurface(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "KET STUDIO / CONTROL CENTER",
            style: KetTheme.headerStyle.copyWith(color: KetTheme.accent),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/quantum.jpg',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quantum analysis workspace",
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: KetTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DemoContent.welcomeSubtitle,
                      style: KetTheme.bodyStyle.copyWith(
                        color: KetTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _OverviewChip(
                title: "Scripts",
                value: "Python and quantum workflows",
              ),
              _OverviewChip(
                title: "Panels",
                value: "Inspector, metrics and history",
              ),
              _OverviewChip(
                title: "Execution",
                value: "Run locally and inspect output",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: KetTheme.panelSurface(elevated: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ACTIONS", style: KetTheme.headerStyle),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _ActionCard(
                      icon: FluentIcons.page_add,
                      title: "New file",
                      subtitle: "Start a fresh experiment or utility script.",
                      emphasis: true,
                      onTap: () => EditorService().openFile("untitled.py", ""),
                    ),
                    _ActionCard(
                      icon: FluentIcons.fabric_open_folder_horizontal,
                      title: "Open folder",
                      subtitle: "Load an existing workspace from disk.",
                      onTap: () => CommandService().execute("file.openFolder"),
                    ),
                    _ActionCard(
                      icon: FluentIcons.test_beaker,
                      title: "Try demo",
                      subtitle: "Open a prepared visualization sample.",
                      onTap: () => EditorService().openFile(
                        "demo_visualizer.py",
                        DemoContent.demoScript,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: KetTheme.panelSurface(elevated: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("WORKSPACE", style: KetTheme.headerStyle),
                const SizedBox(height: 14),
                const _InfoRow(
                  icon: FluentIcons.bulleted_list,
                  title: "Project state",
                  description:
                      "Recent items hali yo'q. Birinchi workspace yarating.",
                ),
                const SizedBox(height: 14),
                const _InfoRow(
                  icon: FluentIcons.processing,
                  title: "Visualization",
                  description:
                      "Run qiling va natijalarni inspector, charts va history panelda ko'ring.",
                ),
                const SizedBox(height: 14),
                const _InfoRow(
                  icon: FluentIcons.settings,
                  title: "Environment",
                  description:
                      "Python path va package management ichkaridan boshqariladi.",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplates() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: KetTheme.panelSurface(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("QUANTUM TEMPLATES", style: KetTheme.headerStyle),
          const SizedBox(height: 6),
          Text(
            "Start from curated examples instead of an empty editor.",
            style: KetTheme.descriptionStyle,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: TemplateService.templates.map((tpl) {
              return _TemplateCard(tpl: tpl);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Text("Learning Resources", style: KetTheme.descriptionStyle),
        const SizedBox(width: 22),
        Text("Quantum Hardware", style: KetTheme.descriptionStyle),
        const Spacer(),
        Text(
          "Alpha v1.0.0",
          style: KetTheme.descriptionStyle.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final String title;
  final String value;

  const _OverviewChip({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KetTheme.bgHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KetTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: KetTheme.headerStyle.copyWith(color: KetTheme.accent),
          ),
          const SizedBox(height: 4),
          Text(value, style: KetTheme.descriptionStyle),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasis;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: emphasis
                  ? KetTheme.accentSoft
                  : (states.isHovered ? KetTheme.bgHover : KetTheme.bgHeader),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: emphasis
                    ? KetTheme.accent.withValues(alpha: 0.28)
                    : KetTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: emphasis ? KetTheme.accent : KetTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: emphasis ? Colors.white : KetTheme.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KetTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: KetTheme.descriptionStyle),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: KetTheme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: KetTheme.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: KetTheme.descriptionStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final QuantumTemplate tpl;

  const _TemplateCard({required this.tpl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: HoverButton(
        onPressed: () => TemplateService.useTemplate(tpl),
        builder: (context, states) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: states.isHovered ? KetTheme.bgHover : KetTheme.bgHeader,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: states.isHovered
                    ? KetTheme.accent.withValues(alpha: 0.28)
                    : KetTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KetTheme.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(tpl.icon, size: 18, color: KetTheme.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  tpl.title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KetTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tpl.description,
                  style: KetTheme.descriptionStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
