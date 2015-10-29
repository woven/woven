import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/feed.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:woven/src/client/infinite_scroll.dart';

/**
 * A list of items.
 */
@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @published App app;
  @published FeedViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

  InboxList.created() : super.created();

  InputElement get subject => $['subject'];

  db.Firebase get f => app.f;

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element.
    var item = viewModel.items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.router.previousPage = app.router.selectedPage;
    app.router.selectedItem = item;

    var str = target.dataset['id'];
    var bytes = UTF8.encode(str);
    var base64 = CryptoUtils.bytesToBase64(bytes);

    app.router.dispatch(url: "/item/$base64");
  }

  toggleLike(Event e, var detail, Element target) {
    e.stopPropagation();

//    if (target.classes.contains("selected")) {
//      target.classes.remove("clicked");
//    } else {
//      target.classes.add("clicked");
//    }

    viewModel.toggleItemLike(target.dataset['id']);
  }

  toggleStar(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.toggleItemStar(target.dataset['id']);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  formatEventDate(DateTime startDate) {
    // TODO: Bring back endDate, currently null.
    return InputFormatter.formatDate(startDate.toLocal(), showHappenedPrefix: true, trimPast: true);
  }

  // Temporary script, about as good a place as any to put it.

  scriptTryPriority() {
//    for (int i = 0; i < 30; i++) {
//      var ref = f.child('/priority_test2').push();
//      var now = new DateTime.now().toUtc();
//      ref.setWithPriority({'createdDate': '$now'}, now.toString());
//    }

    var priority = '2014-10-17 23:54:32.146Z';
    f.child('/priority_test2').startAt(value: priority).limitToFirst(10).onChildAdded.listen((e) {
      print(e.snapshot.val());
      print(e.snapshot.key);
      print(e.snapshot.getPriority());
      priority = e.snapshot.getPriority();
    });
  }

  scriptAddPriorityOnItemsByCommunity() {
    var itemsRef = f.child('/items_by_community/' + app.community.alias);
    var item;

    itemsRef.onChildAdded.listen((e) {
      db.DataSnapshot snapshot = e.snapshot;
      item = snapshot.val();
      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      DateTime time = DateTime.parse(item['updatedDate']);
      var epochTime = time.millisecondsSinceEpoch;
      f.child('/items_by_community/' + app.community.alias + '/' + snapshot.key)
        .setPriority(-epochTime);

      print(e.snapshot.key);
    });
  }

  scriptAddPriorityOnItems() {
    var itemsRef = f.child('/items');
    var item;

    itemsRef.onChildAdded.listen((e) {
      item = e.snapshot.val();
      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      DateTime time = DateTime.parse(item['updatedDate']);
      var epochTime = time.millisecondsSinceEpoch;
      f.child('/items/' + e.snapshot.key)
      .setPriority(-epochTime);
    });
  }

  scriptAddPriorityOnPeople() {
    var itemsRef = f.child('/users');
    var item;

    itemsRef.onChildAdded.listen((e) {
      var item = e.snapshot.val();

      // If no updated date, use the created date.

      DateTime time = DateTime.parse(item['createdDate']);
      var epochTime = time.millisecondsSinceEpoch;
      f.child('/users/' + item['username'])
      .setPriority(-epochTime);

    });
  }


  scriptAddPriorityOnItemsEverywhere() {
    var itemsRef = f.child('/items');
    var item;

    itemsRef.onChildAdded.listen((e) {
      var item = e.snapshot.val();

      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      DateTime time = DateTime.parse(item['updatedDate']);
      var epochTime = time.millisecondsSinceEpoch;
      f.child('/items/' + e.snapshot.key)
      .setPriority(-epochTime);

      itemsRef.child(e.snapshot.key + '/communities').onValue.listen((e2) {
        Map communitiesRef = e2.snapshot.val();
        if (communitiesRef != null) {
          communitiesRef.keys.forEach((community) {
            f.child('/items_by_community/' + community + '/' + e.snapshot.key).setPriority(-epochTime);


            var itemsByTypeRef = f.child('/items_by_community_by_type/' + community + '/' + item['type'] + '/' + e.snapshot.key);

            if (item['type'] == 'event') {
                // Leave events for scriptMakeItemsByCommunityType().
//              var eventPriority;
//              if (item['startDateTime'] != null) {
//                DateTime datetime = DateTime.parse(item['startDateTime']);
//                print('$datetime / ${item['subject']}');
//
//                eventPriority = datetime.millisecondsSinceEpoch;
//              } else {
//                // No startdate.
//                var now = new DateTime.now();
//                DateTime datetime = new DateTime(2012, DateTime.DECEMBER, 12, now.hour, now.second, now.millisecond);
//                print('$datetime / ${item['subject']} / NULL');
//
//                eventPriority = datetime.millisecondsSinceEpoch;
//              }
//              itemsByTypeRef.setPriority(eventPriority);
            } else {
              itemsByTypeRef.setPriority(-epochTime);
            }
          });
        }
      });
    });
  }

  scriptFixStartDateTimeOnItems() {
    // Run this per community.

  }


  scriptMakeItemsByCommunityByType() {
    var itemsRef = f.child('/items_by_community/' + app.community.alias);
    var item;

    itemsRef.onChildAdded.listen((e) {
      item = e.snapshot.val();

      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      DateTime time = DateTime.parse(item['updatedDate']);
      var epochTime = time.millisecondsSinceEpoch;
      var type = item['type'];

      var itemsByTypeRef = f.child('/items_by_community_by_type/' + app.community.alias + '/$type/' + e.snapshot.key);

      if (item['type'] == 'event') {
        var eventPriority;
        DateTime datetime;

        if (item['startDateTime'] != null) {
          DateTime current = DateTime.parse(item['startDateTime']);
          if (!current.isUtc) {
            datetime = new DateTime(current.year, current.month, current.day, current.hour, current.minute, current.second).toUtc();
          } else {
            datetime = new DateTime.utc(current.year, current.month, current.day, current.hour, current.minute, current.second);
          }
          eventPriority = datetime.millisecondsSinceEpoch;
        } else {
          // No startdate. Edge case.
          var now = new DateTime.now();
          datetime = new DateTime(2012, DateTime.DECEMBER, 12, now.hour, now.second, now.millisecond).toUtc();
          eventPriority = datetime.millisecondsSinceEpoch;
        }

        itemsByTypeRef.setWithPriority(item, eventPriority);
        // TODO: Add this to add_stuff.
        itemsByTypeRef.update({
            'startDateTimePriority':'${eventPriority}',
            'startDateTime': '${datetime}'}
        );
      } else {
        itemsByTypeRef.setWithPriority(item, -epochTime);
      }
    });
  }

  scriptUpdateCommentCounts() {
    var itemsRef = f.child('/items');

    itemsRef.onChildAdded.listen((e) {
      var countRef = f.child('/items/' + e.snapshot.key + '/activities/comments');
      var count = 0;
      var item = e.snapshot.val();
      countRef.once('value').then((snapshot) {
        print(snapshot.val());
        print(snapshot.numChildren);
        itemsRef.child(e.snapshot.key + '/comment_count').set(snapshot.numChildren); // TODO: In Progress.

        itemsRef.child(e.snapshot.key + '/communities').onValue.listen((e2) {
          Map communitiesRef = e2.snapshot.val();
          if (communitiesRef != null) {
            communitiesRef.keys.forEach((community) {
              f.child('/items_by_community/' + community + '/' + e.snapshot.key + '/comment_count').set(snapshot.numChildren);
              f.child('/items_by_community_by_type/' + community + '/' + item['type'] + '/' + e.snapshot.key + '/comment_count').set(snapshot.numChildren);
            });
          }
        });
      });
    });
  }

  /**
   * Initializes the infinite scrolling ability.
   */
  initializeInfiniteScrolling() {
    var scroller = app.scroller;
    HtmlElement element = $['content-container'];
    var scroll = new InfiniteScroll(pageSize: 20, element: element, scroller: scroller, threshold: 0);

    subscriptions.add(scroll.onScroll.listen((_) {
//      print("DEBUG: ${viewModel.reloadingContent} // ${viewModel.reachedEnd}");
      if (!viewModel.reloadingContent && !viewModel.reachedEnd) viewModel.paginate();
    }));
  }

  attached() {
    if (app.debugMode) print('+InboxList');

    switch (app.router.selectedPage) {
      case 'events':
        app.pageTitle = 'Events';
        break;
      case 'news':
        app.pageTitle = 'News';
        break;
      case 'announcements':
        app.pageTitle = 'Announcements';
        break;
      default:
        app.pageTitle = 'Feed';
        break;
    }

    initializeInfiniteScrolling();

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
      Timer.run(() {
        app.scroller.scrollTop = viewModel.lastScrollPos;
      });

      // On scroll, record new scroll position.
      subscriptions.add(app.scroller.onScroll.listen((e) {
        viewModel.lastScrollPos = app.scroller.scrollTop;
      }));
    });

//    scriptMakeItemsByCommunityByType(); // Run 1st, for each community.
//    scriptAddPriorityOnItemsEverywhere(); // Run 2nd, may have some issues w/ items manually assigned to multiple communities.
//    scriptUpdateCommentCounts(); // Run 3rd.
//      scriptAddPriorityOnPeople(); // 4.
  // Then, kill empty items in items_by_community.

//    scriptAddPriorityOnItemsByCommunity(); // Deprecated.
//    scriptAddPriorityOnItems(); // Deprecated.

  }

  detached() {
    if (app.debugMode) print('-InboxList');
//    viewModel.lastScrollPos = app.scroller.scrollTop;

    // TODO: If we cancel, how to resume? pause/resume instead?
//    viewModel.childAddedSubscriber.cancel();
//    viewModel.childChangedSubscriber.cancel();
//    viewModel.childMovedSubscriber.cancel();
//    viewModel.childRemovedSubscriber.cancel();

    subscriptions.forEach((subscription) => subscription.cancel());
  }
}
