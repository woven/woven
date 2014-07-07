import 'package:polymer/polymer.dart';

@CustomTag('my-element')
class MyElement extends PolymerElement {
  @observable String owner = 'Daniel';
  MyElement.created() : super.created();
}