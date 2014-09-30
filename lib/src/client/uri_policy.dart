import 'dart:html';

class ItemUrlPolicy implements UriPolicy {
  ItemUrlPolicy();

  RegExp regex = new RegExp(r'(?:http://|https://|//)?.*');

  bool allowsUri(String uri) {
    return regex.hasMatch(uri);
  }
}