enum RemoteButtonShape { circle, roundedSquare, rectangle }

/// Positions belong to the remote, not to its IR commands. Null cells are gaps.
class RemoteGridLayout {
  RemoteGridLayout({
    required int columns,
    this.shape = RemoteButtonShape.roundedSquare,
    Iterable<String?> cells = const [],
  })  : columns = columns.clamp(1, 6),
        cells = List<String?>.unmodifiable(cells);

  final int columns;
  final RemoteButtonShape shape;
  final List<String?> cells;

  static RemoteGridLayout? fromJson(dynamic value) {
    if (value is! Map || value['columns'] is! int) return null;
    final shape = RemoteButtonShape.values.where(
      (shape) => shape.name == value['shape'],
    );
    return RemoteGridLayout(
      columns: value['columns'] as int,
      shape: shape.isEmpty ? RemoteButtonShape.roundedSquare : shape.first,
      cells: value['cells'] is List
          ? (value['cells'] as List).map((id) => id is String ? id : null)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'shape': shape.name,
        'cells': cells,
      };

  RemoteGridLayout copyWith({
    int? columns,
    RemoteButtonShape? shape,
    Iterable<String?>? cells,
  }) =>
      RemoteGridLayout(
        columns: columns ?? this.columns,
        shape: shape ?? this.shape,
        cells: cells ?? this.cells,
      );

  /// Preserve gaps and positions when buttons are edited outside the studio.
  /// Newly added commands append; they never silently fill intentional gaps.
  RemoteGridLayout reconcile(Iterable<String> buttonIds) {
    final remaining = buttonIds.toSet();
    final resolved = <String?>[
      for (final id in cells) id != null && remaining.remove(id) ? id : null,
      ...remaining,
    ];
    return copyWith(cells: resolved);
  }

  RemoteGridLayout padded() {
    final paddedCells = cells.toList();
    while (paddedCells.length % columns != 0) {
      paddedCells.add(null);
    }
    return copyWith(cells: paddedCells);
  }

  RemoteGridLayout swap(int from, int to) {
    final updated = cells.toList();
    final previous = updated[to];
    updated[to] = updated[from];
    updated[from] = previous;
    return copyWith(cells: updated);
  }

  RemoteGridLayout addRow() => copyWith(
      cells: [...padded().cells, ...List<String?>.filled(columns, null)]);

  RemoteGridLayout remap(Map<String, String> ids) => copyWith(
        cells: cells.map((id) => id == null ? null : ids[id]),
      );

  bool sameAs(RemoteGridLayout? other) {
    if (other == null ||
        columns != other.columns ||
        shape != other.shape ||
        cells.length != other.cells.length) {
      return false;
    }
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != other.cells[i]) return false;
    }
    return true;
  }
}
