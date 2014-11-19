library date_formatter;

import 'dart:math';
import 'package:intl/intl.dart';
import 'date_group.dart';
import 'regex.dart';
import 'shared_util.dart' as sharedUtil;

/**
 * A useful utility class for formatting input.
 *
 * Can be used to e.g. strip away HTML.
 */
class InputFormatter {
  static List<String> weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static List<String> months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static List<RegExp> rules = [new RegExp('<img.*?src="(.*?)".*?>', caseSensitive: false), new RegExp('<object.*?</object>', caseSensitive: false), new RegExp('<video.*?</video>', caseSensitive: false), new RegExp('<iframe.*?</iframe>', caseSensitive: false)];

  static DateFormat timeFormatter = new DateFormat('ha');
  static DateFormat timeFormatterSpaced = new DateFormat('h a');
  static DateFormat shortMonthFormatter = new DateFormat('MMM');
  static DateFormat shortDayFormatter = new DateFormat('EE');

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

  static String linkify(String content, {bool noExternalIcon: false, bool absolute: true}) {
    if (content == null) content = '';

    content = content.replaceAllMapped(new RegExp(RegexHelper.linkOrEmail), (Match match) {
      var address = match.group(0);
      var label = match.group(0);

      var isEmail = address.contains('@') && !address.contains('://');
      if (!isEmail && absolute && address.startsWith('http') == false) address = 'http://$address';
      if (isEmail && absolute && address.startsWith('mailto:') == false) address = ' mailto:$address';

      return '<a href="$address" target="_blank" class="${noExternalIcon ? 'no-icon' : ''}">$label</a>';
    });

    return content;
  }

  /**
   * Formats event's "when" field.
   */
  static String formatEventWhen(DateTime startDate, DateTime endDate) {
    if (startDate == null) return 'Not specified';

    var now = new DateTime.now();

    if (now.compareTo(startDate) < 0) {
      return 'When';
    } else if (endDate != null && now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
      return 'Happening';
    } else {
      return 'Happened';
    }
  }

