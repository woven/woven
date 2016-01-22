import 'package:firebase/firebase_io.dart';

import 'package:woven/config/config.dart';

main() async {
  FirebaseClient fb = new FirebaseClient(config['datastore']['firebaseSecret']);
  String fbUrl = config['datastore']['firebaseLocation'];

  var t = new Stopwatch();
  t.start();

  var data = await fb.get(Uri.parse('$fbUrl/users/dave.json'));

  t.stop();
  print(t.elapsedMilliseconds);
  print(data);


  t.reset();
  t.start();

  var data2 = await fb.get(Uri.parse('$fbUrl/users/dave.json'));

  t.stop();
  print(t.elapsedMilliseconds);
  print(data2);
}