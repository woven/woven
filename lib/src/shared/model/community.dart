library community_model;

class CommunityModel {
  String id;
  String alias;
  String name;
  String shortDescription;
  DateTime createdDate;
  DateTime updatedDate;
  int starCount;
  bool disabled;
  bool starred = false;

  static Map toJson(CommunityModel community) {
    return {
        "alias": community.alias,
        "name": community.name,
        "shortDescription": community.shortDescription,
        "createdDate": community.createdDate.toString(),
        "updatedDate": community.updatedDate.toString(),
        "star_count": community.starCount,
        "disabled": community.disabled
    };
  }

  static CommunityModel fromJson(Map data) {
    return new CommunityModel()
      ..alias = data['alias']
      ..name = data['name']
      ..shortDescription = data['shortDescription']
      ..createdDate = DateTime.parse(data['createdDate'])
      ..updatedDate = DateTime.parse(data['updatedDate'])
      ..starCount = data['star_count']
      ..disabled = data['disabled'];
  }
}
