import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/components/page/woven_app/woven_app.dart' show showToastMessage;

import 'dart:convert';
import 'package:crypto/crypto.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('people-list')
class PeopleList extends PolymerElement with Observable {
  @published App app;
  @published MainViewModel viewModel;

  PeopleList.created() : super.created();

  InputElement get subject => $['subject'];

  void selectUser(Event e, var detail, Element target) {
    var selectedUser = target.dataset['user'];
    app.showMessage("More about $selectedUser coming soon!", "important");
    // TODO: User profiles, routes, etc.
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    app.pageTitle = "People";
  }

  detached() {
  }
}
