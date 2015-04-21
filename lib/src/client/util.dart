library client_util;

import 'dart:html';
import 'package:intl/intl.dart';
import 'package:woven/config/config.dart';

/**
 * A helper method for reading a cookie.
 */
String readCookie(String name) {
  String nameEQ = '$name=';
  List<String> ca = document.cookie.split(';');
  for (int i = 0; i < ca.length; i++) {
    String c = ca[i];
    c = c.trim();
    if (c.indexOf(nameEQ) == 0) {
      return c.substring(nameEQ.length);
    }
  }
  return null;
}

/**
 * Creates a new cookie.
 */
void createCookie(String name, String value, {int days: 365}) {
  if (days == null) days = 365;

  DateTime dateToExpire = new DateTime.now().add(new Duration(days: days)).toUtc();
  var formatter = new DateFormat('EEE, dd MMM yyyy hh:mm:ss');
  String expires = formatter.format(dateToExpire) + ' GMT';

  document.cookie = '$name=$value;expires=$expires;path=/;domain=.${config['server']['domain']}';
}

void deleteCookie(String name) {
  createCookie(name, '', days: -1);
}