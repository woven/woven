library uri_preview;

import 'dart:async';
import "dart:html";

import "package:polymer/polymer.dart";
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';

@CustomTag("uri-preview")
class UriPreviewElement extends PolymerElement  {
  @published String previewId = '';
  @published App app;
  @observable Map preview;

  db.Firebase get f => app.f;

  UriPreviewElement.created() : super.created();

  getPreview() {
    if (previewId != null) {
      f.child('/uri_previews/$previewId').onValue.listen((e) {
        Map previewData = e.snapshot.val();
        preview = previewData;
        // Prepare a shortened teaser.
        preview['teaser'] = InputFormatter.createTeaser(preview['teaser'], 80);
        // Prepare the full path to the image.
        preview['image'] = (preview['imageSmallLocation'] != null) ? '${app.cloudStoragePath}/${preview['imageSmallLocation']}' : null;
        // Prepare the domain name.
        var uriHost = Uri.parse(preview['uri']).host;
        preview['uri_host'] = uriHost.substring(uriHost.lastIndexOf(".", uriHost.lastIndexOf(".") - 1) + 1);
      });
    }
  }

  /**
   * Stop the link click from also firing other events.
   */
  stopPropagation(Event e) {
    e.stopPropagation();
  }

  previewIdChanged() {
    getPreview();
  }

  attached() {
    getPreview();
  }
}