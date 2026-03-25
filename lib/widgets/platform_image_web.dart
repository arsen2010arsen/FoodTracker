import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Widget buildPlatformImage({
  required String imagePath,
  required Uint8List? imageBytes,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageBytes != null) {
    return Image.memory(imageBytes, fit: fit);
  }
  return Image.network(imagePath, fit: fit);
}
