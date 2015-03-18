library linkify_text;

import 'dart:async';
import "dart:html";

import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/regex.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/routing/router.dart';

import 'package:polymer/polymer.dart';

@CustomTag("linkify-text")
class LinkifyText extends PolymerElement {
  @published Router router;

  NodeValidator validator = new NodeValidatorBuilder()
    ..allowElement('a', attributes: ['on-click'])
    ..allowHtml5(uriPolicy: new DefaultUriPolicy());

  LinkifyText.created() : super.created();

  String linkify() {
    if (this.text == null) text = '';

    text = this.text.replaceAllMapped(new RegExp(RegexHelper.linkOrEmail), (Match match) {
      var address = match.group(0);
      var label = match.group(0);
      bool isInternal = false;

      var isEmail = address.contains('@') && !address.contains('://');
      if (!isEmail  && address.startsWith('http') == false) address = 'http://$address';
      if (isEmail && address.startsWith('mailto:') == false) address = ' mailto:$address';

      var uri = Uri.parse(address);
      if (uri.host == config['server']['domain']) {
        isInternal = true;
        address = uri.path;
        return '<a href="$address" class="internal" on-click="{{changePage}}">$label</a>';
      }

      return '<a href="$address" target="_blank">$label</a>';
    });

    return text;
  }

  attached() {
    Element container = this.shadowRoot.querySelector('#container');
    this.injectBoundHtml(linkify(), validator: validator, element: container);
  }

  changePage(MouseEvent e) {
    e.stopPropagation();
    router.previousPage = 'lobby';
    router.changePage(e);
  }
}

class DefaultUriPolicy implements UriPolicy {
  DefaultUriPolicy();

  // Allow all external, absolute URLs.
  RegExp regex = new RegExp(r'(?:http://|https://|//)?.*');

  bool allowsUri(String uri) {
    return regex.hasMatch(uri);
  }
}