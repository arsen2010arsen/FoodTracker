import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Widget buildPlatformImage({
  required String imagePath,
  required Uint8List? imageBytes,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(File(imagePath), fit: fit);
}
