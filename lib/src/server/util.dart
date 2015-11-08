library util;

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../shared/util.dart' as sharedUtil;

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

/**
 * A utility method that reads HTTP response body and returns it as a string.
 *
 * The difference to http.read() is: send good headers, handle encodings better and have a timeout.
 */
Future<String> readHttp(String url, {bool requestAsChrome: false}) {
  var completer = new Completer();

  // Act like any normal browser.
  var headers = {
    'Accept-Language': 'en-US,en;q=0.8',
    'Accept-Encoding': 'gzip,deflate',
    //'Accept': 'text/html,application/xhtml+xml,application/xml',
  };

  // Masquerades as a browser so we can crawl... blame on Facebook.
  if (requestAsChrome || url.contains('facebook.com')) {
    headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.101 Safari/537.36';
  }

  var timer = new Timer(new Duration(seconds: 8), () {
    if (completer.isCompleted == false) completer.completeError('Timed out reading URL $url');
  });

  if (url == null) {
    completer.completeError('Empty URL.');
  }

  headers['host'] = Uri.parse(url).host;

  // Handle letter cases. Lower-casify the hostname, but not anything else.
  url = url.replaceFirst(Uri.parse(url).host, Uri.parse(url).host.toLowerCase());

  http.get(url, headers: headers).then((response) {
    if (completer.isCompleted == false) {
      timer.cancel();

      if ((response.statusCode < 200 || response.statusCode >= 300) && response.statusCode != 304) {
        completer.completeError('Website returned status code ${response.statusCode}');
        return;
      }

      var contentType = response.headers[HttpHeaders.CONTENT_TYPE];
      if (contentType == null) contentType = response.headers[HttpHeaders.CONTENT_TYPE.toLowerCase()];

      var charset;
      if (contentType != null) {
        charset = ContentType.parse(contentType).charset;
      } else {
        charset = 'utf-8';
      }

      var c = '';

      if (charset == null || charset.toLowerCase() == 'utf-8') {
        try {
          c = UTF8.decode(response.bodyBytes);
        } catch (e) {
          c = new String.fromCharCodes(response.bodyBytes);
        }
      } else {
        c = new String.fromCharCodes(response.bodyBytes);
      }

      completer.complete(c);
    }
  }).catchError((e) {
    print('Error reading website contents $url: $e');

    if (completer.isCompleted == false) {
      timer.cancel();
      completer.complete(null);
    }
  });

  return completer.future;
}

