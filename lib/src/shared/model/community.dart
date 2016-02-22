library community_model;

import '../util.dart' as util;
import 'package:observe/observe.dart';

class CommunityModel extends Observable {
  @observable String id;
  @observable String alias;
  @observable String name;
  @observable String shortDescription;
  @observable DateTime createdDate;
  @observable DateTime updatedDate;
  @observable int starCount = 0;
  @observable bool disabled;
  @observable bool starred = false;

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
