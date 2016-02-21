library community_model;

import '../util.dart' as util;

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
        "createdDate": util.encode(community.createdDate),
        "updatedDate": util.encode(community.updatedDate),
        "star_count": community.starCount,
        "disabled": community.disabled
    };
  }

  static CommunityModel fromJson(Map data) {
    return new CommunityModel()
      ..alias = data['alias']
      ..name = data['name']
      ..shortDescription = data['shortDescription']
      ..createdDate = (data['createdDate'] != null) ? DateTime.parse(data['createdDate']) : null
      ..updatedDate = (data['updatedDate'] != null) ? DateTime.parse(data['updatedDate']) : null
      ..starCount = data['star_count']
      ..disabled = data['disabled'];
  }
}
