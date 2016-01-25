/// Deploy the (client-side) app safely.
///
/// This builds changes to a new directory, then swaps directory
/// names so that we continue serving with near-zero downtime.
///
/// See https://goo.gl/rdHHrP.
import 'dart:io';

main() async {
  print('Running `pub build`...');

  await Process.run('pub', ['build']);

  print('Swapping directories...');

  new Directory('deploy/web').createSync(recursive: true);

  var deployDir = new Directory('deploy/web');
  var buildDir = new Directory('build/web');
  var oldDir = deployDir.renameSync('deploy/web_old');

  buildDir.renameSync('deploy/web');
  oldDir.deleteSync(recursive: true);

  print('''

And we\'re live!

(Don\'t forget to restart the server if anything changed there.)
''');
}
