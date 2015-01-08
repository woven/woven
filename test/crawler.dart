import 'package:woven/src/shared/crawler_util.dart';

main() {
  // Test crawler functionality.
  List testUris = [
      'http://www.cnn.com/2014/10/06/opinion/sahlberg-finland-education/index.html',
      'http://miamiherald.typepad.com/the-starting-gate/2015/01/entrepreneurship-datebook.html',
      'http://www.meetup.com/wyncode/events/219551937/'
    ];
  CrawlerUtil crawler = new CrawlerUtil();
  testUris.forEach((String uri) {
    crawler.getPreview(Uri.parse(uri)).then((UriPreview preview) {
      print(preview.title);
      print(preview.teaser);
      print(preview.image);
      print('---');
    });
  });
}