import 'package:fluent_ui/fluent_ui.dart';
import '../../core/theme/ket_theme.dart';
import 'dart:math' as math;
import '../../shared/widgets/quantum_bloch_sphere.dart';

class InspectorWidget extends StatefulWidget {
  final dynamic payload;
  const InspectorWidget({super.key, required this.payload});

  @override
  State<InspectorWidget> createState() => _InspectorWidgetState();
}

class _InspectorWidgetState extends State<InspectorWidget> {
  int _currentFrame = 0;

  @override
  Widget build(BuildContext context) {
    final frames = widget.payload['frames'] as List<dynamic>? ?? [];
    if (frames.isEmpty) return const Center(child: Text("No inspector data"));

    final frame = frames[_currentFrame];
    final title = widget.payload['title'] ?? "Circuit Inspector";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.reading_mode, size: 16, color: KetTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: KetTheme.headerStyle.copyWith(letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: KetTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${_currentFrame + 1}/${frames.length}",
                  style: TextStyle(
                    color: KetTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.cube_shape,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            frame['gate'] ?? "Operation",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        frame['state_description'] ??
                            "No description provided for this step.",
                        style: TextStyle(
                          color: KetTheme.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "STATE VISUALIZATION",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: KetTheme.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Qubit States (Adaptive Layout)
                Center(
                  child: Builder(
                    builder: (context) {
                      final blochList = (frame['bloch'] as List<dynamic>? ?? []);
                      final count = blochList.length;
                      
                      // Adaptive size and limit
                      double size = 120;
                      int limit = 20;
                      
                      if (count <= 4) {
                        size = 150;
                        limit = 4;
                      } else if (count <= 12) {
                        size = 100;
                        limit = 12;
                      } else if (count <= 32) {
                        size = 80;
                        limit = 32;
                      } else {
                        size = 60;
                        limit = 64; // Performance guard
                      }

                      final displayList = blochList.take(limit).toList();
                      final isTruncated = blochList.length > limit;

                      return Column(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: displayList.asMap().entries.map((entry) {
                              final theta = (entry.value['theta'] ?? 0.0).toDouble();
                              final phi = (entry.value['phi'] ?? 0.0).toDouble();
                              
                              return _AdaptiveBlochCard(
                                index: entry.key,
                                theta: theta,
                                phi: phi,
                                size: size,
                              );
                            }).toList(),
                          ),
                          if (isTruncated)
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "⚠️ Showing $limit of ${blochList.length} qubits. High-qubit simulation view is optimized for performance.",
                                  style: TextStyle(fontSize: 10, color: Colors.orange),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KetTheme.bgHeader,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.chevron_left_med, size: 14),
                onPressed: _currentFrame > 0
                    ? () => setState(() => _currentFrame--)
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Slider(
                    value: _currentFrame.toDouble(),
                    min: 0,
                    max: math.max(0, frames.length - 1).toDouble(),
                    onChanged: (v) => setState(() => _currentFrame = v.toInt()),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.chevron_right_med, size: 14),
                onPressed: _currentFrame < frames.length - 1
                    ? () => setState(() => _currentFrame++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlochSphere(int index, dynamic data) {
    // This is now handled by the adaptive builder above
    return const SizedBox.shrink();
  }
}

class _AdaptiveBlochCard extends StatelessWidget {
  final int index;
  final double theta;
  final double phi;
  final double size;

  const _AdaptiveBlochCard({
    required this.index,
    required this.theta,
    required this.phi,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (size > 70) 
          Text(
            "q[$index]",
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: size > 100 ? 11 : 9, 
              color: KetTheme.textMuted
            ),
          ),
        const SizedBox(height: 4),
        InteractiveBlochSphere(
          index: index,
          theta: theta,
          phi: phi,
          size: size,
        ),
      ],
    );
  }
}

