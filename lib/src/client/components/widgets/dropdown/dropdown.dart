@HtmlImport('dropdown.html')

library client.components.widgets.dropdown;

import 'dart:html';

import 'package:polymer/polymer.dart';

import 'package:core_elements/core_icon.dart';

@CustomTag('x-dropdown')
class XDropdown extends PolymerElement {
  @published bool opened = false;
  @published bool autoCloseDisabled = false;
  @published bool autoFocusDisabled = false;

  XDropdown.created() : super.created();

  open() => this.style.display = 'block';

  close () => this.style.display = 'none';

  void windowClick(e) {
    e.preventDefault();
    e.stopPropagation();

    close();
  }

  void dropdownClick(Event e) {
    e.stopPropagation();

    // TODO: This prevents the menu item's on-tap from firing.
    // Comment it out and it works better.
    close();
  }


  attached() {
    window.onTouchStart.listen(windowClick);
    window.onMouseDown.listen(windowClick);

    this.onTouchStart.listen(dropdownClick);
    this.onMouseDown.listen(dropdownClick);

  }
}