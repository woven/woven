library date_group;

import 'dart:math';
import 'input_formatter.dart';

/**
 * A utility class for grouping dates.
 *
 * This is used for e.g. grouping news and event lists (today, yesterday, last week, earlier).
 */
class DateGroup {
  static getDateGroupName(DateTime date, {bool forward: false, DateTime endDate}) {
    if (date == null) return 'Not Specified';

    var todayPrecise = new DateTime.now();
    var today = new DateTime(todayPrecise.year, todayPrecise.month, todayPrecise.day);

    var tomorrow = DateTime.parse(today.toString()).add(const Duration(days: 1));
    var twoDays = DateTime.parse(today.toString()).add(const Duration(days: 2));
    var thisWeek = DateTime.parse(today.toString()).subtract(new Duration(days: today.weekday)); // Sun-sat (not mon-sun!)
    var nextWeek = DateTime.parse(thisWeek.toString()).add(const Duration(days: 7));
    var twoWeeks = DateTime.parse(thisWeek.toString()).add(const Duration(days: 14));

    var yesterday = DateTime.parse(today.toString()).subtract(const Duration(days: 1));
    var lastWeek = DateTime.parse(thisWeek.toString()).subtract(const Duration(days: 7));

    if (date.compareTo(today) == -1) {
      // Earlier.
      if (date.compareTo(yesterday) >= 0) {
        return 'Yesterday';
      }

      if (date.compareTo(thisWeek) >= 0) {
        return 'This week';
      }

      if (date.compareTo(lastWeek) >= 0) {
        return 'Last week';
      }

      return 'Earlier';
    } else if (date.compareTo(tomorrow) >= 0) {
      // In the future.
      if (date.compareTo(twoDays) < 0) {
        return 'Tomorrow';
      }

      if (date.compareTo(nextWeek) < 0) {
        return 'This week';
      }

      if (date.compareTo(twoWeeks) < 0) {
        return 'Next week';
      }

      return 'Upcoming';
    } else {
      return 'Today';
    }
  }

  static String getDateSubGroupName(DateTime date, String groupName, {DateTime endDate}) {
    if (date == null) return 'Unknown';

    if (groupName == 'Today' || groupName == 'Yesterday' || groupName == 'Tomorrow') return '';

    if (groupName == 'This week' || groupName == 'Next week' || groupName == 'Last week') {
      return InputFormatter.weekdays[date.weekday];
    }

    // Show 'Week of September 15th'.
    // Basically, we create a new date which is a copy of "date", minus the weekday (sun = 1, mon = 2, wed = 3).
    // This gets us the first day of week, but sometimes it could be the previous month's day, so we use min() to make sure
    // we never go to previous month.
    var dateWeek = DateTime.parse(date.toString()).subtract(new Duration(days: min(date.weekday, date.day - 1)));
    var postfix;

    switch (dateWeek.day) {
      case 1:
      case 21:
      case 31:
        postfix = 'st';
        break;
      case 2:
      case 22:
        postfix = 'nd';
        break;
      case 3:
      case 23:
        postfix = 'rd';
        break;
      default:
        postfix = 'th';
    }

    var yearPart = '';
    var today = new DateTime.now();
    var elevenMonthsAgo = new DateTime(today.year, today.month - 11, 1);
    if (date.compareTo(elevenMonthsAgo) <= 0) {
      yearPart = ' ${date.year}';
    }

    return 'Week of ${InputFormatter.months[date.month - 1]} ${dateWeek.day}$postfix$yearPart';
  }
}