class Item {
  String username;
  String message;
  DateTime date;

  Item(this.username, this.message, this.date);

  String toString() => '${username}: ${message} (${date.toString()})';
}