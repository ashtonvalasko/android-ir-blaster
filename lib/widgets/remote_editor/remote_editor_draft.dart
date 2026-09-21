import 'package:irblaster_controller/utils/remote.dart';
import 'package:irblaster_controller/utils/remote_grid_layout.dart';

enum RemoteLayoutStyle { compact, wide, custom }

class RemoteEditorDraft {
  RemoteEditorDraft({
    this.remoteId,
    required this.name,
    required this.layoutStyle,
    required List<IRButton> buttons,
    this.gridLayout,
  })  : buttons = List<IRButton>.from(buttons),
        _initialName = name,
        _initialLayoutStyle = layoutStyle,
        _initialGridLayout = gridLayout,
        _initialButtons = List<IRButton>.from(buttons);

  factory RemoteEditorDraft.create({
    required String defaultName,
    RemoteLayoutStyle layoutStyle = RemoteLayoutStyle.compact,
    RemoteGridLayout? gridLayout,
  }) {
    return RemoteEditorDraft(
      name: defaultName,
      layoutStyle: layoutStyle,
      gridLayout: gridLayout,
      buttons: const <IRButton>[],
    );
  }

  factory RemoteEditorDraft.fromRemote(Remote remote) {
    return RemoteEditorDraft(
      remoteId: remote.id,
      name: remote.name,
      layoutStyle: remote.gridLayout != null
          ? RemoteLayoutStyle.custom
          : remote.useNewStyle
              ? RemoteLayoutStyle.wide
              : RemoteLayoutStyle.compact,
      buttons: remote.buttons,
      gridLayout: remote.resolvedGridLayout,
    );
  }

  final int? remoteId;
  final String _initialName;
  final RemoteLayoutStyle _initialLayoutStyle;
  final RemoteGridLayout? _initialGridLayout;
  final List<IRButton> _initialButtons;

  String name;
  RemoteLayoutStyle layoutStyle;
  RemoteGridLayout? gridLayout;
  final List<IRButton> buttons;

  bool get useNewStyle => layoutStyle == RemoteLayoutStyle.wide;
  int get buttonCount => buttons.length;

  bool get isDirty {
    if (name != _initialName) return true;
    if (layoutStyle != _initialLayoutStyle) return true;
    if (layoutStyle == RemoteLayoutStyle.custom &&
        (gridLayout == null
            ? _initialGridLayout != null
            : !gridLayout!.sameAs(_initialGridLayout))) {
      return true;
    }
    return !_sameButtons(buttons, _initialButtons);
  }

  RemoteEditorDraft copy() {
    return RemoteEditorDraft(
      remoteId: remoteId,
      name: name,
      layoutStyle: layoutStyle,
      buttons: buttons,
      gridLayout: gridLayout,
    );
  }

  Remote toRemote() {
    return Remote(
      id: remoteId,
      name: name,
      buttons: List<IRButton>.from(buttons),
      useNewStyle: useNewStyle,
      gridLayout: layoutStyle == RemoteLayoutStyle.custom
          ? (gridLayout ?? RemoteGridLayout(columns: 3))
              .reconcile(buttons.map((button) => button.id))
          : null,
    );
  }

  void updateName(String value) {
    name = value;
  }

  void updateLayoutStyle(RemoteLayoutStyle value) {
    layoutStyle = value;
  }

  void replaceButtonAt(int index, IRButton button) {
    final oldId = buttons[index].id;
    buttons[index] = button;
    gridLayout = gridLayout?.copyWith(
      cells: gridLayout!.cells.map((id) => id == oldId ? button.id : id),
    );
  }

  void addButton(IRButton button, {int? cell}) {
    buttons.add(button);
    if (cell != null && gridLayout != null) {
      final cells = gridLayout!.cells.toList();
      cells[cell] = button.id;
      gridLayout = gridLayout!.copyWith(cells: cells);
    }
    _syncGrid();
  }

  void addButtons(Iterable<IRButton> values) {
    buttons.addAll(values);
    _syncGrid();
  }

  void insertButton(int index, IRButton button) {
    buttons.insert(index, button);
    _syncGrid();
  }

  IRButton removeButtonAt(int index) {
    final button = buttons.removeAt(index);
    _syncGrid();
    return button;
  }

  void _syncGrid() {
    gridLayout = gridLayout?.reconcile(buttons.map((button) => button.id));
  }

  static bool _sameButtons(List<IRButton> a, List<IRButton> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameButton(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _sameButton(IRButton a, IRButton b) {
    return a.id == b.id &&
        a.code == b.code &&
        a.rawData == b.rawData &&
        a.frequency == b.frequency &&
        a.image == b.image &&
        a.isImage == b.isImage &&
        a.necBitOrder == b.necBitOrder &&
        a.protocol == b.protocol &&
        _sameProtocolParams(a.protocolParams, b.protocolParams) &&
        a.iconCodePoint == b.iconCodePoint &&
        a.iconFontFamily == b.iconFontFamily &&
        a.iconFontPackage == b.iconFontPackage &&
        a.iconColor == b.iconColor &&
        a.buttonColor == b.buttonColor;
  }

  static bool _sameProtocolParams(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_sameDynamic(entry.value, b[entry.key])) return false;
    }
    return true;
  }

  static bool _sameDynamic(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      return _sameProtocolParams(
        a.map((key, value) => MapEntry('$key', value)),
        b.map((key, value) => MapEntry('$key', value)),
      );
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_sameDynamic(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
