library community_model;

class CommunityModel {
  String id;
  String alias;
  String name;
  String shortDescription;
  String createdDate;
  String updatedDate;
  int starCount;
  bool disabled;

  static Map encode(CommunityModel community) {
    return {
        "alias": community.alias,
        "name": community.name,
        "shortDescription": community.shortDescription,
        "createdDate": community.createdDate,
        "updatedDate": community.updatedDate,
        "star_count": community.starCount,
        "disabled": community.disabled
    };
  }

  static CommunityModel decode(Map data) {
    return new CommunityModel()
      ..alias = data['alias']
      ..name = data['name']
      ..shortDescription = data['shortDescription']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']
      ..starCount = data['star_count']
      ..disabled = data['disabled'];
  }
}
