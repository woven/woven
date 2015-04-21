library safe_html;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";

@CustomTag("safe-html")
class SafeHtml extends PolymerElement  {
  @published NodeValidator validator = new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new DefaultUriPolicy());

  SafeHtml.created() : super.created();

  addFragment() {
    DivElement container = $['container'];
    String fragment =  this.text;
    container.setInnerHtml(fragment,
      validator: validator); // Set the fragment in a safe way.
    this.text = ""; // Clear the original fragment passed to the element.
  }

  attached() {
    addFragment();
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