import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_jam/ui/urban_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => UrbanAssets.instance.load());

  test(
    'Approved sprites decode with transparent margins and visible artwork',
    () async {
      for (final name in UrbanAssets.paths.keys.where(
        (name) => name != 'city',
      )) {
        final image = UrbanAssets.instance.image(name);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        // Transparent corners prevent a sheet cell/background rectangle appearing
        // behind a bus, passenger, wordmark or result illustration on the board.
        for (final pixel in [
          0,
          image.width - 1,
          image.width * (image.height - 1),
          image.width * image.height - 1,
        ]) {
          expect(
            bytes[pixel * 4 + 3],
            0,
            reason: '$name has a background corner',
          );
        }
        var visible = 0;
        for (int i = 3; i < bytes.length; i += 4) {
          if (bytes[i] > 200) visible++;
        }
        expect(
          visible / (image.width * image.height),
          greaterThan(.2),
          reason: '$name is blank or clipped',
        );
      }
    },
  );

  test(
    'Six bus/person pairs retain adult upright proportions at mobile scale',
    () {
      for (final color in UrbanAssets.colors) {
        final bus = UrbanAssets.instance.image('bus-$color');
        final person = UrbanAssets.instance.image('person-$color');
        expect(bus.height / bus.width, inInclusiveRange(1.5, 1.9));
        expect(person.height / person.width, inInclusiveRange(2.2, 3.0));
      }
      final logo = UrbanAssets.instance.image('wordmark');
      expect(logo.width / logo.height, greaterThan(4.8));
    },
  );
}
