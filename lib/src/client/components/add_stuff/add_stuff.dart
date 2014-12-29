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
  List validShareToOptions = ['miamitech', 'wynwood', 'woven', 'thelab', 'wyncode']; // TODO: Fixed for now, change later.

  CoreOverlay get overlay => $['overlay'];

  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('add-stuff');

  /**
   * Toggle the overlay.
   */
  toggleOverlay() {
    overlay.toggle();
  }

  /**
   * Populate the share to field intelligently.
   */
  handleOpen() {
    // Add the current community to the share to field.
    String shareTo = theData['share-to'];
    shareTo.replaceAll(r',[\s]+', ',');
    List shareTos = (!shareTo.isEmpty) ? shareTo.trim().split(',') : [];

    if (app.community != null && (!shareTos.contains(app.community.alias.trim()) || shareTos.isEmpty)) shareTos.add(app.community.alias.trim());
    theData['share-to'] = shareTos.join(',').trim().toString();

    // Focus the subject field.
    CoreInput subjectInput = elRoot.shadowRoot.querySelector('#subject');
    subjectInput.focus();
  }

  /**
   * Grow and shrink the input.
   *
   * Responds to key-press event.
   */
  resizeInput(Event e, detail, CoreInput target) {
    // Not working at the moment.
    return;

    e.stopPropagation();

    Element textarea = target.shadowRoot.querySelector("textarea");

    // Reset height on every press, so we can get true scrollHeight below.
    textarea.style.height = "0px";

    // We set this here, as it's not reading it properly from CSS.
    target.style.lineHeight = "16px";

    // Parse the textarea's height as an int so we can play w/ it.
    var elHeight = textarea.clientHeight;

    if (textarea.scrollHeight > elHeight) elHeight = textarea.scrollHeight;
    textarea.style.height = "${elHeight}px";
  }

  /**
   * Add an item.
   */
  addItem(Event e) {
    e.preventDefault();

    String subject = theData['subject'];
    String body = theData['body'];
    String shareTo = theData['share-to'];

    // Validate share tos.
    if (shareTo.trim().isEmpty) {
      window.alert("You haven't tagged a community.");
      return false;
    }

    var shareTos = shareTo.trim().split(',');
    List invalidShareTos = [];

    shareTos.forEach((e) {
      var community = e.trim();
      if (!validShareToOptions.contains(community)) {
        invalidShareTos.add(community);
      }
    });

    if (invalidShareTos.length > 0) {
      window.alert("You've tagged an invalid community.\n\nInvalid: ${invalidShareTos.join(', ')}");
      return false;
    }

    // Validate other stuff.
    if (subject.trim().isEmpty) {
      window.alert("Your subject is empty.");
      return false;
    }

    if (body.trim().isEmpty) {
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

    // Handle the share to field.
    if (theData['share-to'] == null) {}

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
      DateTime startDateTime = new DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
      int eventPriority = startDateTime.millisecondsSinceEpoch;
      (item as EventModel)
        ..startDateTime = startDateTime
        ..startDateTimePriority = eventPriority
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
    setItem(db.Firebase itemRef) {
      // Use a priority so Firebase sorts. Use a negative so latest is at top.
      // TODO: Beef this up in case items have same exact timestamp.
      DateTime time = DateTime.parse("$now");
      var priority = time.toUtc().millisecondsSinceEpoch;

      // Update the main item, then...
      itemRef.setWithPriority(encodedItem, -priority).then((e) {
        var item = id.name;

        // Loop over all communities shared to.
        shareTos.forEach((e) {
          var community = e.trim();
          // Add to items_by_community.
          root.child('/items_by_community/' + community + '/' + item)
            ..setWithPriority(encodedItem, -priority);

          // Only in the main /items location, store a simple list of its parent communities.
          root.child('/items/' + item + '/communities/' + community)
            ..set(true);

          // Update the community itself.
          root.child('/communities/' + community).update({
              'updatedDate': '$now'
          });

          // Add to items_by_community_by_type.
          var itemsByTypeRef = root.child('/items_by_community_by_type/' + community + '/$selectedType/' + item);

          // Use a priority based on the start date/time when storing the event in items_by_community_by_type.
          if (selectedType == 'event') {
            // Combine the separate date and time fields into one DateTime object.
            DateTime date = parseDate(theData['event-start-date']);
            DateTime time = parseTime(theData['event-start-time']);
            DateTime startDateTime = new DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();

            var eventPriority = startDateTime.millisecondsSinceEpoch;

            itemsByTypeRef.setWithPriority(encodedItem, eventPriority);

          } else {
            itemsByTypeRef.setWithPriority(encodedItem, -priority);
          }
        });
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

    if (app.community != null) app.selectedPage = 0;
    app.router.dispatch(url: (app.community != null) ? '/${app.community.alias}' : '/');
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
    if (app.community != null) {
      theData['share-to'] = app.community.alias;
    }

    CoreSelector type = $['content-type'];
    type.addEventListener('core-select', (e) {
      selectedType = type.selected;
    });
  }
}