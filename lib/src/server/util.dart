library util;

import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../shared/shared_util.dart' as sharedUtil;
import 'package:crypto/crypto.dart';

/**
 * Returns true if the given status code was "success".
 */
bool isSuccessStatusCode(int statusCode) => statusCode >= 200 && statusCode < 300 || statusCode == 304;

/**
 * A simple utility function to download a remote file to a local filesystem path.
 *
 * This supports both HTTP and data URIs.
 */
Future downloadFileTo(String url, String sourcePath) {
  return new Future(() {
    if (url.startsWith('http')) {
      return http.get(correctUrl(url)).then((response) {
        if (!isSuccessStatusCode(response.statusCode)) throw 'Status code ${response.statusCode} when downloading $url.';

        return new Directory(path.dirname(sourcePath)).create(recursive: true).then((_) {
          return new File(sourcePath).writeAsBytes(response.bodyBytes);
        });
      });
    } else if (url.startsWith('data:')) {
      // We support base64 encoded data URIs only, for now.
      var base64 = url.replaceFirst(new RegExp('data:.*?/.*?;base64,'), '');
      return new File(sourcePath).writeAsBytes(CryptoUtils.base64StringToBytes(base64));
    } else {
      throw new ArgumentError('Could not download an invalid URI: $url');
    }
  });
}

/**
 * In some cases we need to convert a space to %20 to make things work.
 */
String correctUrl(String url) {
  if (url == null) return '';

  url = url.replaceAll(' ', '%20');
  url = sharedUtil.htmlDecode(url);

  return url;
}

