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

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();
  @published App app;
  @published bool opened = false;

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

    CoreSelector type = $['content-type'];
    CoreInput name = $['name'];
    CoreInput subject = $['subject'];
    CoreInput body = $['body'];

    if (subject.value.trim().isEmpty) {
      window.alert("Your message is empty.");
      return false;
    }

    DateTime now = new DateTime.now().toUtc();

    var item = new ItemModel()
      ..user = name.inputValue
      ..subject = subject.inputValue
      ..type = type.selected
      ..body = body.inputValue
      ..createdDate = now.toString()
      ..updatedDate = now.toString();

    var encodedItem = item.encode();

    var root = new db.Firebase(config['datastore']['firebaseLocation']);

    // Save the item, and we'll have a reference to it.
    var id = root.child('/items').push();

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setItem(db.Firebase itemRef) {
      itemRef.set(encodedItem).then((e){
        var item = id.name();
        root.child('/items_by_community/' + app.community.alias + '/' + item)
          ..set(encodedItem);
        // Only in the main /items location, store a simple list of its parent communities.
        root.child('/items/' + item + '/communities/' + app.community.alias)
          ..set(true);
        // Update the community itself.
        root.child('/communities/' + app.community.alias).update({
            'updatedDate': '$now'
        });
      });
    }

    // Run the above Future using the reference from the initial save above.
    setItem(id);

    overlay.toggle();
    body.value = "";
    subject.value = "";

    app.selectedPage = 0;
  }

  attached() {
    //
  }
}

