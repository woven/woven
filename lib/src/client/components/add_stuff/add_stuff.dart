library add_stuff;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:convert';
import 'dart:async';
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
import 'package:woven/src/shared/model/uri_preview.dart';

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();

  @published App app;
  @published bool opened = false;
  @observable var selectedType;
  @observable Map formData = toObservable({});
  List validShareToOptions = ['miamitech', 'wynwood', 'woven', 'thelab', 'wyncode', 'ideagarden', 'fiu']; // TODO: Fixed for now, change later.

  CoreOverlay get overlay => $['overlay'];

  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('add-stuff');

  CoreInput get messageInput => elRoot.shadowRoot.querySelector('#message-textarea');

  CoreInput get subjectInput => elRoot.shadowRoot.querySelector('#subject');
  CoreInput get bodyInput => elRoot.shadowRoot.querySelector('#body-textarea');
  CoreInput get shareToInput => elRoot.shadowRoot.querySelector('#share-to');

  CoreInput get eventStartDateInput => elRoot.shadowRoot.querySelector('#event-start-date');
  CoreInput get eventStartTimeInput => elRoot.shadowRoot.querySelector('#event-start-time');
  CoreInput get urlInput => elRoot.shadowRoot.querySelector('#url');

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
    shareToInput.value.replaceAll(r',[\s]+', ',');
    List shareTos = (!shareToInput.value.isEmpty) ? shareToInput.value.trim().split(',') : [];

    if (app.community != null && (!shareTos.contains(app.community.alias.trim()) || shareTos.isEmpty)) shareTos.add(app.community.alias.trim());
    shareToInput.value = shareTos.join(',').trim().toString();

    // Focus the subject field.
//    CoreInput subjectInput = elRoot.shadowRoot.querySelector('#subject');
//    subjectInput.focus(); // TODO: Not working.
  }

  /**
   * Add an item.
   */
  addItem(Event e) {
    e.preventDefault();

    // Validate share tos.
    if (shareToInput.value.isEmpty) {
      window.alert("You haven't tagged a community.");
      return false;
    }

    var shareTos = shareToInput.value.trim().split(',');
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

    if (selectedType == 'message' && messageInput.value.trim().isEmpty) {
      window.alert("Add a message or choose another type.");
      return false;
    }

    if (urlInput != null && !isValidUrl(urlInput.value)) {
      window.alert("That's not a valid URL. Please include http://.");
      return false;
    }

    // Validate other fields only if user selected a type to attach.
    // TODO: Other fields limited to event type for now.
    if (selectedType == 'event') {

      // Validate other stuff.
      if (subjectInput.value.trim().isEmpty) {
        window.alert("The title is empty.");
        return false;
      }

      if (bodyInput.value.trim().isEmpty) {
        window.alert("The description is empty.");
        return false;
      }

      if (selectedType == "event") {
        if (parseDate(eventStartDateInput.value) == null) {

          window.alert("That's not a valid start date. Ex: " + new DateFormat("M/dd/yyyy").format(new DateTime.now()));
          return false;
        }
        if (parseTime(eventStartTimeInput.value) == null) {

          window.alert("That's not a valid start time. Ex: " + new DateFormat("h:mm a").format(new DateTime.now()) + ', ' + new DateFormat("h a").format(new DateTime.now()));
          return false;
        }
      }
    }

    // Handle the share to field.
    if (shareToInput.value == null) {}

    var now = new DateTime.now().toUtc();

    ItemModel item;
    if (selectedType == 'event') item = new EventModel();
    else if (selectedType == 'news') item = new NewsModel();
    else item = new ItemModel();

    item
      ..user = app.user.username
      ..message = (messageInput != null && !messageInput.value.trim().isEmpty) ? messageInput.value : null
      ..subject = (subjectInput != null && !subjectInput.value.trim().isEmpty) ? subjectInput.value : null
      ..type = (selectedType != null) ? selectedType : 'message'
      ..body = (bodyInput != null && !bodyInput.value.trim().isEmpty) ? bodyInput.value : null
      ..createdDate = now
      ..updatedDate = now;

    if (item is EventModel) {
      // Combine the separate date and time fields into one DateTime object.
      DateTime date = parseDate(eventStartDateInput.value);
      DateTime time = parseTime(eventStartTimeInput.value);
      DateTime startDateTime = new DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
      int eventPriority = startDateTime.millisecondsSinceEpoch;
      (item as EventModel)
        ..startDateTime = startDateTime
        ..startDateTimePriority = eventPriority
        ..url = urlInput.value;
    }

    if (item is NewsModel) {
      (item as NewsModel)
        ..url = urlInput.value;
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
      var priority = time.millisecondsSinceEpoch;

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
            DateTime date = parseDate(eventStartDateInput.value);
            DateTime time = parseTime(eventStartTimeInput.value);
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

    // Reference to the item.
    var itemId = id.name;

    // For event and news items, let's get URL previews.
    if (item is EventModel || item is NewsModel) {
      HttpRequest.request(Routes.getUriPreview.toString() + "?itemid=$itemId").then((HttpRequest req) {
        Map response = JSON.decode(req.responseText);
        UriPreview preview = UriPreview.fromJson(response['data']);
        // TODO: Keep this on server side, why do it client side?
//        var previewRef = root.child('/uri_previews').push();
//        previewRef.set(preview.toJson());
      });
    }

    // Send a notification email to anybody mentioned in the item.
    HttpRequest.request(Routes.sendNotifications.toString() + "?itemid=$itemId");

    overlay.toggle();

    // Reset all form fields. Wait a bit for the dialog to close first.
    new Timer(new Duration(seconds: 1), () {
      formData.forEach((k, v) => formData[k] = '');
    });

    // After add, jump to an appropriate page.
    // TODO: Better handle use case where channel you added to isn't the one you're in.
    if (app.community != null) app.selectedPage = 7;
    app.router.dispatch(url: (app.community != null) ? '/${app.community.alias}' : '/');
    app.showMessage('Your ${selectedType == 'message' || selectedType == null ? 'message' : selectedType} was added.');
  }

  updateInput(Event e, var detail, CoreInput sender) {
    if (sender.id == "event-start-date" && sender.value.trim() == "") {
//      sender.type = "date";
      sender.value = new DateFormat("M/dd/yyyy").format(new DateTime.now());
    }

    if (sender.id == "event-start-time" && sender.value.trim() == "") {
//      sender.type = "time";
      sender.value = new DateFormat("h:mm a").format(new DateTime.now());
    }
  }

  attached() {
    if (app.community != null) {
       shareToInput.value = app.community.alias;
    }

    // Update the selectedType var when a type is selected.
    CoreSelector type = $['content-type'];
    type.addEventListener('core-select', (e) {
      selectedType = type.selected;
    });
  }
}