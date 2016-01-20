library session_manager;

import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:jwt/json_web_token.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'firebase.dart';
import 'package:woven/config/config.dart';

/**
 * A generic session manager that works with HTTP and WebSocket requests.
 *
 * The built-in HttpSession only works with HTTP.
 */

/**
 * Adds a session cookie to this response.
 */
Map<String, String> getSessionHeaders(String sessionId) {
  var domain = config['server']['domain'];

  var cookie = new Cookie('session', sessionId);
  // Set the expire date to a year from now.
  DateTime now = new DateTime.now();
  DateTime expireDate = now.add(new Duration(days: 365));

  cookie.expires = expireDate;
  cookie.path = '/';
  cookie.domain = '.$domain';
  cookie.httpOnly = true;

  return {'set-cookie': cookie.toString()};
}

Map<String, String> deleteCookie() {
  var domain = config['server']['domain'];

  var cookie = new Cookie('session', '');
  // Set the expire date to yesterday so we kill our cookie.
  DateTime now = new DateTime.now();
  DateTime expireDate = now.add(new Duration(days: -1));

  cookie.expires = expireDate;
  cookie.path = '/';
  cookie.domain = '.${domain.replaceFirst('www.', '')}';
  cookie.httpOnly = true;

  return {'set-cookie': cookie.toString()};
}

Cookie getSessionCookie(shelf.Request request) {
  print(request.headers);
  Map<String, Cookie> cookies = _parseCookies(request.headers);
  return cookies['session'];
}

// From https://github.com/wstrange/shelf_simple_session/blob/master/lib/src/cookie.dart.
Map<String, Cookie> _parseCookies(Map<String, String> headers) {
  // Parse a Cookie header value according to the rules in RFC 6265.
  var cookies = new Map<String, Cookie>();

  void parseCookieString(String s) {
    int index = 0;

    bool done() => index == -1 || index == s.length;

    void skipWS() {
      while (!done()) {
        if (s[index] != " " && s[index] != "\t") return;
        index++;
      }
    }

    String parseName() {
      int start = index;
      while (!done()) {
        if (s[index] == " " || s[index] == "\t" || s[index] == "=") break;
        index++;
      }
      return s.substring(start, index);
    }

    String parseValue() {
      int start = index;
      while (!done()) {
        if (s[index] == " " || s[index] == "\t" || s[index] == ";") break;
        index++;
      }
      return s.substring(start, index);
    }

    bool expect(String expected) {
      if (done()) return false;
      if (s[index] != expected) return false;
      index++;
      return true;
    }

    while (!done()) {
      skipWS();
      if (done()) return;
      String name = parseName();
      skipWS();
      if (!expect("=")) {
        index = s.indexOf(';', index);
        continue;
      }
      skipWS();
      String value = parseValue();
      try {
        cookies[name] = new Cookie(name, value);
      } catch (_) {
        // Skip it, invalid cookie data.
      }
      skipWS();
      if (done()) return;
      if (!expect(";")) {
        index = s.indexOf(';', index);
        continue;
      }
    }
  }

  var c = headers[HttpHeaders.COOKIE];
  if (c != null) parseCookieString(c);

  return cookies;
}

/**
 * Add the session id to the session_index.
 *
 * TODO: Allow for signed out sessions too, i.e. username optional?
 */
Future addSessionToIndex(String session, String username) {
  var authToken = generateFirebaseToken({'uid': username});
  DateTime now = new DateTime.now().toUtc();
  var sessionData = {
    'username': username,
    'updatedDate': now.toString(),
    'authToken': authToken,
    '.priority': -now.millisecondsSinceEpoch
  };
  return Firebase
      .put('/session_index/$session.json', sessionData, auth: authToken)
      .then((_) {
    return sessionData;
  });
}

/**
 * Generate a unique id for the session using best practices.
 */
String createSessionId() {
  var _random = new Random();
  const int _KEY_LENGTH = 16; // 128 bits.
  var data = new List<int>(_KEY_LENGTH);
  for (int i = 0; i < _KEY_LENGTH; ++i) data[i] = _random.nextInt(256);

  return CryptoUtils.bytesToHex(data);
}

/**
 * Finds the authentication token for a given session id.
 */
Future findFirebaseTokenForSession(String session) {
  return Firebase.get('/session_index/$session.json').then((sessionData) {
    return sessionData['authToken'];
  });
}

/**
 * Generates a new Firebase authentication token.
 */
String generateFirebaseToken(Map data) {
  // Encode (i.e. sign) a payload into a JWT token.
  final jwt =
      new JsonWebTokenCodec(secret: config['datastore']['firebaseSecret']);
  final payload = {
    'iss': 'woven',
    'exp': new DateTime.now()
        .add(new Duration(days: 365))
        .millisecondsSinceEpoch,
    'v': 0,
    'iat': new DateTime.now().millisecondsSinceEpoch * 1000,
    'd': data,
  };
  final token = jwt.encode(payload);
  return token;
}
