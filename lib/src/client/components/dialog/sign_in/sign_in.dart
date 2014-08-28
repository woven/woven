import 'package:polymer/polymer.dart';

@CustomTag('sign-in')
class SignInDialog extends PolymerElement {
  @published bool opened = false;

  SignInDialog.created() : super.created();

  toggle() {
    $['overlay'].toggle();
  }
}