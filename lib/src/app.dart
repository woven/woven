library application;

import 'package:polymer/polymer.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable var pageTitle = "LAB Collective";
  @observable var user = "";
  @observable var firebaseURL = "https://luminous-fire-4671.firebaseio.com";
}
