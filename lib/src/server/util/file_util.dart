library file_util;

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../shared/shared_util.dart' as sharedUtil;
import 'package:crypto/crypto.dart';
import '../util.dart';

/**
 * A simple utility function to download a remote file to a local filesystem path.
 *
 * This supports both HTTP and data URIs.
 */
Future<File> downloadFileTo(String url, File file) {
  return new Future(() {
    if (url.startsWith('http')) {
      return http.get(correctUrl(url)).then((response) {
        if (!isSuccessStatusCode(response.statusCode)) throw 'Status code ${response.statusCode} when downloading $url.';
        return file.writeAsBytes(response.bodyBytes);
      });
    } else if (url.startsWith('data:')) {
      // We support base64 encoded data URIs only, for now.
      var base64 = url.replaceFirst(new RegExp('data:.*?/.*?;base64,'), '');
      return file.writeAsBytes(CryptoUtils.base64StringToBytes(base64));
    } else {
      throw new ArgumentError('Could not download an invalid URI: $url');
    }
  });
}

Future<File> createTemporaryFile({String prefix: 'woven-'}) {
  return new Future(() {
    var name;

    Future retry() {
      name = '$prefix${new Random().nextInt(10000000)}';

      var file = new File(path.join(Directory.systemTemp.path, name));
      return file.exists().then((exists) {
        if (exists) return retry();

        return file.create();
      });
    }

    return retry();
  });
}