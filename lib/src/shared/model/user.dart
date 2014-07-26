library user_model;

class UserModel {
  String username;
  String firstName;
  String lastName;
  String location;
  String facebookId;
  String email;

  Map encode() {
    return {
      "username": username,
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "facebookId": facebookId,
      "location": location
    };
  }

  static UserModel decode(Map data) {
    return new UserModel()
      ..firstName = data['firstName']
      ..lastName = data['lastName']
      ..username = data['username']
      ..email = data['email']
      ..facebookId = data['facebookId']
      ..location = data['location'];
  }
}
