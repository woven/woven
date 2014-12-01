import 'package:polymer/polymer.dart';

@CustomTag('sign-in-dialog')
class SignInDialog extends PolymerElement {
  @published bool opened = false;

  SignInDialog.created() : super.created();

  toggle() {
    $['overlay'].toggle();
  }
}