library safe_html;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";

import 'package:woven/src/client/uri_policy.dart';

@CustomTag("safe-html")
class SafeHtml extends PolymerElement  {
  @published String model;

  NodeValidator nodeValidator;
  bool get applyAuthorStyles => true;
  bool isInitialized = false;

  SafeHtml.created() : super.created() {
    nodeValidator = new NodeValidatorBuilder()
      ..allowCustomElement('A', attributes: ['href']);
  }

  void modelChanged(old) {
    if(isInitialized) {
      _addFragment();
    }
  }

  void _addFragment() {
    var fragment = new DocumentFragment.html(model, validator: nodeValidator);
    $["container"].nodes
      ..clear()
      ..add(fragment);

  }

  @override
  void attached() {
    super.attached();
    Timer.run(() {
      _addFragment();
      isInitialized = true;
    });
  }
}