library uri_preview;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';

@CustomTag("uri-preview")
class UriPreviewElement extends PolymerElement  {
  @published String id = '';
  @observable Map preview;
  var f = new Firebase(config['datastore']['firebaseLocation']);

  UriPreviewElement.created() : super.created();

  getPreview() {
    if (id != null) {
      f.child('/uri_previews/$id').onValue.listen((e) {
        Map previewData = e.snapshot.val();
        preview = previewData;
      });
    }
  }

  idChanged() {
    getPreview();
  }

  attached() {
    getPreview();
  }
}