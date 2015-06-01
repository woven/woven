library daily_digest_task;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:mustache/mustache.dart' as mustache;
import 'package:intl/intl.dart';

import 'task.dart';
import 'package:woven/src/server/model/community.dart';
import 'package:woven/src/server/mailer/mailer.dart';
import 'package:woven/src/shared/model/item_group.dart';
import 'package:woven/src/shared/model/message.dart';
import 'package:woven/src/server/firebase.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/server/model/user.dart';

class DailyDigestTask extends Task {
  bool runImmediately = false;
  DateTime runAtDailyTime = new DateTime.utc(1900, 1, 1, 13, 40); // Equivalent to 7am EST.

  List<ItemGroup> groups = [];
  List groupsB = [];

  DailyDigestTask();

  /**
   * Runs the task.
   */
  Future run() async {
    DateTime now = new DateTime.now().toUtc();
    print("Starting daily digest task at $now...");
    List<Map> usersByCommunity = await CommunityModel.getCommunitiesWithUsers();

    // Loop over each community/users map.
    usersByCommunity.forEach((Map communitiesWithUsers) async {
      CommunityModel community = communitiesWithUsers['community'];
      List<UserModel> users = communitiesWithUsers['users'];

      if (users == null) return;

      // Hardcode EST (UTC-5) for now.
      DateTime startOfDay = new DateTime.utc(now.year, now.month, now.day).add(new Duration(hours:5));
      DateTime endOfDay = startOfDay.add(new Duration(hours: 23, minutes: 59, seconds: 59));
//        print("startOf: $startOfDay, endOf: $endOfDay");

      try {
        String output = await generateDigest(community.alias, from: startOfDay, to: endOfDay);

        // If the digest returned nothing, we're done here.
        if (output == null) return;
        // Send the digest to each user in the community.
        users.forEach((user) async {
          if (user == null) return;
//          if (user.username != 'dave') return;
          // TODO: Temporarily limited to Dave.

          var firstName = (user.firstName != null ? user.firstName : '[oops, we don\'t have your first name]');
          var lastName = (user.lastName != null ? user.lastName : '[egad, we don\'t have your last name]');

          if (user.email == null) {
            print('Skipped ${user.username} due to no email address...');
            return;
          }

          // Personalize the output using merge tokens.
          // We based our merge tokens off of MailChimp: http://goo.gl/xagsyk
          var mergedDigest = output
          .replaceAll(r'*|FNAME|*', firstName)
          .replaceAll(r'*|LNAME|*', lastName)
          .replaceAll(r'*|EMAIL|*', user.email);

          DateTime now = new DateTime.now();
          var formatter = new DateFormat('E M/d/yy');
          String formattedToday = formatter.format(now);

          // Generate and send the email.
          var envelope = new Envelope()
            ..from = "Woven <hello@woven.co>"
            ..to = ['${firstName} ${lastName} <${user.email}>']
            ..subject = '${community.name} – Today\'s activity – $formattedToday'
            ..html = '$mergedDigest';

          Map res = await Mailgun.send(envelope);
          if (res['status'] == 200) return;
          // Success.
          print('Daily digest failed to send. Response was:\n$res');

        });
      } catch(error, stack) {
        print("Exception caught generating and sending digest:\n$error\n\n$stack");
      }
    });
  }

  /**
   * Generate the HTML output for the daily digest.
   */
  Future generateDigest(String community, {DateTime from, DateTime to}) async {
    Map jsonForTemplate = {};
    List events = [];
    List news = [];
    List messages = [];

    String communityName = await CommunityModel.getCommunityName(community);

    DateTime now = new DateTime.now().toUtc();
    DateTime yesterday = now.subtract(new Duration(days: 1));

    Future<List> findEvents() async {
      // Handle empty to/from.
      if (from == null) {
        from = new DateTime.utc(now.year, now.month, now.day);
      }
      if (to == null) {
        to = new DateTime.utc(from.year, from.month, from.day, 23, 59, 59, 999);
      }

      var startAt = from.millisecondsSinceEpoch;
      var endAt = to.millisecondsSinceEpoch;
      var query = '/items_by_community_by_type/$community/event.json?orderBy="startDateTimePriority"&startAt="$startAt"&endAt="$endAt"';

      Map itemsMap = await Firebase.get(query);

      // If there are no items for the digest, get out of here.
      if (itemsMap == null) return null;

      itemsMap.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        var itemMap = v;
        itemMap['id'] = k;
        events.add(itemMap);
      });

