library user_picture;

import "dart:html";

import "package:polymer/polymer.dart";

import "package:woven/src/client/app.dart";

@CustomTag("user-picture")
class UserPicture extends PolymerElement {
  @published App app;

  UserPicture.created() : super.created();

}