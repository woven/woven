library shared_util;

import 'package:crypto/crypto.dart';
import 'dart:convert';

String htmlDecode(String text) {
  if (text == null) {
    return '';
  }

  return text.replaceAll("&amp;", "&")
  .replaceAll("&lt;", "<")
  .replaceAll("&gt;", ">")
  .replaceAll("&quot;", '"')
  .replaceAll("&apos;", "'")
  .replaceAllMapped(new RegExp('&#([0-9]+);'), (Match match) {
    try {
      var value = int.parse(match.group(1));
      var character = new String.fromCharCode(value);

      return character;
    } catch (e) {
      return '';
    }
  }).replaceAllMapped(new RegExp('&#x([a-f0-9]+);'), (Match match) {
    try {
      var value = int.parse(match.group(1), radix: 16);
      var character = new String.fromCharCode(value);

      return character;
    } catch (e) {
      return '';
    }
  });
}

/**
 * Parses a date into a DateTime object.
 */
parseDate(String date) {
  var parts = date.split('/');
  if (parts.length != 3) return null;
  if (parts[2].length != 4) return null;
  try {
    DateTime parsedDate = new DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
    return parsedDate;
  } catch (e) {
    return null;
  }
}

/**
 * Parses a time into a DateTime object.
 */
parseTime(String time) {
  var parts;

  if (time.contains(':')) parts = time.split(':');
  else if (time.contains('.')) parts = time.split('.');
  else parts = [time];

  // Hour only.
  var hour = int.parse(parts[0].replaceAll(new RegExp('[^0-9]'), ''), onError: (s) => 0);

  var minute = -1;
  if (parts.length > 1) minute = int.parse(parts[1].replaceAll(new RegExp('[^0-9]'), ''), onError: (s) => 0);
  if (parts.length == 1) minute = 0;

  String lastPart = parts.length > 1 ? parts[1] : parts[0];

  var isAm = lastPart.toLowerCase().contains('am');
  var isPm = lastPart.toLowerCase().contains('pm');

  if (isPm) {
    if (hour < 12) hour += 12;
    else hour = 12;
  }
  if (isAm && hour > 11) hour -= 12;

  if (hour > 23) return null;
  if (hour < 0) return null;
  if (minute < 0) return null;
  if (minute > 59) return null;

  // Get the current time just so we can create a full datetime from the time.
  DateTime now = new DateTime.now();

  try {
    DateTime parsedTime = new DateTime(now.year, now.month, now.day, hour, minute);
    return parsedTime;
  } catch (e) {
    return null;
  }
}

/**
 * Hash some string, e.g. for an item ID in a URL.
 */
hashEncode(String text) {
  var encodedText = CryptoUtils.bytesToBase64(UTF8.encode(text));
  return encodedText;
}

/**
 * Decode a hashed string, e.g. an item ID in a URL.
 */
hashDecode(String encodedText) {
  var base64 = encodedText;
  var bytes = CryptoUtils.base64StringToBytes(base64);
  var decodedText = UTF8.decode(bytes);
  return decodedText;
}

/**
 * Handle possessives nicely.
 *
 * James' beer, not James's beer.
 */

formatPossessive(String text) {
  if (text == null) return false;

  if (text.endsWith("s")) {
    return '$text\'';
  } else {
    return '$text\'s';
  }
}