  static String formatDate(DateTime date, {
  DateTime endDate,
  direction: 'future',
  hideHappened: false,
  hideTime: false,
  bool showTime: false,
  hideMonth: false,
  detailed: false,
  useStaticDate: false,
  hideDay: false,
  compactDay: false,
  trimPast: false,
  expandPast: false,
  int timeZoneOffset,
  bool showHappenedPrefix: false,
  Function t
  }) {
    if (date == null) return '';

    if (endDate != null && endDate.compareTo(date) <= 0) endDate = null;

    var now = new DateTime.now();

    // If a timezone is specified, move everything including 'now'.
    if (timeZoneOffset != null) {
      date = date.add(new Duration(minutes: timeZoneOffset * 60));
      now = now.add(new Duration(minutes: timeZoneOffset * 60));
      if (endDate != null) {
        endDate = endDate.add(new Duration(minutes: timeZoneOffset * 60));
      }
    }

    // Some initialization first.
    var today = new DateTime(now.year, now.month, now.day);
    var tomorrow = DateTime.parse(today.toString()).add(const Duration(days: 1));
    var yesterday = DateTime.parse(today.toString()).subtract(const Duration(days: 1));
    var monthAgo = DateTime.parse(today.toString()).subtract(const Duration(days: 30));
    var yearAgo = DateTime.parse(today.toString()).subtract(const Duration(days: 365));

    var dayPart = '', monthPart = '', timePart;

    // Create first part.
    if (date.year == today.year && date.month == today.month && date.day == today.day) dayPart = 'Today';
    else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) dayPart = 'Yesterday';
    else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) dayPart = 'Tomorrow';
      else if (compactDay == false) dayPart = weekdays[date.weekday];

    if (t != null) dayPart = t(dayPart);

    if (useStaticDate) dayPart = '$dayPart, ';

    // Create month part.
    var groupName = DateGroup.getDateGroupName(date, forward: endDate != null);
    if (useStaticDate || (groupName != 'Today' && groupName != 'Yesterday' && groupName != 'Tomorrow')) {
      var postfix = getDayPostfix(date.day);

      monthPart = ' ${months[date.month - 1]} ${date.day}$postfix';
    }

    // Create time part.
    var hour = date.hour;
    var postfix = 'am';
    if (date.hour > 11) {
      hour -= 12;
      postfix = 'pm';
    }

    if (hour == 0) hour = 12;

    timePart = '$hour';
    if (date.minute > 0) {
      var min = date.minute;
      if (min.toString().length == 1) min = '0$min';
      timePart = '$timePart:$min';
    }

    var timeZonePart = '';
    timePart = ', $timePart$postfix$timeZonePart';

    // Hide time if it's 00:00
    if (date.hour == 0 && date.minute == 0 && (endDate == null || (endDate != null && endDate.hour == 00 && endDate.minute == 0))) hideTime = true;

    // Hide time if it's in the past and we want to trimPast.
    if (trimPast) {
      if (date.compareTo(monthAgo) < 0 && !showTime) {
        hideTime = true;
      }

      if (date.compareTo(yearAgo) < 0) {
        hideMonth = true;
      }
    }

    var extra = '', showEndTime = false, addEndTime = false;

    // Events happening now.
    if (endDate != null && now.compareTo(date) >= 0 && now.compareTo(endDate) < 1) {
      extra = 'Happening now';
      if (t != null) extra = t(extra);
      hideDay = true;
      hideMonth = true;
      addEndTime = true;
      showEndTime = true;

      // If multi-day, hide time.
      if (endDate.difference(date).inHours.abs() > 24) {
        hideTime = true;
        hideDay = false;
        dayPart = ' ${weekdays[date.weekday].substring(0, 3)}-${weekdays[endDate.weekday].substring(0, 3)}';
      }
    }

    // Events happened today.
    if (endDate != null && now.compareTo(date) == 1 && now.compareTo(endDate) == 1 && tomorrow.compareTo(endDate) == 1) {
      var formatter = new DateFormat('MMMM d');
      extra = 'Happened';
      if (dayPart == 'Today' || dayPart == 'Yesterday') dayPart = dayPart.toLowerCase();
      hideTime = false;
      addEndTime = true;
      showEndTime = true;
      dayPart = ' $dayPart';
      if (trimPast && !showTime) hideTime = true;
      if (date.year != now.year) hideDay = true;
    }

    if ((endDate == null && date.compareTo(now) == -1) || (endDate != null && endDate.compareTo(now) == -1)) {
      if (trimPast && !hideHappened) {
        extra = 'Happened ';
        if (dayPart == 'Today' || dayPart == 'Yesterday') dayPart = dayPart.toLowerCase();
      }
    }

    // We don't want 10pm-12pm, instead 10-12pm
    if (showEndTime) {
      var endPart = timeFormatter.format(endDate).toLowerCase();

      if (endPart.contains('pm') == timePart.contains('pm')) {
        timePart = timePart.replaceAll('pm', '').replaceAll('am', '');
      }

      timePart = '$timePart-$endPart';
    }

    // Show year if different year.
    var yearPart = '';
    if (date.year != now.year) {
      yearPart = ' ${date.year}';
    }

    if ((expandPast || trimPast) && !detailed) {
      if (direction == 'future' && new DateTime(now.year, now.month, now.day + 7).compareTo(date) < 0) {
        timePart = '';
      }

      if (direction == 'past' && new DateTime(now.year, now.month, now.day - 7).compareTo(date) > 0) {
        timePart = '';
      }
    }

    if ((expandPast || trimPast)) {
      if (direction == 'future' && new DateTime(now.year, now.month, now.day + 14).compareTo(date) < 0) {
        dayPart = '';
        monthPart = monthPart.trim();
      }

      if (direction == 'past' && new DateTime(now.year, now.month, now.day - 14).compareTo(date) > 0) {
        dayPart = '';
        monthPart = monthPart.trim();
      }
    }

    if (expandPast || trimPast) {
      if (extra != '') {
        if (direction == 'future') {
          if (new DateTime(now.year, now.month, now.day - 7).compareTo(date) < 0) {
            monthPart = '';
          } else {
            dayPart = '';
          }
        }

        if (direction == 'past') {
          if (new DateTime(now.year, now.month, now.day + 7).compareTo(date) > 0) {
            monthPart = '';
          } else {
            dayPart = '';
          }
        }
      }
    }

    if (trimPast && new DateTime(now.year, now.month, now.day + 7).compareTo(date) > 0 && direction == 'future') {
      //monthPart = '';
    }

    if (trimPast && new DateTime(now.year, now.month, now.day - 7).compareTo(date) < 0 && direction == 'past') {
      monthPart = '';
    }

    if (hideDay) dayPart = '';
    if (hideTime) timePart = '';
    if (hideMonth) monthPart = '';
    if (extra != '') yearPart = '';

    if (t != null) extra = t(extra);

    if (dayPart == '') monthPart = monthPart.trim();

    return '$extra$dayPart$monthPart$yearPart$timePart';
  }

  static String getDayPostfix(int day) {
    var postfix;

    if (day == 1 || day == 21 || day == 31) postfix = 'st';
    else if (day == 2 || day == 22) postfix = 'nd';
    else if (day == 3 || day == 23) postfix = 'rd';
      else postfix = 'th';

    return postfix;
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

  /**
   * Cuts text short.
   *
   * Makes sure that words aren't cut in half or URIs.
   */
  static String cutText(String text, [int length = 250, dots = false]) {
    if (text == null) return '';

    if (text.length <= length) return text;

    var wasCut = text.length > length;

    // Go to the potential end.
    var position = min(length, text.length) - 3;

    // If we are at the end of a word, we should include it.
    position += 1;

    // We are in the middle of something? Don't just crop directly (i.e. "fooooo" -> "foo...") always prefer to cut words.
    var regExp = new RegExp('[a-zA-Z]');
    while (position > 0 && regExp.hasMatch(text[position - 1])) {
      position--;
    }

    // Get rid of potential crap at the end.
    regExp = new RegExp('[^a-zA-Z]');
    while (position > 0 && regExp.hasMatch(text[position - 1])) {
      position--;
    }

    // Find URL start/end -indexes.
    var urls = new RegExp('(https?://|www.)[^ ]+').allMatches(text);
    var urlBoundaries = [];
    urls.forEach((Match match) {
      var startIndex = text.indexOf(match.group(0));
      var endIndex = startIndex + match.group(0).length;
      urlBoundaries.add([startIndex, endIndex]);
    });

    var inMiddleOfUrl = false;
    var amount = 0;
    urlBoundaries.forEach((List<int> boundary) {
      if (position > boundary[0] && position < boundary[1]) {
        amount = position - boundary[0];
        inMiddleOfUrl = true;
      }
    });

    if (inMiddleOfUrl) {
      position -= amount;
    }

    if (position <= 0) return '';

    text = text.substring(0, position).trim();
    text = '$text...';

    return text;
  }

  /**
   * Strips the HTML.
   *
   * This leaves the content inside tags.
   */
  static String stripHtml(String html, [List<String> exclude = const []]) {
    if (html == null) return '';

    var tagOpen = false, stripped = '', tagName, letterRegExp = new RegExp('^[a-zA-Z]\$');

    for (var i = 0, length = html.length; i < length; i++) {
      if (html[i] == '<') {
        tagOpen = true;
        tagName = '';

        if (i + 1 < html.length) {
          var a = 1;

          if (html[i+1] == '/') {
            a++;
          }

          while (true) {
            if (html.length >= i + a) break;

            var character = html[i + a];

            if (!letterRegExp.hasMatch(character)) {
              break;
            }

            tagName = '$tagName$character';

            a++;
          }
        }

        tagName =  tagName.toLowerCase();
      }

      if (tagOpen == false || exclude.contains(tagName)) {
        stripped = '${stripped}${html[i]}';
      }

      if (html[i] == '>') {
        tagOpen = false;
        tagName = '';
      }
    }

    return stripped;
  }

  /**
   * Create intelligent teasers.
   */
  static String createIntelligentTeaser(String contents, {int length: 200, int minLength: 75}) {
    if (contents == null) return '';

    contents = sharedUtil.htmlDecode(contents);

    contents = nl2br(stripHtml(contents).trim());

    if (length >= contents.length) length = contents.length - 1;

    // Find links.
    var linkMatches = new RegExp('(http://|www.)[^ ]+').allMatches(contents);

    var lastSingleDotPosition = 0;
    for (var i = length; i > minLength; i--) {
      // This is it!
      if (contents[i] == '.' && contents[i - 1] != '.' && (i == length || contents[i + 1] != '.')) {
        // Don't accept this if in the middle of a link!
        var isLink = false;
        linkMatches.forEach((match) {
          if (match.start < i && match.end > i) isLink = true;
        });

        if (isLink) continue;

        lastSingleDotPosition = i + 1;
        break;
      }
    }

    // Only three-dotted sentence available.
    if (lastSingleDotPosition == 0) {
      var index = contents.indexOf('.');
      if (index != -1) {
        if (contents.length > index + 1 && contents[index + 1] == '.') lastSingleDotPosition = index + 3;
        else lastSingleDotPosition = index + 1;
      }
    }

    var cutPosition = min(min(lastSingleDotPosition, contents.length), length);

    // Cut.
    if (lastSingleDotPosition != 0) contents = contents.substring(0, cutPosition);

    // Replace <br>'s with an empty space.
    contents = contents.replaceAll(new RegExp('<br ?/?>'), ' ');

    // Weird stuff on Meetup...
    contents = contents.replaceAll('\\', '');

    // Get rid of &nbsp;
    contents = contents.replaceAll(new RegExp('&nbsp;?', caseSensitive: false), '');

    // Make sure there's no crazy whitespace.
    contents = contents.replaceAll(new RegExp(' {2,}'), ' ');

    return contents;
  }

  static String makeExternalLinksTargetBlank(String contents) {
    if (contents == null) return '';

    return contents.replaceAllMapped('<a ', (Match m) {
      return '<a target="_blank" ';
    });
  }

  /**
   * Creates a teaser out of the content.
   *
   * Removes HTML, strips whitespace and cuts the length.
   */
  static String createTeaser(String contents, [int length = 150]) {
    var originalContent = contents;

    if (originalContent == null) return '';

    contents = contents != null ? nl2br(cutText(stripHtml(contents).trim(), length)) : '';

    // Replace <br>'s with an empty space.
    contents = contents.replaceAll(new RegExp('<br ?/?>'), ' ');

    // Strip non-letters from the end.
    if (originalContent.length > length) {
      contents = contents.replaceAll(new RegExp('[^a-zA-Z]+\$', multiLine: false), '');
    }

    // Weird stuff on Meetup...
    contents = contents.replaceAll('\\', '');

    // Get rid of &nbsp;
    contents = contents.replaceAll(new RegExp('&nbsp;?', caseSensitive: false), '');

    // Make sure there's no crazy whitespace.
    contents = contents.replaceAll(new RegExp(' {2,}'), ' ');

    if (originalContent.length > length && contents.length > 100) {
      return '$contents...';
    }

    return contents;
  }

  /**
   * Find and format @mentions in the given content.
   *
   * Injects HTML to surround each mention with a span that can be styled.
   */
  static String formatMentions(String content) {
    if (content == null) return '';

    var regExp = new RegExp(r'\B@[a-zA-Z0-9_-]+', caseSensitive: false);

    content = content.replaceAllMapped(regExp, (Match m) => '<span class="mention">${m[0]}</span>');

    return content;
  }
}