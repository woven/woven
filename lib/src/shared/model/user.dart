library user_model;

class UserModel {
  String id;
  String username;
  String firstName;
  String lastName;
  String location;
  String facebookId;
  String email;
  String createdDate;
  bool isNew = false;
  bool disabled = false;

  Map encode() {
    return {
      "username": username,
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "facebookId": facebookId,
      "location": location,
      "createdDate": createdDate,
      "disabled": disabled
    };
  }

  static UserModel decode(Map data) {
    return new UserModel()
      ..firstName = data['firstName']
      ..lastName = data['lastName']
      ..username = data['username']
      ..email = data['email']
      ..facebookId = data['facebookId']
      ..location = data['location']
      ..createdDate = data['createdDate']
      ..disabled = data['disabled'];
  }
}
