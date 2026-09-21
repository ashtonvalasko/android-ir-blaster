/// Searches display names without changing the database identifiers they return.
class DbCatalogSearch {
  DbCatalogSearch(List<String> names)
      : _entries = [for (final name in names) (name, _normalize(name))];

  final List<(String, String)> _entries;
  static final _separators = RegExp(r'[\s\-_./()]');

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(_separators, '');

  List<String> search(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return [for (final entry in _entries) entry.$1];
    final words = query
        .trim()
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((word) => word.isNotEmpty)
        .toList();
    final ranked = List.generate(4, (_) => <String>[]);
    for (final (name, key) in _entries) {
      if (key == normalized) {
        ranked[0].add(name);
      } else if (key.startsWith(normalized)) {
        ranked[1].add(name);
      } else if (key.contains(normalized)) {
        ranked[2].add(name);
      } else if (words.every(key.contains)) {
        ranked[3].add(name);
      }
    }
    return ranked.expand((group) => group).toList();
  }
}
