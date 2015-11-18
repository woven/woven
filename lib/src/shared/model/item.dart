library shared.model.item;

class Item {
  String id;
  String user;
  String type;
  int priority; // For sorting in Firebase.
  String usernameForDisplay;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();
}
