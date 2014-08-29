import 'dart:html';
import 'package:polymer/polymer.dart';
//export 'package:polymer/init.dart';


// HACK until we fix code gen size. This doesn't really fix it,
// just makes it better.
//@MirrorsUsed(override: '*')
//import 'dart:mirrors';

main() => initPolymer();

@initMethod
init() => Polymer.onReady.then((_) {
  //
});
