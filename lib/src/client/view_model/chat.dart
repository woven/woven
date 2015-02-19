library chat_view_model;

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'dart:async';
import 'dart:html';
import 'base.dart';
import 'package:woven/src/client/components/chat_view/chat_view.dart';

class ChatViewModel extends BaseViewModel with Observable {
  final App app;
  final List messages = toObservable([]);
  // TODO: Use this later for date separators between messages.
  final Map groupedItems = toObservable({});

  final f = new Firebase(config['datastore']['firebaseLocation']);

  int pageSize = 50;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  @observable bool isScrollPosAtBottom = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;
  int totalCount = 0;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');


  ChatViewModel({this.app}) {
    loadMessagesByPage();
  }

  /**
   * Load more items pageSize at a time.
   */
  loadMessagesByPage() {
    reloadingContent = true;
    int count = 0;

    var messagesRef = f.child('/messages_by_community/${app.community.alias}')
    .startAt(priority: lastPriority)
    .limit(pageSize + 1);

    if (messages.length == 0) onLoadCompleter.complete(true);

    // Get the list of items, and listen for new ones.
    messagesRef.once('value').then((snapshot) {
      snapshot.forEach((itemSnapshot) {
        Map message = itemSnapshot.val();

        // Use the Firebase snapshot ID as our ID.
        message['id'] = itemSnapshot.name;

        count++;
        totalCount++;

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = itemSnapshot.getPriority();

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
        secondToLastPriority = itemSnapshot.getPriority();

        // Insert each new item into the list.
        insertMessage(message);

//        messages.sort((m1, m2) => m1["createdDate"].compareTo(m2["createdDate"]));

        // Wait for the message to come in over the network, then set scroll position to new bottom.
        // Only do this if the user is already scrolled to bottom, else leave alone.
        if (isScrollPosAtBottom || lastScrollPos == 0) {
          new Timer(new Duration(milliseconds: 50), () {
//            chatView.scroller.scrollTop = chatView.scroller.scrollHeight;
          });
        }
      });
      print('[DEBUG] messages.length: ${messages.length}');

//      relistenForItems();

      // If we received less than we tried to load, we've reached the end.
      if (count <= pageSize) reachedEnd = true;

      new Timer(new Duration(seconds: 1), () {
        reloadingContent = false;
      });


    });

//    print('Total count: $totalCount');
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
    .startAt(priority: startAt)
    .endAt(priority: endAt);

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) {
      Map newItem = e.snapshot.val();
      newItem['id'] = e.snapshot.name;

      // If we already have the item, get out of here.
      var existingItem = messages.firstWhere((i) => i['id'] == e.snapshot.name, orElse: () => null);
      if (existingItem != null) return;

      // Insert each new item into the list.
      insertMessage(newItem);

      // Wait for the message to come in over the network, then set scroll position to new bottom.
      // Only do this if the user is already scrolled to bottom, else leave alone.
      print('''
      isScrollPsAtBottom: $isScrollPosAtBottom
      lastScrollPos: $lastScrollPos
      ''');
      if (isScrollPosAtBottom || lastScrollPos == 0) {
        new Timer(new Duration(milliseconds: 50), () {
//          chatView.scroller.scrollTop = chatView.scroller.scrollHeight;
        });
      }
    });

    // Listen for changed items.
    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
      Map currentData = messages.firstWhere((i) => i['id'] == e.snapshot.name);
      Map newData = e.snapshot.val();

      Future processData = new Future.sync(() {
        // First pre-process some things.
        if (newData['createdDate'] != null) newData['createdDate'] = DateTime.parse(newData['createdDate']);
        if (newData['updatedDate'] != null) newData['updatedDate'] = DateTime.parse(newData['updatedDate']);
      }).then((_) {
        // Now that new data is pre-processed, update current data.
        newData.forEach((k, v) => currentData[k] = v);
      });
    });
  }

  /**
   * Prepare the message and insert it into the observed list.
   */
  void insertMessage(Map message) {
    // Find the index of the item with the closest updated date.
    indexOfClosestItemByDate(date) {
      for (var message in messages) {
        if ((message['updatedDate'] as DateTime).isAfter(date)) return messages.indexOf(message);
      }
    }

    // If no updated date, use the created date.
    // TODO: We assume createdDate is never null!
    if (message['updatedDate'] == null) {
      message['updatedDate'] = message['createdDate'];
    }

    // The live-date-time element needs parsed dates.
    message['updatedDate'] = DateTime.parse(message['updatedDate']);
    message['createdDate'] = DateTime.parse(message['createdDate']);

    var index = indexOfClosestItemByDate(message['updatedDate']);

    // Insert the message at the bottom of the current list, or at a given index.
    messages.insert(index == null ? messages.length : index, toObservable(message));
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadMessagesByPage();
  }
}