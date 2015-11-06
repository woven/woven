library util;

import 'dart:convert';
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;
import 'package:intl/intl.dart';

import '../shared/shared_util.dart' as sharedUtil;

/**
 * Returns true if the given status code was "success".
 */
bool isSuccessStatusCode(int statusCode) =>
    statusCode >= 200 && statusCode < 300 || statusCode == 304;

/**
 * In some cases we need to convert a space to %20 to make things work.
 */
String correctUrl(String url) {
  if (url == null) return '';

  url = url.replaceAll(' ', '%20');
  url = sharedUtil.htmlDecode(url);

  return url;
}

/**
 * Adds HTTP if no protocol found.
 */
String prefixHttp(String text) {
  if (text == null) return '';

  if (text.startsWith('http') == false) {
    return 'http://$text';
  }

  return text;
}

/**
 * Adds a prefix to the string if it's not already there.
 */
String prefix(String text, String prefix) =>
    text.startsWith(prefix) ? text : "$prefix$text";

/**
 * Adds a postfix to the string if it's not already there.
 */
String postfix(String text, String postfix) =>
    text.endsWith(postfix) ? text : "$text$postfix";

shelf.Response respond(content, {statusCode: 200}) {
  return new shelf.Response(statusCode, body: JSON.encode(content));
}

/**
 * Parses a date into a DateTime object.
 */
Future<DateTime> parseDate(String dateString) {
  return new Future(() {
    if (dateString == null) return null;

    if (int.parse(dateString, onError: (s) => null) != null) {
      var v = int.parse(dateString) * 1000;
      return new DateTime.fromMillisecondsSinceEpoch(v);
    }

    var formats = [
      new DateFormat('EEE, d MMM yyyy HH:mm:ss Z'), // "Tue, 12 Feb 2013 16:27:30 EST"
      new DateFormat('d MMM yyyy HH:mm:ss Z'), // "08 Feb 2013 15:15:03 +0200"
      new DateFormat('yyyy-MM-ddTHH:mm:ssZ')
    ];

    for (var i = 0, length = formats.length; i < length; i++) {
      try {
        DateTime date = formats[i].parse(dateString);

        var m = new RegExp('(\\+|-)([0-9]){4}\$').firstMatch(dateString);
        if (m != null) {
          date = date.add(new Duration(minutes: timeZoneOffsetToMinutes(m.group(0))));
        } else {
          date = date.add(date.timeZoneOffset);
        }

        return date;
      } catch (e) {
        print(e);
      }
    }

    // Try generic.
    try {
      var date = DateTime.parse(dateString);

      date = date.add(date.timeZoneOffset);

      return date;
    } catch (e) {}

    return null;
  });
}

// Timezone offset cache.
var timeZoneOffsets = {};

DateTime parseUtc(String date, {int minutes: 0}) {
  var r = DateTime.parse(date);
  return new DateTime.utc(r.year, r.month, r.day, r.hour, r.minute + minutes, r.second);
}

int timeZoneOffsetToMinutes(String offset) {
  var add = offset.substring(0, 1) == '+';

  offset = offset.substring(1);

  if (offset.length == 4) {
    var hours = int.parse(offset.substring(0, 2)) * (add ? -1 : 1);
    var minutes = int.parse(offset.substring(2, 4)) * (add ? -1 : 1);

    return minutes + hours * 60;
  } else {
    var hours = int.parse(offset.substring(0, 2)) * (add ? -1 : 1);

    return hours * 60;
  }

  return 0;
}

