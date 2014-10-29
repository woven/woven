library session_manager;

import 'dart:io';
import 'package:woven/config/config.dart';

/**
 * A generic session manager that works with HTTP and WebSocket requests.
 *
 * The built-in HttpSession only works with HTTP.
 */
class SessionManager {
  /**
   * Adds a session cookie to this request.
   */
  addSessionCookieToRequest(HttpRequest request, HttpSession session) {
    var domain = config['server']['domain'];
    try {
      domain = request.headers['host'].first;
    } catch (e) {}

    var cookie = new Cookie('session', session['id']);
    // Set the expire date to a year from now.
    DateTime now = new DateTime.now();
    DateTime expireDate =  now.add(new Duration(days: 365));

    cookie.expires = expireDate;
    cookie.path = '/';
    cookie.domain = '.${domain.replaceFirst('www.', '')}';
    request.response.cookies.add(cookie);
  }
}