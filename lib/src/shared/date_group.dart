library date_group;

import 'dart:async';
import 'dart:math';
import 'input_formatter.dart';
import 'package:polymer/polymer.dart' show toObservable;

/**
 * A utility class for grouping dates.
 *
 * This is used for e.g. grouping news and event lists (today, yesterday, last week, earlier).
 */
class DateGroup {
  static Map groupByJustDate(List objects) {
    var results = {};

    objects.forEach((object) {
      DateTime date;
      if (object.toString().startsWith('Event')) {
        date = object.startDate;
        if (object.endDate != null && object.endDate.difference(date).inHours.abs() > 24) {
          if (date.compareTo(new DateTime.now()) == -1 && object.endDate.compareTo(new DateTime.now()) == 1) {
            date = new DateTime.now();
          }
        }
      }

      if (['NewsArticle', 'Discussion', 'Question'].contains(object.dbType)) {
        date = object.publicationDate;
      }

      if (date == null) date = new DateTime(1970, 1, 1);

      var group = new DateTime(date.year, date.month, date.day);

      if (results.containsKey(group) == false) results[group] = toObservable([]);

      results[group].add(object);
    });

    return results;
  }

  static Future<Map<String, List<Object>>> groupByDate(List objects, String datePropertyName, {bool forward: true, bool oneLevel: false}) {
    var results = {};

    objects.forEach((object) {
      var groupName, subGroupName;

      if (['NewsArticle', 'Discussion', 'Question'].contains(object.dbType)) {
        groupName = getDateGroupName(object.publicationDate);
        subGroupName = getDateSubGroupName(object.publicationDate, groupName);
      }

      if (object.toString().startsWith('Event')) {
        groupName = getDateGroupName(object.startDate, forward: forward, endDate: object.endDate);
        subGroupName = getDateSubGroupName(object.startDate, groupName, endDate: object.endDate);
      }

      if (object.toString().startsWith('Group')) {
        groupName = getDateGroupName(object.createdAt);
        subGroupName = getDateSubGroupName(object.createdAt, groupName);
      }

      if (groupName == null) {
        groupName = 'Unknown';
        subGroupName = 'Unknown';
      }

      if (oneLevel) {
        if (results.containsKey(groupName) == false) {
          results[groupName] = toObservable([]);
        }

        results[groupName].add(object);
      } else {
        if (results.containsKey(groupName) == false) {
          results[groupName] = toObservable({});
        }

        if (results[groupName].containsKey(subGroupName) == false) {
          results[groupName][subGroupName] = toObservable([]);
        }

        results[groupName][subGroupName].add(object);
      }
    });

    return new Future.value(results);
  }

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