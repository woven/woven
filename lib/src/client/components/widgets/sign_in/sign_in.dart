import 'package:polymer/polymer.dart';
import 'package:woven/src/client/app.dart';

@CustomTag('sign-in')
class SignIn extends PolymerElement {
  @published App app;
  @published String message = "Please sign in.";

  SignIn.created() : super.created();

  void signInWithFacebook() {
    app.signInWithFacebook();
  }
}