      // Do some pre-processing.
      events.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 100);
        // Convert the UTC start date to EST (UTC-5) for the newsletter.
        // TODO: Later, consider more timezones.
        DateTime startDateTime = DateTime.parse(i['startDateTime']).subtract(new Duration(hours: 5));
        // TODO: Revisit this, it was causing exception as News don't have subjects now.
        if (i['subject'] == null) i['subject'] = '';
        i['body'] = teaser;
        i['startDateTime'] = InputFormatter.formatDate(startDateTime);
        i['encodedId'] = base64Encode(i['id']);
      });

      return events;
    }

    Future<List> findNews() async {
      var startAt = new DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 12, 00, 00);
      var endAt = new DateTime.utc(now.year, now.month, now.day, 23, 59, 00); // TODO: Set back to 12 UTC.
      var query = '/items_by_community_by_type/$community/news.json?orderBy="createdDate"&startAt="$startAt"&endAt="$endAt"';

      Map itemsMap = await Firebase.get(query);

      if (itemsMap == null) return null;

      itemsMap.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        var itemMap = v;
        itemMap['id'] = k;
        news.add(itemMap);
      });

      // Do some pre-processing.
      news.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 100);

        // Convert the UTC start date to EST (UTC-5). TODO: Later, consider more timezones.
        DateTime createdDate = DateTime.parse(i['createdDate']).subtract(new Duration(hours: 5));

        // TODO: Revisit this, it was causing exception as News don't have subjects now.
        if (i['subject'] == null) i['subject'] = '';

        i['body'] = teaser;
        i['createdDate'] = InputFormatter.formatDate(createdDate);
        i['encodedId'] = base64Encode(i['id']);
      });

      return news;
    }

    Future<List> findMessages() async {
      var startAt = new DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 12, 00, 00);
      var endAt = new DateTime.utc(now.year, now.month, now.day, 23, 59, 00); // TODO: Set back to 12 UTC.
      var query = '/messages_by_community/$community.json?orderBy="createdDate"&startAt="$startAt"&endAt="$endAt"';

      Map itemsMap = await Firebase.get(query);

      if (itemsMap == null) return null;

      applyEmojiStyles(String text) =>
        text.replaceAll('class="emoji"','''style="display: inline-block;vertical-align: sub;width: 1.5em;height: 1.5em;background-size: 1.5em;background-repeat: no-repeat;text-indent: -9999px;"''');

      itemsMap.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        Message message = new Message.fromJson(v);
        message.id = k;
        if (message.type != 'notification' && message.message.isNotEmpty) {
          message.message = applyEmojiStyles(InputFormatter.formatUserText(message.message));
          messages.add(message);
        }
      });

      await Future.forEach(messages, (Message message) async {
        process(message);
      });

      await Future.forEach(groups, (ItemGroup group) async {
        Map groupMap = group.toJson();
        groupMap['usernameForDisplay'] = await UserModel.usernameForDisplay(groupMap['user']);
        var getPicture = await UserModel.getFullPathToPicture(groupMap['user']);
        groupMap['fullPathToPicture'] = (getPicture != null ? getPicture : null);

        groupsB.add(groupMap);
      });
      return groupsB;
    }

    await Future.wait([findEvents(), findNews(), findMessages()]);

    if (messages.isEmpty && events.isEmpty) return null;

    jsonForTemplate['communityName'] = communityName;
    jsonForTemplate['community'] = community;
    jsonForTemplate['events'] = events;
    jsonForTemplate['news'] = []; // Empty list i.e. news disabled for now.
    jsonForTemplate['messages'] = groupsB;
    jsonForTemplate['has_messages'] = groupsB.isNotEmpty;

    String contents = await new File('web/static/templates/daily_digest.mustache').readAsString();

    // Parse the template.
    var template = mustache.parse(contents);
    var output = template.renderString(jsonForTemplate);

    return output;
  }

  void processAll(List<Message> items) {
    items.forEach(process);
  }

  void process(Message item) {
    DateTime now = new DateTime.now().toUtc();

    // If no updated date, use the created date.
    // TODO: We assume createdDate is never null!
    if (item.updatedDate == null) item.updatedDate = item.createdDate;

    // If the message timestamp is after our local time,
    // change it to now so messages aren't in the future.
    DateTime localTime = new DateTime.now().toUtc();
    if (item.updatedDate.isAfter(localTime)) item.updatedDate = localTime;
    if (item.createdDate.isAfter(localTime)) item.createdDate = localTime;

    // Retrieve the group that this item belongs to, if any.
    var group = groups.firstWhere((group) => group.isDateWithin(item.createdDate), orElse: () => null);

    if (group != null) {
      if (!group.needsNewGroup(item)) {
        group.put(item);
      } else {
        // Damn, we'd like to put the item in this group, but diff user!
        // This means, we have to split an existing group into 2 halves,
        // and then create 1 new for this item in between those halves.
        var groupIndex = groups.indexOf(group);

        var intersection = group.indexOf(item);
        var topHalf = group.items.sublist(0, intersection);
        var bottomHalf = group.items.sublist(intersection);

        groups.remove(group); // Get rid of the old group, we need to split this thing!

        groups.insert(groupIndex, new ItemGroup.fromItems(bottomHalf));
        groups.insert(groupIndex, new ItemGroup(item));
        groups.insert(groupIndex, new ItemGroup.fromItems(topHalf));
      }
    } else {
      // Okay, so the item is not within ANY group.
      // This leaves a few options:
      // 1) The item belongs to the top or bottom position of some group (i.e. not within).
      // 2) The item needs its own new group.

      // Fetch the first groups that are after/before this item. i.e. surrounding the item.
      var groupBefore = groups.reversed.firstWhere((group) => item.createdDate.isAfter(group.getLatestDate()), orElse: () => null);
      var groupAfter = groups.firstWhere((group) => item.createdDate.isBefore(group.getOldestDate()), orElse: () => null);

      if (groupBefore == null && groupAfter == null) {
        // No groups at all!
        groups.add(new ItemGroup(item));
      } else if (groupBefore != null && groupAfter != null) {
        if (groupBefore.needsNewGroup(item) && groupAfter.needsNewGroup(item)) {
          // The item does not belong in either groups,
          // so it has to go in between them in its own group.
          var index = groups.indexOf(groupAfter);
          groups.insert(index, new ItemGroup(item));
        } else if (!groupBefore.needsNewGroup(item)) {
          // We do not belong to groupAfter, but we belong to groupBefore!
          groupBefore.put(item);
        } else {
          // We belong to groupAfter.
          groupAfter.put(item);
        }
      } else if (groupBefore == null) {
        // There was no group before this item, but one after.
        // Thus if we belong to groupAfter, let's go there,
        // otherwise we need a new group at the top.
        if (!groupAfter.needsNewGroup(item)) {
          groupAfter.put(item);
        } else {
          groups.insert(0, new ItemGroup(item));
        }
      } else {
        // There was no group after this item, but one before.
        // Same as earlier, let's put it there or in a new group at the bottom.
        if (!groupBefore.needsNewGroup(item)) {
          groupBefore.put(item);
        } else {
          groups.add(new ItemGroup(item));
        }
      }
    }
  }
}