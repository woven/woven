import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:template_binding/template_binding.dart';
import 'package:woven/src/client/components/people_page/people_page.dart';

main() => initPolymer();

@initMethod init() {
  Polymer.onReady.then((_) {
//    templateBind(querySelector('body /deep/ template[is="auto-binding-dart"]')).model = PeoplePage;
  });
}
