import 'dart:async';

import 'package:http/http.dart' as http;

import '../util.dart';

class ImageInfo {
  String url;
  String type;
  String filename;
  String extension;
  int size;
  bool tooSmall = false;

  static const MINIMUM_IMAGE_SIZE = 2000;

//  Map imageSizes = {};

  static Future<ImageInfo> parse(String url) async {
    var imageInfo = new ImageInfo();
    var size;

    var head = await http.head(url);
    if (head.headers['content-length'] == null) {
      // See if we get content-length with a GET.
      var get = await http.get(url);
      if (get.headers['content-length'] == null) {
        size = get.body.length;
      } else {
        size = get.headers['content-length'];
      }
    } else {
      size = head.headers['content-length'];
    }

    size = int.parse(size, onError: (_) => 0);

    Uri uri = Uri.parse(url);
    var filename = uri.path.split('/').last.toString();
    var filenameParts = filename.split('.');
    var extension;

    if (filenameParts.length > 1) {
      extension = filenameParts.last.toString();
    } else {
      var contentType = head.headers['content-type'];
      extension = getImageExtensionFromContentType(contentType);
      filename = filename + '.' + extension;
    }

    imageInfo
      ..url = url
      ..tooSmall = size <= MINIMUM_IMAGE_SIZE
      ..type = head.headers['content-type']
      ..filename = filename
      ..extension = extension
      ..size = size;

    return imageInfo;
  }
}
