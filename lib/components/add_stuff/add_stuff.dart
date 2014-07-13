import 'package:polymer/polymer.dart';
//import 'package:core_elements/core_overlay.dart';
//import '../widgets/dialog/dialog.dart';

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();
  toggleOverlay() {
    //CoreOverlay addStuffOverlay = querySelector('#add-stuff-overlay');
    //CoreOverlay addStuffOverlay = this.shadowRoot.querySelector('#add-stuff-overlay');
    //print(addStuffOverlay);

    $['add-stuff-overlay'].toggle();
    //addStuffOverlay.toggle();
  }


}

