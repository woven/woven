library util;

import '../shared/shared_util.dart' as sharedUtil;
import 'package:jwt/json_web_token.dart';

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

generateFirebaseToken(Map data) {
  // Encode (i.e. sign) a payload into a JWT token.
  final jwt = new JsonWebTokenCodec(secret: "o7SEeh3CLCqofPAZQOtFLeGdcmABhsOEpC3bUiYh");
  final payload = {
      'iss': 'woven',
      'exp': new DateTime.now().add(new Duration(days: 365)).millisecondsSinceEpoch,
      'v': 0,
      'iat': new DateTime.now().millisecondsSinceEpoch*1000,
      'd': data
  };
  final token = jwt.encode(payload);
  return token;
}