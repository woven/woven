library community_model_server;

import 'package:woven/src/shared/model/community.dart' as shared;
import 'package:woven/src/shared/model/user.dart';
import '../firebase.dart';
import 'dart:async';

class CommunityModel extends shared.CommunityModel {
  /**
   * Get the participants (users) for a given community.
   *
   * Returns a list of user objects.
   */
  static Future<List<UserModel>> getCommunityParticipants(String community) {
    return Firebase.get('/users_who_starred/community/$community.json')
    .then((Map response) => (response != null) ? Future.wait(response.keys.map(usernameToUser)) : null);
  }

  /**
   * Get a list of users for each community.
   *
   * Returns a list of maps, each with a community object and a corresponding list of user objects.
   */
  static Future getCommunitiesWithUsers() {
    return getCommunities().then((List<CommunityModel> communities) {
      return Future.wait(communities.map((CommunityModel community) {
        return getCommunityParticipants(community.alias).then((List users) {
          return {'community': community, 'users': users};
        });
      }));
    });
  }

  /**
   * Get a specific user's basic information.
   *
   * Returns a user object.
   */
  static Future<UserModel> usernameToUser(username) => Firebase.get('/users/$username.json').then(UserModel.decode);

  /**
   * Get all communities, except disabled.
   *
   * Returns a list of community objects.
   */
  static Future<Iterable<CommunityModel>> getActiveCommunities() =>
  getCommunities().then((Iterable cs) => cs.where((c) => !c.disabled));

  /**
   * Get all communities.
   *
   * Returns a list of community objects.
   */
  static Future<Iterable<CommunityModel>> getCommunities() =>
  Firebase.get('/communities.json').then((Map data) => data.values.map(shared.CommunityModel.decode));


//  static Future<Iterable<CommunityModel>> getCommunities() =>
//  Firebase.get('/communities.json').then((Map data) => data.values
//  .map(shared.CommunityModel.decode)
//  .where((c) => !c.disabled)
//  );

//  static Future<List<CommunityModel>> getCommunities() {
//    List<CommunityModel> communities = [];
//    return Firebase.get('/communities.json').then((Map response) {
//      response.values.forEach((Map communityMap) {
//        CommunityModel community = shared.CommunityModel.decode(communityMap);
//        // Ignore disabled communities.
//        if (community.disabled) return;
//        communities.add(community);
//      });
//      return communities;
//    });
//  }
}
