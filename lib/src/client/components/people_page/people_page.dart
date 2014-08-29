import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:quiver/iterables.dart';
import 'package:template_binding/template_binding.dart';

@CustomTag('people-page')
class PeoplePage extends PolymerElement with Observable {
  var items = range(50);
  @observable int lastSelected = 0;

  PeoplePage.created() : super.created();

  get pages => $['pages'];

  selectView(e) {
    var i = nodeBind(e.target).templateInstance.model['item'];
    pages.selected = i+1;
    _notify();
  }

  back() {
    this.lastSelected = pages.selected;
    window.console.log(this.lastSelected);
    pages.selected = 0;
    _notify();
  }

  transitionend() {
    this.lastSelected = null;
  }

  // Note: Dart cannot detect a change to core-animated-pages's selected
  // property, so we notify manually.
  _notify() {
    notifyChange(new PropertyChangeRecord(this, #pages, null, null));
  }

}


