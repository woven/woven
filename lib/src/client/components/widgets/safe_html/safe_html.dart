library safe_html;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";

import 'package:woven/src/client/uri_policy.dart';

@CustomTag("safe-html")
class SafeHtml extends PolymerElement  {
  @published NodeValidator validator = new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  SafeHtml.created() : super.created();

  addFragment() {
    ContentElement content = shadowRoot.querySelector('content');
    var contentNodes = content.getDistributedNodes();
    String html = '';
    contentNodes.forEach((node) {
      html = (html.isEmpty) ? "$node" : "$html$node";
    });
    this.text = '';
    content.setInnerHtml(html,
    validator: validator);
  }

  attached() {
    addFragment();
  }
}