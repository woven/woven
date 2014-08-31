library community_model;

class CommunityModel {
  String id;
  String alias;
  String name;
  String shortDescription;
  String createdDate;
  String updatedDate;

  Map encode() {
    return {
        "alias": alias,
        "name": name,
        "shortDescription": shortDescription,
        "createdDate": createdDate,
        "updatedDate": updatedDate
    };
  }

  static CommunityModel decode(Map data) {
    return new CommunityModel()
      ..alias = data['alias']
      ..name = data['name']
      ..shortDescription = data['shortDescription']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate'];
  }
}
