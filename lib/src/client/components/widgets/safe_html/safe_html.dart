library safe_html;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";

import 'package:woven/src/client/uri_policy.dart';

@CustomTag("safe-html")
class SafeHtml extends PolymerElement  {
  @published NodeValidator validator = new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy()); // TODO: How to make the policy generic?

  SafeHtml.created() : super.created();

  addFragment() {
    DivElement container = $['container'];
    String fragment =  this.text;
    container.setInnerHtml(fragment, // Set the fragment in a safe way.
      validator: validator);
    this.text = ""; // Clear the original fragment passed to the element.
  }

  attached() {
    addFragment();
  }
}