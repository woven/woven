library util;

import '../shared/shared_util.dart' as sharedUtil;
import 'package:shelf/shelf.dart' as shelf;
import 'dart:convert';


/**
 * Returns true if the given status code was "success".
 */
bool isSuccessStatusCode(int statusCode) => statusCode >= 200 && statusCode < 300 || statusCode == 304;

/**
 * In some cases we need to convert a space to %20 to make things work.
 */
String correctUrl(String url) {
  if (url == null) return '';

  url = url.replaceAll(' ', '%20');
  url = sharedUtil.htmlDecode(url);

  return url;
}

shelf.Response respond(content, {statusCode: 200}) {
  return new shelf.Response(statusCode, body: JSON.encode(content));
}