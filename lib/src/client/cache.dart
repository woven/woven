library cache;

import '../shared/model/user.dart';
import '../shared/model/community.dart';

class Cache {
  Map<String, UserModel> users = {}; // User models mapped by ID.
  Map<String, CommunityModel> communities = {}; // Community models mapped by alias.
}
