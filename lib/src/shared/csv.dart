library csv;

class Csv {
  static String listToCsv(List<List> entries) {
    var output = '';

    entries.forEach((entry) {
      output = '$output${entry.map((e) => encode(e)).join(',')}\n';
    });

    return output;
  }

  static String encode(item) {
    if (item == null) item = '';

    item = item.toString();

    item.replaceAll('"', '""');

    return '"$item"';
  }
}