@HtmlImport('dialog.html')

library components.widgets.dialog;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_overlay.dart';

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