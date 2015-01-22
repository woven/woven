library image_util;

import 'dart:io';
import 'dart:async';
import 'package:woven/config/config.dart';
import 'file_util.dart';

class ImageUtil {
  ImageUtil();

  Future<File> resize(File origFile, {int width, int height}) {
    return createTemporaryFile(prefix: "woven").then((File newFile) {
      var params = [origFile.path, "-resize", "$width", "-crop", "${width}x${height}+0+0", "+repage", "-extent", "${width}x${height}", newFile.path];
      return Process.run(config['imageMagick']['convert'], params).then((ProcessResult result) {
        return newFile;
      });
    });
  }
}