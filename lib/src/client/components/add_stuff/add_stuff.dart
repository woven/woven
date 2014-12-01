library add_stuff;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_selector.dart';
import 'package:woven/src/shared/model/item.dart';
import 'package:woven/src/shared/model/event.dart';
import 'package:woven/src/shared/model/news.dart';
import 'package:intl/intl.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/shared/routing/routes.dart';

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();

  @published App app;
  @published bool opened = false;
  @observable var selectedType;
  @observable Map theData = toObservable({});

  CoreOverlay get overlay => $['overlay'];

  /**
   * Toggle the overlay.
   */
  toggleOverlay() {
    overlay.toggle();
//    name.focus(); //Doesn't work
  }

  /**
   * Add an item.
   */
  addItem(Event e) {
    e.preventDefault();

    String subject = theData['subject'];
    String body = theData['body'];

    if (subject.trim().isEmpty || body.trim().isEmpty) {
      window.alert("Your message is empty.");
      return false;
    }

    if (selectedType == "event") {
      if (parseDate(theData['event-start-date']) == null) {

        window.alert("That's not a valid start date. Ex: " + new DateFormat("M/dd/yyyy").format(new DateTime.now()));
        return false;
      }
      if (parseTime(theData['event-start-time']) == null) {

        window.alert("That's not a valid start time. Ex: " + new DateFormat("h:mm a").format(new DateTime.now()) + ', ' + new DateFormat("h a").format(new DateTime.now()));
        return false;
      }
    }

    _isValidUrl(String url) {
      if (url.contains("http://") || url.contains("https://") || url.contains("www.")) {
        return true;
      } else {
        return false;
      }
    }

    if (theData['url'] != null && _isValidUrl(theData['url']) == false) {
      window.alert("That's not a valid URL.");
      return false;
    }

    var now = new DateTime.now().toUtc();

    ItemModel item;
    if (selectedType == 'event') item = new EventModel();
    else if (selectedType == 'news') item = new NewsModel();
    else item = new ItemModel();

    item
      ..user = app.user.username
      ..subject = theData['subject']
      ..type = selectedType
      ..body = theData['body']
      ..createdDate = now
      ..updatedDate = now;

    if (item is EventModel) {
      // Combine the separate date and time fields into one DateTime object.
      DateTime date = parseDate(theData['event-start-date']);
      DateTime time = parseTime(theData['event-start-time']);
      DateTime startDateTime = new DateTime(date.year, date.month, date.day, time.hour, time.minute);
      (item as EventModel)
        ..startDateTime = startDateTime
        ..url = theData['url'];
    }

    if (item is NewsModel) {
      (item as NewsModel)
        ..url = theData['url'];
    }

    var encodedItem = item.encode();

    var root = new db.Firebase(config['datastore']['firebaseLocation']);

    // Save the item, and we'll have a reference to it.
    var id = root.child('/items').push();

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setItem(db.Firebase itemRef) {
      // Use a priority so Firebase sorts. Use a negative so latest is at top.
      // TODO: Beef this up in case items have same exact timestamp.
      DateTime time = DateTime.parse("$now");
      var priority = time.millisecondsSinceEpoch;

      // Update the main item, then...
      itemRef.setWithPriority(encodedItem, -priority).then((e) {
        var item = id.name;

        root.child('/items_by_community/' + app.community.alias + '/' + item)
          ..setWithPriority(encodedItem, -priority);

        // Only in the main /items location, store a simple list of its parent communities.
        root.child('/items/' + item + '/communities/' + app.community.alias)
          ..set(true);

        // Update the community itself.
        root.child('/communities/' + app.community.alias).update({
            'updatedDate': '$now'

        });

        var itemsByTypeRef = root.child('/items_by_community_by_type/' + app.community.alias + '/$selectedType/' + item);

        // Use a priority based on the start date/time when storing the event in items_by_community_by_type.
        if (selectedType == 'event') {
          // Combine the separate date and time fields into one DateTime object.
          DateTime date = parseDate(theData['event-start-date']);
          DateTime time = parseTime(theData['event-start-time']);
          DateTime startDateTime = new DateTime(date.year, date.month, date.day, time.hour, time.minute);

          var eventPriority = startDateTime.millisecondsSinceEpoch;

          itemsByTypeRef.setWithPriority(encodedItem, eventPriority);

        } else {
          itemsByTypeRef.setWithPriority(encodedItem, -priority);
        }
      });
    }

    // Run the above Future using the reference from the initial save above.
    setItem(id);

    // Send a notification email to anybody mentioned in the item.
    var itemId = id.name;
    HttpRequest.request(Routes.sendNotifications.toString() + "?itemid=$itemId");

    overlay.toggle();
    theData['subject'] = "";
    theData['body'] = "";
    // TODO: Reset the selected type too? May be useful not to.

    app.selectedPage = 0;
    app.router.dispatch(url: '/${app.community.alias}');
  }

  updateInput(Event e, var detail, CoreInput sender) {
    if (sender.id == "event-start-date" && sender.inputValue == "") {
//      sender.type = "date";
      sender.inputValue = new DateFormat("M/dd/yyyy").format(new DateTime.now());
    }
    if (sender.id == "event-start-time" && sender.inputValue == "") {
//      sender.type = "time";
      sender.inputValue = new DateFormat("h:mm a").format(new DateTime.now());
    }
  }

  attached() {
    CoreSelector type = $['content-type'];
    type.addEventListener('core-select', (e) {
      selectedType = type.selected;
    });
  }
}