class Item {
  String username;
  String message;
  DateTime date;
  String feedId;

  String toString() => '${username}: ${message} (${date.toString()})';
}