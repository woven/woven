library image_util;

import 'dart:async';
import 'dart:io';

import 'package:image/image.dart';
import 'package:logging/logging.dart';

import 'file_util.dart';

class ImageUtil {
  final Logger logger = new Logger('ImageUtil');

  ImageUtil();

  Future<File> resize(File origFile, {int width, int height}) async {
    logger.fine('Resizing ${origFile.path}');

    Image image = decodeImage(await origFile.readAsBytes());

    var originalAspectRatio = image.width / image.height;
    var targetAspectRatio = width / height;

    if (originalAspectRatio < targetAspectRatio) {
      // Too narrow
      image = copyCrop(
          image, 0, 0, image.width, (image.width / targetAspectRatio).floor());
    } else {
      // Too wide
      image = copyCrop(image, 0, 0, (image.height * targetAspectRatio).floor(),
          image.height);
    }

    Image thumbnail = copyResize(image, width, height);

    File newFile = await createTemporaryFile(prefix: "woven");

    await newFile.writeAsBytes(encodeNamedImage(thumbnail, origFile.path));

    logger.fine('Successfully resized ${origFile.path}');

    return newFile;
  }
}
