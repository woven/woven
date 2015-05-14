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

class ChatViewModel extends BaseViewModel with Observable {
  final App app;

  @observable List<ItemGroup> groups = toObservable([]);
  List<Message> queue = [];

  // TODO: Use this later for date separators between messages.

  int pageSize = 25;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  @observable bool isScrollPosAtBottom = false;
  bool isFirstLoad = true;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;
  int totalCount = 0;

  var sanitizer = new HtmlEscape(HtmlEscapeMode.ELEMENT);

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  db.Firebase get f => app.f;

  AudioContext audioContext = new AudioContext();

  ChatViewModel({this.app}) {
    loadMessagesByPage();
  }

  /**
   * Load items pageSize at a time.
   */
  Future loadMessagesByPage() {
    reloadingContent = true;
    int count = 0;

    var messagesRef = f.child('/messages_by_community/${app.community.alias}')
    .startAt(value: lastPriority)
    .limitToFirst(pageSize + 1);

//    if (items.length == 0) onLoadCompleter.complete(true);

    // Get the list of items, and listen for new ones.
    return messagesRef.once('value').then((snapshot) {
      Map messages = snapshot.exportVal();
      if (messages == null) {
        reachedEnd = true;
        return null;
      }
      List messagesAsList = [];
      messages.forEach((k,v) {
        Message message = new Message.fromJson(v);
        message.id = k;
        messagesAsList.add(message);
      });

      return Future.forEach(messagesAsList, (Message message) {
        count++;
        totalCount++;

        // Make sure we're using the collapsed username.
        message.user = message.user.toLowerCase();

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = message.priority;

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return null;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
        secondToLastPriority = message.priority;

        return usernameForDisplay(message.user).then((String usernameForDisplay) {
          message.usernameForDisplay = usernameForDisplay;

          queue.add(message);
        });

      }).then((_) {
        processAll(queue);
        queue.clear();
        relistenForItems();

        // If we received less than we tried to load, we've reached the end.
        if (count <= pageSize) reachedEnd = true;

        // Wait until the view is loaded, then scroll to bottom.
        if (isScrollPosAtBottom || isFirstLoad && chatView != null) Timer.run(() => chatView.scrollToBottom());
        isFirstLoad = false;

        new Timer(new Duration(seconds: 1), () {
          reloadingContent = false;
        });
      });
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
    var itemsRef = f.child('/messages_by_community/${app.community.alias}')
    .startAt(value: startAt)
    .endAt(value: endAt);

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) async {
      Message message = new Message.fromJson(e.snapshot.val());
      message.id = e.snapshot.key;

      // Make sure we're using the collapsed username.
      message.user = message.user.toLowerCase();

      Message existingItem = groups.expand((ig) => ig.items).firstWhere((Message i) => (i.id != null)
        ? (i.id == message.id)
        : (i.user == message.user && i.message != null && i.message == sanitizer.convert(message.message)), orElse: () => null);

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
        if (existingItem.updatedDate.isAfter(localTime)) existingItem.updatedDate = localTime;
        if (existingItem.createdDate.isAfter(localTime)) existingItem.createdDate = localTime;

      } else {
        // Insert each new item into the list.
        message.usernameForDisplay = await usernameForDisplay(message.user);

        // Notify mentioned users, unless this is a notification message.
        if (message.type != 'notification') doNotifications(message);

        process(message);
      }

      // If user is scrolled to bottom, keep it that way.
      if (isScrollPosAtBottom || isFirstLoad && chatView != null) Timer.run(() => chatView.scrollToBottom());
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

    for (var mention in regExp.allMatches(item.message)) {
      if (mentions.contains(mention.group(2))) return;
      mentions.add(mention.group(2).replaceAll("@", "").toLowerCase());
    }

    if (mentions.contains(app.user.username.toLowerCase())) {
      // Notify the user.
      if (!Notification.supported) return;

      Notification notification = new Notification("${item.usernameForDisplay} mentioned you", body: InputFormatter.createTeaser(item.message.replaceAll('\n', ' '), 75), icon: '/static/images/w_button_trans_margin.png');
      playNotificationSound();
      notification.addEventListener('click', notificationClicked);
      new Timer(new Duration(seconds: 8), () {
        notification.close();
      });
    }
  }

  Future<String> usernameForDisplay(String username) {
    return UserModel.usernameForDisplay(username.toLowerCase(), f, app.cache)
    .then((String usernameForDisplay) => usernameForDisplay);
  }

  /**
   * Prepare the message and insert it into the observed list.
   */
  insertMessage(Message message) {
    if (message.message != null) message.message = sanitizer.convert(message.message);

    DateTime now = new DateTime.now().toUtc();
    DateTime gracePeriod = app.timeOfLastFocus.add(new Duration(seconds: 2));

    message.isHighlighted = false;
    if (now.isAfter(gracePeriod) && !app.isFocused) message.isHighlighted = true;

    // If no updated date, use the created date.
    // TODO: We assume createdDate is never null!
    if (message.updatedDate == null) message.updatedDate = message.createdDate;

    // The live-date-time element needs parsed dates.
//    message.updatedDate = DateTime.parse(message.updatedDate);
//    message.createdDate = DateTime.parse(message.createdDate);

    // If the message timestamp is after our local time,
    // change it to now so messages aren't in the future.
    DateTime localTime = new DateTime.now().toUtc();
    if (message.updatedDate.isAfter(localTime)) message.updatedDate = localTime;
    if (message.createdDate.isAfter(localTime)) message.createdDate = localTime;

//    var index = indexOfClosestItemByDate(message['updatedDate']);
//
//    messages.insert(index == null ? messages.length : index, toObservable(message));
  }


  /**
   * Handle clicks on web notifications.
   */
  notificationClicked(Event e) => context.callMethod('focus');

  /**
   * Play the notification sound.
   */
  playNotificationSound() async {
    GainNode gainNode = audioContext.createGain();

    // get the audio file
    HttpRequest request = await HttpRequest.request(app.serverPath + "/static/audio/beep_short_on.wav", responseType: "arraybuffer");
    // decode it
    AudioBuffer buffer = await audioContext.decodeAudioData(request.response);
    AudioBufferSourceNode source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connectNode(audioContext.destination);

    // play it now
    source.start(audioContext.currentTime);
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
    String commandText =  message.message;
    String commandTop = commandText.split(' ').first;
    String commandOptions = (commandText.split(' ').length > 1) ? commandText.substring(commandText.lastIndexOf(' ') + 1, commandText.length).trim() : null;
    switch (commandTop) {
      case '/theme':
        switch (commandOptions) {
          case 'dark':
            message.message = 'You went dark. I\'ve saved your preference.';
            if (app.user.settings['theme'] == 'dark') message.message = 'You\'ve already gone dark.';
            document.body.classes.add('no-transition');
            process(message);
            Timer.run(() => app.user.settings['theme'] = 'dark');
            f.child('/users/${app.user.username.toLowerCase()}/settings/theme').set('dark');
            new Timer(new Duration(seconds: 1), () => document.body.classes.remove('no-transition'));
            break;
          case 'light':
            message.message = 'Let there be light. I\'ve saved your preference.';
            if (app.user.settings['theme'] == 'light') message.message = 'You\'re already lit up.';
            document.body.classes.add('no-transition');
            process(message);
            Timer.run(() => app.user.settings['theme'] = 'light');
            f.child('/users/${app.user.username.toLowerCase()}/settings/theme').set('light');
            new Timer(new Duration(seconds: 1), () => document.body.classes.remove('no-transition'));
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
            app.serverPath +
            Routes.inviteUserToChannel.toString(),
            method: 'POST',
            sendData: JSON.encode({
              'community': app.community.alias,
              'fromUser': message.user,
              'email': email,
              'authToken': app.authToken
            }));

        var response = Response.fromJson(JSON.decode(request.responseText));
        if (response.success) message.message = 'I have sent an invitation to $email on your behalf.';
        if (!response.success) message.message = 'Sorry. I was not able to send an invitation to $email.';
        process(message);
        break;
      case '/print isMobile':
        message.message = app.isMobile.toString() + ' ' + window.screen.width.toString();
        process(message);
        break;
      case '/notify':
        // JS interop version of web notifications until Dart fixes land.
        String dummyMessage = 'Lorem ipsum dolor sit amet conseceteur adipiscing\n elit and some other random text and gibberish to prove a point';

        if (!Notification.supported) return;
        await Notification.requestPermission();
        Notification notification = new Notification("Hello world", body: InputFormatter.createTeaser(dummyMessage.replaceAll('\n', ' '), 75), icon: '/static/images/woven_button_trans_margin_more.png');
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

  void processAll(List<Message> items) {
    items.forEach(process);
  }

  void process(Message item) {
    if (item.message != null) item.message = sanitizer.convert(item.message);

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

    // Retrieve the group that this item belongs to, if any.
    var group = groups.firstWhere((group) => group.isDateWithin(item.createdDate), orElse: () => null);

    if (group != null) {
      if (group.hasSameUser(item)) {
        group.put(toObservable(item));
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
        if (groupBefore.hasDifferentUser(item) && groupAfter.hasDifferentUser(item)) {
          // The item does not belong in either groups,
          // so it has to go in between them in its own group.
          var index = groups.indexOf(groupAfter);
          groups.insert(index, new ItemGroup(item));
        } else if (groupBefore.hasSameUser(item)) {
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
        if (groupAfter.hasSameUser(item)) {
          groupAfter.put(item);
        } else {
          groups.insert(0, new ItemGroup(item));
        }
      } else {
        // There was no group after this item, but one before.
        // Same as earlier, let's put it there or in a new group at the bottom.
        if (groupBefore.hasSameUser(item)) {
          groupBefore.put(item);
        } else {
          groups.add(new ItemGroup(item));
        }
      }
    }
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadMessagesByPage();
  }
}