library chat_view_model;

import 'dart:async';
import 'dart:html' hide Notification;
import 'dart:web_audio';
import 'dart:js';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:notification/notification.dart';

import 'base.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/components/chat_view/chat_view.dart';
import 'package:woven/src/client/model/message.dart';
import 'package:woven/src/client/model/user.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/regex.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/item_group.dart';
import 'package:woven/src/shared/model/target_group_enum.dart';

class ChatViewModel extends BaseViewModel with Observable {
  final App app;

  @observable List<ItemGroup> groups = toObservable([]);
  List<Message> queue = [];

  // TODO: Use this later for date separators between messages.

  int pageSize = 40;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  @observable bool isScrollPosAtBottom = false;
  bool isFirstLoad = true;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;
  int totalCount = 0;

  var sanitizer = new HtmlEscape(HtmlEscapeMode.ELEMENT);

  StreamSubscription childAddedSubscriber,
      childChangedSubscriber,
      childMovedSubscriber,
      childRemovedSubscriber;

  ChatView get chatView => document
      .querySelector('woven-app')
      .shadowRoot
      .querySelector('x-main')
      .shadowRoot
      .querySelector('chat-view');

  db.Firebase get f => app.f;

  ChatViewModel({this.app}) {
    loadMessagesByPage();
  }

  /**
   * Load items pageSize at a time.
   */
  Future loadMessagesByPage() async {
    reloadingContent = true;
    int count = 0;

    var messagesRef = f
        .child('/messages_by_community/${app.community.alias}')
        .startAt(value: lastPriority)
        .limitToFirst(pageSize + 1);

    if (groups.expand((ItemGroup i) => i.items).length == 0) onLoadCompleter
        .complete(true);

    // Get the list of items, and listen for new ones.
    db.DataSnapshot snapshot = await messagesRef.once('value');

    Map messages = snapshot.exportVal();
    if (messages == null) {
      reachedEnd = true;
      return null;
    }

    List messagesAsList = [];

    messages.forEach((k, v) {
      Message message = new Message.fromJson(v);
      message.id = k;
      messagesAsList.add(message);
    });

    await Future.forEach(messagesAsList, (Message message) async {
      count++;
      totalCount++;

      // Track the snapshot's priority so we can paginate from the last one.
      lastPriority = message.priority;

      // Don't process the extra item we tacked onto pageSize in the limit() above.
      if (count > pageSize) return null;

      // Remember the priority of the last item, excluding the extra item which we ignore above.
      secondToLastPriority = message.priority;

      await preProcess(message);

      queue.add(message);
    });

    processAll(queue);
    queue.clear();
    relistenForItems();

    // If we received less than we tried to load, we've reached the end.
    if (count <= pageSize) reachedEnd = true;

    // Wait until the view is loaded, then scroll to bottom.
    if (isScrollPosAtBottom || isFirstLoad && chatView != null) Timer
        .run(() => chatView.scrollToBottom());
    isFirstLoad = false;

    new Timer(new Duration(seconds: 1), () {
      reloadingContent = false;
    });
  }

  /**
   * Listen for new stuff within the items we're currently showing.
   */
  void relistenForItems() {
    if (childAddedSubscriber != null) {
      childAddedSubscriber.cancel();
      childAddedSubscriber = null;
    }
    if (childChangedSubscriber != null) {
      childChangedSubscriber.cancel();
      childChangedSubscriber = null;
    }
    if (childMovedSubscriber != null) {
      childMovedSubscriber.cancel();
      childMovedSubscriber = null;
    }
    if (childRemovedSubscriber != null) {
      childRemovedSubscriber.cancel();
      childRemovedSubscriber = null;
    }

    // TODO: This is ignoring the page size/limit set above.
    listenForNewItems(startAt: topPriority, endAt: secondToLastPriority);
  }

