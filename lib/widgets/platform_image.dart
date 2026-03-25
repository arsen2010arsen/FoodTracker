import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'platform_image_io.dart'
    if (dart.library.html) 'platform_image_web.dart' as impl;

Widget buildPlatformImage({
  required String imagePath,
  required Uint8List? imageBytes,
  BoxFit fit = BoxFit.cover,
}) {
  return impl.buildPlatformImage(
    imagePath: imagePath,
    imageBytes: imageBytes,
    fit: fit,
  );
}
