import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
          final folder = Directory('test-results/ios-screens');
          await folder.create(recursive: true);
          await File('${folder.path}/$name.png').writeAsBytes(image);
          return image.isNotEmpty;
        },
    responseDataCallback: (data) async {
      await Directory('test-results').create(recursive: true);
      final summary = Map<String, dynamic>.from(data ?? {});
      final screenshots = summary['screenshots'] as List<dynamic>? ?? [];
      summary['screenshots'] = screenshots.map((image) {
        final shot = image as Map<String, dynamic>;
        return {
          'name': shot['screenshotName'],
          'bytes': (shot['bytes'] as List<dynamic>).length,
        };
      }).toList();
      await File(
        'test-results/ios-uat.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
    },
  );
}