  listenForNewItems({startAt, endAt}) {
    // If this is the first item loaded, start listening for new items.
    var itemsRef = f
        .child('/messages_by_community/${app.community.alias}')
        .startAt(value: startAt)
        .endAt(value: endAt);

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) async {
      Message message = new Message.fromJson(e.snapshot.val());
      message.id = e.snapshot.key;

      // Make sure we're using the collapsed username.
      message.user = message.user.toLowerCase();

      Message existingItem = groups.expand((ig) => ig.items).firstWhere(
          (Message i) => (i.id != null)
              ? (i.id == message.id)
              : (i.user == message.user &&
                  i.message != null &&
                  i.message == message.message),
          orElse: () => null);

      // If we already have the item, get out of here.
      if (existingItem != null) {
        // Pass the ID to the existing item as we might not have it.
        existingItem.id = message.id;

        existingItem.createdDate = message.createdDate;
        existingItem.updatedDate = (message.updatedDate != null)
            ? message.updatedDate
            : message.createdDate;

        // If the message timestamp is after our local time,
        // change it to now so messages aren't in the future.
        DateTime localTime = new DateTime.now().toUtc();
        if (existingItem.updatedDate
            .isAfter(localTime)) existingItem.updatedDate = localTime;
        if (existingItem.createdDate
            .isAfter(localTime)) existingItem.createdDate = localTime;
      } else {
        // Notify mentioned users if this is a typical message (i.e. no special type).
        if (message.type == null) doNotifications(message);

        process(message);
      }

      // If user is scrolled to bottom, keep it that way.
      if (isScrollPosAtBottom || isFirstLoad && chatView != null) {
        Timer.run(() => chatView.scrollToBottom());
      }
    });

    // Listen for changed items.
