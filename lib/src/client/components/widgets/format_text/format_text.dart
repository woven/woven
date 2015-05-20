library format_text;

import 'dart:html';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:emoji/emoji.dart';

import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/routing/router.dart';

@CustomTag("format-text")
class FormatText extends PolymerElement {
  @published Router router;
  @published String text;

  NodeValidator validator = new NodeValidatorBuilder()
    ..allowElement('a', attributes: ['on-click'])
    ..allowHtml5(uriPolicy: new DefaultUriPolicy())
    ..allowImages(new DefaultUriPolicy());

  var sanitizer = new HtmlEscape(HtmlEscapeMode.ELEMENT);

  FormatText.created() : super.created();

  format() {
    return replaceEmojiCodesWithGlyphs(
      InputFormatter.formatMentions(
        InputFormatter.linkify(
          sanitizer.convert(replaceEmoticonsWithEmojiCodes(text)), internalHost: config['server']['domain']
        )
      )
    );
  }

  update() {
    Element container = this.shadowRoot.querySelector('#container');
    this.injectBoundHtml(format(), validator: validator, element: container);
  }

  attached() {
    super.attached();
    update();
  }

  textChanged() => update();

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