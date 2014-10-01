library safe_html;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";

import 'package:woven/src/client/uri_policy.dart';

@CustomTag("safe-html")
class SafeHtml extends PolymerElement  {

  SafeHtml.created() : super.created();

  NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  addFragment() {
    ContentElement content = shadowRoot.querySelector('content');
    var contentNodes = content.getDistributedNodes();
    var html = "";
    contentNodes.forEach((node) {
      html = "$html$node";
    });

    this.children.clear();
    content.setInnerHtml(html,
    validator: nodeValidator);
  }

  attached() {
    addFragment();
  }
}