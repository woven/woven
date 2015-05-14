library shared.model.item;

class Item {
  String id;
  String user;
  String type;
  String usernameForDisplay;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();

  Item(this.id, this.user, this.usernameForDisplay); // TODO: Have to put all fields here?
}