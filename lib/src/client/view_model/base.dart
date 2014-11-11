library base_view_model;

import 'dart:async';

class BaseViewModel {
  int lastScrollPos = 0;

  BaseViewModel();

  Completer onLoadCompleter = new Completer();
  Future get onLoad => onLoadCompleter.future;
}