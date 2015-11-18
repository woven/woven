class Item {
  String username;
  String message;
  DateTime date;

  String toString() => '${username}: ${message} (${date.toString()})';
}