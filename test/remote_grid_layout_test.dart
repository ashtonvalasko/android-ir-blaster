import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/utils/remote.dart';
import 'package:irblaster_controller/utils/remote_grid_layout.dart';
import 'package:irblaster_controller/utils/remotes_io.dart';
import 'package:irblaster_controller/widgets/remote_editor/remote_editor_draft.dart';

IRButton button(String id) => IRButton(
      id: id,
      image: id,
      isImage: false,
      code: 123,
    );

void main() {
  for (final wide in [false, true]) {
    test('legacy layout remains unchanged: wide=$wide', () {
      final remote = Remote.fromJson({
        'id': 1,
        'name': 'TV',
        'useNewStyle': wide,
        'buttons': [button('power').toJson()],
      });
      final draft = RemoteEditorDraft.fromRemote(remote);
      expect(draft.isDirty, isFalse);
      expect(draft.toRemote().useNewStyle, wide);
      expect(draft.toRemote().toJson().containsKey('gridLayout'), isFalse);
    });
  }

  test('JSON round trip preserves positions, shapes and real button count', () {
    final original = Remote(
        name: 'TV',
        buttons: [button('1'), button('0')],
        gridLayout: RemoteGridLayout(
            columns: 3,
            shape: RemoteButtonShape.circle,
            cells: ['1', null, null, null, '0', null]));
    final restored = Remote.fromJson(jsonDecode(jsonEncode(original.toJson())));
    expect(restored.resolvedGridLayout!.sameAs(original.gridLayout), isTrue);
    expect(restored.buttons.length, 2);
    expect(restored.buttons.last.code, 123);
    final draft = RemoteEditorDraft.fromRemote(restored);
    expect(draft.copy().isDirty, isFalse);
    expect(draft.toRemote().gridLayout!.sameAs(original.gridLayout), isTrue);
  });

  test('moves swap cells and never shift neighboring buttons', () {
    final layout = RemoteGridLayout(columns: 3, cells: ['a', 'b', null]);
    expect(layout.swap(0, 2).cells, [null, 'b', 'a']);
    expect(layout.swap(0, 1).cells, ['b', 'a', null]);
    expect(layout.cells, ['a', 'b', null]);
  });

  test('missing and duplicate references cannot hide real commands', () {
    final layout =
        RemoteGridLayout(columns: 3, cells: ['a', 'a', 'missing', null]);
    expect(layout.reconcile(['a', 'b']).cells, ['a', null, null, null, 'b']);
  });

  test('deleting leaves a gap; adding to a chosen cell fills only that cell',
      () {
    final draft = RemoteEditorDraft(
        name: 'TV',
        layoutStyle: RemoteLayoutStyle.custom,
        buttons: [button('a'), button('b')],
        gridLayout: RemoteGridLayout(columns: 3, cells: ['a', null, 'b']));
    draft.removeButtonAt(0);
    expect(draft.gridLayout!.cells, [null, null, 'b']);
    expect(draft.buttonCount, 1);
    draft.addButton(button('c'), cell: 1);
    expect(draft.gridLayout!.cells, [null, 'c', 'b']);
    expect(draft.isDirty, isTrue);
  });

  test('external additions and deletions preserve positioned commands', () {
    final remote = Remote(
        name: 'TV',
        buttons: [button('a'), button('b')],
        gridLayout: RemoteGridLayout(columns: 3, cells: ['a', null, 'b']));
    remote.buttons.removeAt(0);
    remote.buttons.add(button('c'));
    expect(remote.resolvedGridLayout!.cells, [null, null, 'b', 'c']);
  });

  test('ordinary additions fill rows without turning display padding into gaps',
      () {
    final draft = RemoteEditorDraft.create(
        defaultName: 'TV',
        layoutStyle: RemoteLayoutStyle.custom,
        gridLayout: RemoteGridLayout(columns: 3));
    draft.addButton(button('a'));
    expect(draft.gridLayout!.padded().cells, ['a', null, null]);
    draft.addButton(button('b'));
    draft.addButton(button('c'));
    expect(draft.gridLayout!.cells, ['a', 'b', 'c']);
  });

  test('import copies remap positions to new button IDs', () {
    final remote = Remote(
        name: 'TV',
        buttons: [button('a'), button('b')],
        gridLayout: RemoteGridLayout(columns: 3, cells: ['b', null, 'a']));
    final copy = cloneRemotesForImport([remote]).single;
    expect(copy.buttons.first.id, isNot('a'));
    expect(copy.gridLayout!.cells,
        [copy.buttons.last.id, null, copy.buttons.first.id]);
    expect(copy.buttons.map((b) => b.code), [123, 123]);
  });

  test('the backup parser preserves custom layouts before importing a copy',
      () {
    final original = Remote(
        name: 'TV',
        buttons: [button('a'), button('b')],
        gridLayout: RemoteGridLayout(
            columns: 3,
            shape: RemoteButtonShape.circle,
            cells: ['b', null, 'a']));
    final result = analyzeImportedText(
        jsonEncode({
          'schema': 'irblaster.backup',
          'version': 1,
          'remotes': [original.toJson()],
          'macros': [],
        }),
        filename: 'backup.json',
        fallbackRemoteName: 'Remote',
        fallbackButtonLabel: 'Button');
    expect(
        result.remotes.single.resolvedGridLayout!.sameAs(original.gridLayout),
        isTrue);
    final imported = cloneRemotesForImport(result.remotes).single;
    expect(imported.gridLayout!.cells,
        [imported.buttons.last.id, null, imported.buttons.first.id]);
  });

  test('layout-only changes are dirty and undo can restore the clean draft',
      () {
    final draft = RemoteEditorDraft(
        name: 'TV',
        layoutStyle: RemoteLayoutStyle.custom,
        buttons: [button('a')],
        gridLayout: RemoteGridLayout(columns: 3, cells: ['a', null, null]));
    final before = draft.gridLayout!;
    draft.gridLayout = before.addRow();
    expect(draft.isDirty, isTrue);
    expect(draft.gridLayout!.cells.length, 6);
    draft.gridLayout = before;
    expect(draft.isDirty, isFalse);
    draft.gridLayout = before.copyWith(shape: RemoteButtonShape.rectangle);
    expect(draft.isDirty, isTrue);
  });

  test('invalid optional layouts fall back safely and columns are bounded', () {
    expect(RemoteGridLayout.fromJson('bad'), isNull);
    expect(RemoteGridLayout.fromJson({'columns': 'bad'}), isNull);
    final layout = RemoteGridLayout.fromJson({
      'columns': 999,
      'shape': 'unknown',
      'cells': [42, null, 'a']
    })!;
    expect(layout.columns, 6);
    expect(layout.shape, RemoteButtonShape.roundedSquare);
    expect(layout.cells, [null, null, 'a']);
  });
}
