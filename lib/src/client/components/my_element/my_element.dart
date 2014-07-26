import 'package:polymer/polymer.dart';

@CustomTag('my-element')
class MyElement extends PolymerElement {
  @published String name = 'Some default';
  MyElement.created() : super.created();
}