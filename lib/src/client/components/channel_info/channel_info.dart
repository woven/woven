@HtmlImport('channel_info.html')
library components.channel_info;

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';

import 'package:woven/src/client/app.dart';

@CustomTag('channel-info')
class ChannelInfo extends PolymerElement {
  ChannelInfo.created() : super.created();

  @published App app;
  @published bool opened = false;

//  db.Firebase get f => app.f;
//
  CoreOverlay get overlay => $['overlay'];

//  Element get elRoot => document
//      .querySelector('woven-app')
//      .shadowRoot
//      .querySelector('x-main')
//      .shadowRoot
//      .querySelector('add-stuff');

  // Toggle the overlay.
  toggleOverlay() {
    overlay.toggle();
  }

  attached() {
    if (app.debugMode) print('+ChannelInfo');
  }
}
