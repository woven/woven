library date_formatter;

import 'dart:math';

/**
 * A useful utility class for formatting input.
 *
 * Can be used to e.g. strip away HTML.
 */
class InputFormatter {
  static List<String> weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static List<String> months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static List<RegExp> rules = [new RegExp('<img.*?src="(.*?)".*?>', caseSensitive: false), new RegExp('<object.*?</object>', caseSensitive: false), new RegExp('<video.*?</video>', caseSensitive: false), new RegExp('<iframe.*?</iframe>', caseSensitive: false)];

  /**
   * Formats a moment-based date.
   */
  static String formatMomentDate(DateTime date, {bool noText: false, bool short: false, bool momentsAgo: false, t}) {
    if (date == null) return '';

    var todayPrecise = new DateTime.now();

    var secondText = ' second';
    var minuteText = ' minute';
    var hourText = ' hour';
    var dayText = ' day';
    var monthText = ' month';
    var yearText = ' year';

    if (short) {
      secondText = 's';
      minuteText = 'm';
      hourText = 'h';
      dayText = 'd';
      yearText = 'y';
    }

    var ago = 'ago';
    if (t != null) ago = t('ago');

    // First check if the date time is close to current time.
    var diff = date.difference(todayPrecise);

    if (diff.inSeconds == 0 || diff.inSeconds.abs() < 60) {
      if (noText) return '0 seconds $ago';
      return 'Now';
    } else if (diff.inSeconds.abs() < 60) {
      var s = diff.inSeconds.abs() == 1 || short ? '' : 's';

      if (diff.inSeconds < 0) {
        if (momentsAgo) return 'Moments $ago';
        return '${-diff.inSeconds}$secondText$s $ago';
      } else {
        return 'in ${diff.inSeconds}$secondText$s';
      }
    } else if (diff.inMinutes.abs() < 60) {
      var s = diff.inMinutes.abs() == 1 || short ? '' : 's';

      if (diff.inMinutes < 0) return '${-diff.inMinutes}$minuteText$s $ago'; else return 'in ${diff.inMinutes}$minuteText$s';
    } else if (diff.inHours.abs() < 24) {
      var s = diff.inHours.abs() == 1 || short ? '' : 's';

      if (diff.inHours < 0) return '${-diff.inHours}$hourText$s $ago'; else return 'in ${diff.inHours}$hourText$s';
    } else if (diff.inDays.abs() < 365) {
      var s = diff.inDays.abs() == 1 || short ? '' : 's';

      if (diff.inDays < 0) return '${-diff.inDays}$dayText$s $ago'; else return 'in ${diff.inDays}$dayText$s';
    } else if (diff.inDays.abs() < 365) {
      var s = -diff.inDays ~/ 30 == 1 ? '' : 's';

      if (diff.inDays < 0) return '${-diff.inDays ~/ 30} month$s $ago'; else return 'in ${diff.inDays ~/ 30} month$s';
    } else {
      var s = diff.inDays.abs() < 365 * 2 || short ? '' : 's';

      if (diff.inDays < 0) return '${-diff.inDays ~/ 365} $yearText$s $ago'; else return 'in ${diff.inDays ~/ 365} $yearText$s';
    }
  }

  /**
   * Replaces newlines with breaklines.
   */
  static String nl2br(String content, {onlyIfHtml: false}) {
    if (content == null) return '';

    if (onlyIfHtml && content.allMatches('<p>').length == 0) return content;

    content = content.replaceAll('\\n', '\n');

    return content.replaceAll('\n', '<br />');
  }
}