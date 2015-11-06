library rss_item;

class RssItem {
  String title;
  String link;
  String description;
  String language;
  String copyright;
  DateTime publicationDate;
  List<String> categories = [];
  String image;

  String toString() {
    var item = new XmlElement('item');

    if (title != null) {
      var field = new XmlElement('title');
      field.addChild(new XmlText(title));

      item.addChild(field);
    }

    if (link != null) {
      var field = new XmlElement('link');
      field.addChild(new XmlText(link));
      item.addChild(field);
    }

    if (description != null) {
      var field = new XmlElement('description');
      field.addChild(new XmlText(description));
      item.addChild(field);
    }

    if (publicationDate != null) {
      var field = new XmlElement('pubDate');
      field.addChild(new XmlText(publicationDate.toString()));
      item.addChild(field);
    }

    return item.toString();
  }
}