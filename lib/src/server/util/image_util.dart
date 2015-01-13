library image_util;

import 'dart:io';
import 'dart:async';
import 'package:woven/config/config.dart';
import 'file_util.dart';

class ImageUtil {
  ImageUtil();

  Future<File> resize(File origFile, size) {
    return createTemporaryFile(prefix: "woven").then((File newFile) {
      var params = [origFile.path, "-resize", size, "-gravity", "center", "-extent", size, newFile.path];
      return Process.run(config['imageMagick']['convert'], params).then((ProcessResult result) {
        return newFile;
      });
    });
  }
}