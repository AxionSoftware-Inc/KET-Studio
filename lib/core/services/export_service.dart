import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Exports metrics map to a CSV file
  Future<void> exportMetricsToCsv(Map<String, dynamic> metrics, {String? fileName}) async {
    try {
      final StringBuffer sb = StringBuffer();
      // Header
      sb.writeln("Metric,Value");
      
      // Rows
      metrics.forEach((key, value) {
        // Clean key and value for CSV (basic escaping)
        final k = key.toString().replaceAll('"', '""');
        final v = value.toString().replaceAll('"', '""');
        sb.writeln('"$k","$v"');
      });

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Metrics to CSV',
        fileName: fileName ?? 'quantum_metrics.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(sb.toString());
      }
    } catch (e) {
      debugPrint("Export CSV Error: $e");
    }
  }

  /// Captures a widget as an image and saves it
  Future<void> exportWidgetToImage(RenderRepaintBoundary boundary, {String? fileName}) async {
    try {
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Plot to Image',
        fileName: fileName ?? 'quantum_plot.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(pngBytes);
      }
    } catch (e) {
      debugPrint("Export Image Error: $e");
    }
  }
}
