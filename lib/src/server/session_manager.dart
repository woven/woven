library session_manager;

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'firebase.dart';
import 'package:woven/config/config.dart';
import 'package:crypto/crypto.dart';

/**
 * A generic session manager that works with HTTP and WebSocket requests.
 *
 * The built-in HttpSession only works with HTTP.
 */
class SessionManager {
  /**
   * Adds a session cookie to this request.
   */
  addSessionCookieToRequest(HttpRequest request, String sessionId) {
    var domain = config['server']['domain'];
    try {
      domain = request.headers['host'].first;
    } catch (e) {}

    var cookie = new Cookie('session', sessionId);
    // Set the expire date to a year from now.
    DateTime now = new DateTime.now();
    DateTime expireDate =  now.add(new Duration(days: 365));

    cookie.expires = expireDate;
    cookie.path = '/';
    cookie.domain = '.$domain';
    cookie.httpOnly = true;
    request.response.cookies.add(cookie);
  }

  deleteCookie(HttpRequest request) {
    var domain = config['server']['domain'];
    try {
      domain = request.headers['host'].first;
    } catch (e) {}

    var cookie = new Cookie('session', '');
    // Set the expire date to yesterday so we kill our cookie.
    DateTime now = new DateTime.now();
    DateTime expireDate =  now.add(new Duration(days: -1));

    cookie.expires = expireDate;
    cookie.path = '/';
    cookie.domain = '.${domain.replaceFirst('www.', '')}';
    cookie.httpOnly = true;
    request.response.cookies.add(cookie);
  }

  /**
   * Add the session id to the session_index.
   */
  Future addSessionToIndex(String session, String username, String authToken) {
    DateTime now = new DateTime.now().toUtc();
    var sessionData = {
        'username': username,
        'updatedDate': now.toString(),
        '.priority': -now.millisecondsSinceEpoch};
    return Firebase.put('/session_index/$session.json', sessionData, authToken);
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
}