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

  // *
  // Toggle the overlay.
  // *
  toggleOverlay() {
    overlay.toggle();
//    name.focus(); //Doesn't work
  }

  // *
  // Add an item.
  // *
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
    var id = root.child("/items").push();

    // Set the item in multiple places because denormalization equals speed.
    Future setItem(db.Firebase itemRef) {
      itemRef.set(encodedItem).then((e){
        var nameRef = id.name();
        root.child('/communities/' + app.community.alias + '/items/' + nameRef)
          ..set(encodedItem);
      });
    }

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

