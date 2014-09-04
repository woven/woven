import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

@CustomTag('item-preview')
class ItemPreview extends PolymerElement {
  @published App app;
  @observable Map item;

  get formattedBody {
    if (app.selectedItem == null) return '';
    return "${InputFormatter.nl2br(app.selectedItem['body'])}";
  }

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  void getItem() {
    // If there's no app.selectedItem, we probably
    // came here directly, so let's get it.
    print(app.selectedItem);
    if (app.selectedItem == null) {
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(window.location.toString()).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      var decodedItem = UTF8.decode(bytes);

      var f = new db.Firebase(config['datastore']['firebaseLocation'] + '/items/' + decodedItem);

      f.onValue.first.then((e) {
        item = e.snapshot.val();

        // The live-date-time element needs parsed dates.
        item['createdDate'] = DateTime.parse(item['createdDate']);

        // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
        // So we'll add that to our local item list.
        item['id'] = e.snapshot.name();

        app.selectedItem = item;
      }).then((e) {
        HtmlElement body = $['body'];
        body.innerHtml = formattedBody;
      });
    }

    if (app.selectedItem != null) {
      // Trick to respect line breaks.
      HtmlElement body = $['body'];
      body.innerHtml = formattedBody;
    }
  }

  attached() {
    print("+Item");
    getItem();
    app.pageTitle = "";
  }

  detached() {
    //
  }

  ItemPreview.created() : super.created();
}
