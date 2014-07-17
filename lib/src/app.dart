library application;

import 'package:polymer/polymer.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
}
