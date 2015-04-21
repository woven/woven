import 'package:polymer/polymer.dart';
//export 'package:polymer/init.dart';

@CustomTag('x-dialog')
class XDialog extends PolymerElement {
  @published bool opened = false;
  @published bool autoCloseDisabled = false;
  @published bool autoFocusDisabled = false;

  XDialog.created() : super.created();
  ready() {
    $['overlay'].target = this;
  }

  toggle() {
    $['overlay'].toggle();
  }
}