//    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
//      Map currentData = messages.firstWhere((i) => i['id'] == e.snapshot.key);
//      Map newData = e.snapshot.val();
//
//      Future processData = new Future.sync(() {
//        // First pre-process some things.
//        if (newData['createdDate'] != null) newData['createdDate'] = DateTime.parse(newData['createdDate']);
//        if (newData['updatedDate'] != null) newData['updatedDate'] = DateTime.parse(newData['updatedDate']);
//
//        // If the message timestamp is after our local time,
//        // change it to now so messages aren't in the future.
//        DateTime localTime = new DateTime.now().toUtc();
//        if (newData['updatedDate'].isAfter(localTime)) newData['updatedDate'] = localTime;
//        if (newData['createdDate'].isAfter(localTime)) newData['createdDate'] = localTime;
//
//      }).then((_) {
//        // Now that new data is pre-processed, update current data.
//        newData.forEach((k, v) => currentData[k] = v);
//        // TODO: Ugh, I'd like to avoid this re-sort.
////        messages.sort((m1, m2) => m1["createdDate"].compareTo(m2["createdDate"]));
//      });
//    });
  }

  doNotifications(Message item) {
    var regExp = new RegExp(RegexHelper.mention, caseSensitive: false);

    List mentions = [];

    if (item.message == null) item.message = '';

    for (var mention in regExp.allMatches(item.message)) {
      if (mentions.contains(mention.group(2))) return;
      mentions.add(mention.group(2).replaceAll("@", "").toLowerCase());
    }

    if (mentions.contains(app.user.username.toLowerCase())) {
      // Notify the user.
      if (!Notification.supported) return;

      Notification notification = new Notification(
          "${item.usernameForDisplay} mentioned you",
          body: InputFormatter.createTeaser(
              item.message.replaceAll('\n', ' '), 75),
          icon: '/static/images/w_button_trans_margin.png');
      playNotificationSound();
      notification.addEventListener('click', notificationClicked);
      new Timer(new Duration(seconds: 8), () {
        notification.close();
      });
    }
  }

  Future<String> usernameForDisplay(String username) {
    return UserModel
        .usernameForDisplay(username.toLowerCase(), f, app.cache)
        .then((String usernameForDisplay) => usernameForDisplay);
  }

  /**
   * Handle clicks on web notifications.
   */
  notificationClicked(Event e) => context.callMethod('focus');

  /**
   * Play the notification sound.
   */
  playNotificationSound() async {
    GainNode gainNode = app.audioContext.createGain();

    // get the audio file
    HttpRequest request = await HttpRequest.request(
        app.serverPath + "/static/audio/beep_short_on.wav",
        responseType: "arraybuffer");
    // decode it
    AudioBuffer buffer =
        await app.audioContext.decodeAudioData(request.response);
    AudioBufferSourceNode source = app.audioContext.createBufferSource();
    source.buffer = buffer;
    source.connectNode(app.audioContext.destination);

    // play it now
    source.start(app.audioContext.currentTime);
  }

  /**
   * Handle commands.
   */
  commandRouter(Message message) async {
    // TODO: Refactor all this later.
    // A message of type 'local' is a basic, temporary local message
    // to the user, like in response to a command.
//    message.type = 'local';
    message.type = 'notification';
    String commandText = message.message;
    String commandTop = commandText.split(' ').first;
    String commandOptions = (commandText.split(' ').length > 1)
        ? commandText
            .substring(commandText.lastIndexOf(' ') + 1, commandText.length)
            .trim()
        : null;
    switch (commandTop) {
      case '/theme':
        switch (commandOptions) {
          case 'dark':
            message.message = 'You went dark. I\'ve saved your preference.';
            if (app.user.settings['theme'] == 'dark') message.message =
                'You\'ve already gone dark.';
            document.body.classes.add('no-transition');
            process(message);
            Timer.run(() => app.user.settings['theme'] = 'dark');
            f
                .child(
                    '/users/${app.user.username.toLowerCase()}/settings/theme')
                .set('dark');
            new Timer(new Duration(seconds: 1),
                () => document.body.classes.remove('no-transition'));
            break;
          case 'light':
            message.message =
                'Let there be light. I\'ve saved your preference.';
            if (app.user.settings['theme'] == 'light') message.message =
                'You\'re already lit up.';
            document.body.classes.add('no-transition');
            process(message);
            Timer.run(() => app.user.settings['theme'] = 'light');
            f
                .child(
                    '/users/${app.user.username.toLowerCase()}/settings/theme')
                .set('light');
            new Timer(new Duration(seconds: 1),
                () => document.body.classes.remove('no-transition'));
            break;
          default:
            message.message = 'I don\'t recognize that theme.';
            process(message);
            break;
        }
        break;
      case '/invite':
        // TODO: Validate the email.
        String email = commandOptions;

        if (email == null || email.trim().isEmpty) {
          message.message = 'I need a valid email address.';
          process(message);
          break;
        }

        HttpRequest request = await HttpRequest.request(
            app.serverPath + Routes.inviteUserToChannel.toString(),
            method: 'POST',
            sendData: JSON.encode({
              'community': app.community.alias,
              'fromUser': message.user,
              'email': email,
              'authToken': app.authToken
            }));

        var response = Response.fromJson(JSON.decode(request.responseText));
        if (response.success) message.message =
            'I have sent an invitation to $email on your behalf.';
        if (!response.success) message.message =
            'Sorry. I was not able to send an invitation to $email.';
        process(message);
        break;
      case '/print isMobile':
        message.message =
            app.isMobile.toString() + ' ' + window.screen.width.toString();
        process(message);
        break;
      case '/notify':
        // JS interop version of web notifications until Dart fixes land.
        String dummyMessage =
            'Lorem ipsum dolor sit amet conseceteur adipiscing\n elit and some other random text and gibberish to prove a point';

        if (!Notification.supported) return;
        await Notification.requestPermission();
        Notification notification = new Notification("Hello world",
            body: InputFormatter.createTeaser(
                dummyMessage.replaceAll('\n', ' '), 75),
            icon: '/static/images/woven_button_trans_margin_more.png');
        new Timer(new Duration(seconds: 8), () {
          notification.close();
        });

        playNotificationSound();
        break;
      default:
        message.message = 'I don\'t recognize that command.';
        process(message);
        break;
    }
    Timer.run(() => chatView.scrollToBottom());
  }

  preProcess(Message item) async {
    // TODO: Look into not waiting for this lookup; show UI sooner w/ x-username element doing the lookup.
//    item.usernameForDisplay = await UserModel.usernameForDisplay(item.user.toLowerCase(), f, app.cache);
    item.usernameForDisplay = item.user;

    // If the message references an item, let's get it so we can show it inline.
    if (item.data != null &&
        item.data['event'] == 'added' &&
        item.data['id'] != null) {
      var itemId = item.data['id'];

      // Let's handle older 'notification' messages which reference an item.
      item.type = 'item';
    }
  }

  void processAll(List<Message> items) {
    items.forEach(process);
  }

  process(Message item) {
    // Make sure we're using the collapsed username.
    item.user = item.user.toLowerCase();

    DateTime now = new DateTime.now().toUtc();
    DateTime gracePeriod = app.timeOfLastFocus.add(new Duration(seconds: 2));

    item.isHighlighted = false;
    if (now.isAfter(gracePeriod) && !app.isFocused) item.isHighlighted = true;

    // If no updated date, use the created date.
    // TODO: We assume createdDate is never null!
    if (item.updatedDate == null) item.updatedDate = item.createdDate;

    // If the message timestamp is after our local time,
    // change it to now so messages aren't in the future.
    DateTime localTime = new DateTime.now().toUtc();
    if (item.updatedDate.isAfter(localTime)) item.updatedDate = localTime;
    if (item.createdDate.isAfter(localTime)) item.createdDate = localTime;

    // TODO: Can we get the inline item as part of the chat vm?
    // Problem is we;d have to dupe item processing from feed vm.
//    if (item.type == 'item') {
//      f.child('/items/' + item.data['id']).onValue.listen((e) {
//
//      });
//    }

    // Retrieve the group that this item belongs to, if any.
    var group = groups.firstWhere(
        (group) => group.isDateWithin(item.createdDate),
        orElse: () => null);

    if (group != null) {
      TargetGroup target = group.determineTargetGroup(item);
      if (target == TargetGroup.Same) {
        group.put(item);
      } else {
        var groupIndex = groups.indexOf(group);
        var intersection = group.indexOf(item);

        var topHalf = group.items.sublist(0, intersection);
        var bottomHalf = group.items.sublist(intersection);

        groups.remove(
            group); // Get rid of the old group, we need to split this thing!

        if (target == TargetGroup.New) {
          groups.insert(groupIndex, new ItemGroup.fromItems(bottomHalf));
          groups.insert(groupIndex, new ItemGroup(item));
          groups.insert(groupIndex, new ItemGroup.fromItems(topHalf));
        } else if (target == TargetGroup.Above) {
          topHalf.add(item);
          groups.insert(groupIndex, new ItemGroup.fromItems(bottomHalf));
          groups.insert(groupIndex, new ItemGroup.fromItems(topHalf));
        } else if (target == TargetGroup.Below) {
          bottomHalf.insert(0, item);
          groups.insert(groupIndex, new ItemGroup.fromItems(bottomHalf));
          groups.insert(groupIndex, new ItemGroup.fromItems(topHalf));
        } else {
          throw 'Unknown target group!';
        }
      }
    } else {
      // Okay, so the item is not within ANY group.
      // This leaves a few options:
      // 1) The item belongs to the top or bottom position of some group (i.e. not within).
      // 2) The item needs its own new group.

      // Fetch the first groups that are after/before this item. i.e. surrounding the item.
      var groupBefore = groups.reversed.firstWhere(
          (group) => item.createdDate.isAfter(group.getLatestDate()),
          orElse: () => null);
      var groupAfter = groups.firstWhere(
          (group) => item.createdDate.isBefore(group.getOldestDate()),
          orElse: () => null);

      if (groupBefore == null && groupAfter == null) {
        // No groups at all!
        groups.add(new ItemGroup(item));
      } else if (groupBefore != null && groupAfter != null) {
        if (groupBefore.determineTargetGroup(item) == TargetGroup.New &&
            groupAfter.determineTargetGroup(item) == TargetGroup.New) {
          // The item does not belong in either groups,
          // so it has to go in between them in its own group.
          var index = groups.indexOf(groupAfter);
          groups.insert(index, new ItemGroup(item));
        } else if (groupBefore.determineTargetGroup(item) == TargetGroup.Same) {
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
        if (groupAfter.determineTargetGroup(item) == TargetGroup.Same) {
          groupAfter.put(item);
        } else {
          groups.insert(0, new ItemGroup(item));
        }
      } else {
        // There was no group after this item, but one before.
        // Same as earlier, let's put it there or in a new group at the bottom.
        if (groupBefore.determineTargetGroup(item) == TargetGroup.Same) {
          groupBefore.put(item);
        } else {
          groups.add(new ItemGroup(item));
        }
      }
    }
  }

  /**
   * Find the index of the item with the closest updated date.
   */
//  indexOfClosestItemByDate(date) {
//    for (var message in messages) {
//      if ((message['updatedDate'] as DateTime).isAfter(date)) return messages.indexOf(message);
//    }
//  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadMessagesByPage();
  }
}
