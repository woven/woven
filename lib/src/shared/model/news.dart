library news_model;

import 'item.dart';
import 'trait/link.dart';

class NewsModel extends ItemModel with Link {

  Map encode() {
    var data = super.encode();
    data['url'] = (url != null) ? url.toString() : null;
    data['uriPreviewId'] = (uriPreviewId != null) ? uriPreviewId.toString() : null;
    return data;
  }

  // TODO: Can I eliminate/inherit some of this?
  static NewsModel decode(Map data) {
    return new NewsModel()
      ..user = data['user']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']

      ..url = data['url']
      ..uriPreviewId = data['uriPreviewId'];

  }
}