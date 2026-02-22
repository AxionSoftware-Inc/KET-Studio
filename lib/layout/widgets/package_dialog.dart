import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/python_setup_service.dart';
import '../../core/theme/ket_theme.dart';

class PackageDialog extends StatelessWidget {
  const PackageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Row(
        children: [
          const Text("Python Package Manager"),
          const Spacer(),
          Tooltip(
            message: "Refresh versions",
            child: IconButton(
              icon: const Icon(FluentIcons.refresh, size: 14),
              onPressed: PythonSetupService().isBusy
                  ? null
                  : () => PythonSetupService().checkAndInstallDependencies(
                      force: true,
                    ),
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 500),
      content: ListenableBuilder(
        listenable: PythonSetupService(),
        builder: (context, _) {
          final setup = PythonSetupService();
          final allLibs = [...setup.coreLibraries, ...setup.optionalLibraries];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                setup.isBusy
                    ? "Operations in progress... Please wait."
                    : "Manage your quantum environment libraries and dependencies.",
                style: TextStyle(
                  fontSize: 12,
                  color: setup.isBusy ? KetTheme.accent : Colors.grey,
                  fontWeight: setup.isBusy
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: allLibs.map((lib) {
                      final name = lib.split('[').first;
                      final version = setup.packageVersions[name];
                      final isInstalled = version != null;
                      final isCurrentTask =
                          setup.currentTask.value?.contains(name) ?? false;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isCurrentTask)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: ProgressRing(strokeWidth: 2),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isInstalled
                                      ? FluentIcons.check_mark
                                      : FluentIcons.circle_addition,
                                  size: 12,
                                  color: isInstalled
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isInstalled
                                        ? "Version: $version"
                                        : (isCurrentTask
                                              ? "Installing..."
                                              : "Not installed"),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCurrentTask
                                          ? KetTheme.accent
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isInstalled && !isCurrentTask)
                              Button(
                                onPressed: setup.isBusy
                                    ? null
                                    : () => setup.installPackage(lib),
                                child: const Text("Install"),
                              )
                            else if (isCurrentTask)
                              const Text(
                                "Busy",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              Text(
                                "Ready",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        FilledButton(
          child: const Text("Close"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
