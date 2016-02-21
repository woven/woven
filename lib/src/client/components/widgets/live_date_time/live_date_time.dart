@HtmlImport('live_date_time.html')

library components.widgets.live_date_time;

import 'dart:html';
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:polymer/polymer.dart';

@CustomTag('live-date-time')
class LiveDateTime extends PolymerElement {
  @observable String formattedValue;

  @published DateTime value;
  @observable DateTime toValue;
  @published var formatter;
  @published bool stripAgo = false;

  var subs = [];

  attached() {
    update();
  }

  detached() {
    subs.forEach((sub) => sub.cancel());
    subs.clear();
  }

  update() {
    if (value is DateTime) formattedValue = formatter(value);

    if (stripAgo && formattedValue != null) formattedValue = formattedValue.replaceAll(' ago', '');

    if (value == null) return;

    var secondsUntilUpdate = 1;
    var diff = value.difference(new DateTime.now());

    var seconds = diff.inSeconds.abs();
    if (seconds >= 60) {
      secondsUntilUpdate = 60 - seconds % 60;
    }

    if (secondsUntilUpdate == 0) secondsUntilUpdate = 1;

    subs.add(new Timer(new Duration(seconds: secondsUntilUpdate), () {
      update();
    }));
  }

  LiveDateTime.created() : super.created();
}