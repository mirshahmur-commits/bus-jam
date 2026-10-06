import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decoded once before the first frame. Painters never decode assets mid-move.
class UrbanAssets {
  UrbanAssets._();
  static final instance = UrbanAssets._();
  static const colors = ['coral', 'blue', 'gold', 'mint', 'violet', 'rose'];
  static final paths = {
    for (final color in colors) 'bus-$color': 'assets/art/urban/bus-$color.png',
    for (final color in colors)
      'person-$color': 'assets/art/urban/person-$color.png',
    'city': 'assets/art/urban/city.png',
    'win': 'assets/art/urban/win.png',
    'fail': 'assets/art/urban/fail.png',
    'wordmark': 'assets/branding/wordmark.png',
  };
  final _images = <String, ui.Image>{};
  Future<void>? _loading;
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    await Future.wait(
      paths.entries.map((entry) async {
        final bytes = await rootBundle.load(entry.value);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          _images[entry.key] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }),
    );
  }

  ui.Image image(String name) => _images[name]!;

  void paint(
    Canvas canvas,
    Rect rect,
    String name, {
    BoxFit fit = BoxFit.contain,
  }) {
    paintImage(
      canvas: canvas,
      rect: rect,
      image: image(name),
      fit: fit,
      filterQuality: FilterQuality.medium,
    );
  }
}

class UrbanArtwork extends StatelessWidget {
  const UrbanArtwork(this.name, {super.key, this.label});
  final String name;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: RawImage(
      image: UrbanAssets.instance.image(name),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}
