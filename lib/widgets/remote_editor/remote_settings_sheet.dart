import 'package:flutter/material.dart';
import 'package:irblaster_controller/l10n/l10n.dart';
import 'package:irblaster_controller/widgets/remote_editor/remote_editor_draft.dart';
import 'package:irblaster_controller/utils/remote_grid_layout.dart';
import 'package:irblaster_controller/widgets/remote_editor/remote_layout_picker.dart';

class RemoteSettingsResult {
  const RemoteSettingsResult({
    required this.name,
    required this.layoutStyle,
    this.gridLayout,
  });

  final String name;
  final RemoteLayoutStyle layoutStyle;
  final RemoteGridLayout? gridLayout;
}

class RemoteSettingsSheet extends StatefulWidget {
  const RemoteSettingsSheet({
    super.key,
    required this.initialName,
    required this.initialLayoutStyle,
    this.initialGridLayout,
  });

  final String initialName;
  final RemoteLayoutStyle initialLayoutStyle;
  final RemoteGridLayout? initialGridLayout;

  @override
  State<RemoteSettingsSheet> createState() => _RemoteSettingsSheetState();
}

class _RemoteSettingsSheetState extends State<RemoteSettingsSheet> {
  late final TextEditingController _nameController;
  late RemoteLayoutStyle _layoutStyle;
  RemoteGridLayout? _gridLayout;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _layoutStyle = widget.initialLayoutStyle;
    _gridLayout = widget.initialGridLayout;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    Navigator.of(context).pop(
      RemoteSettingsResult(
        name: _nameController.text.trim().isEmpty
            ? l10n.untitledRemote
            : _nameController.text.trim(),
        layoutStyle: _layoutStyle,
        gridLayout: _gridLayout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SingleChildScrollView(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editRemote,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.remoteName,
              hintText: l10n.remoteNameHint,
            ),
          ),
          const SizedBox(height: 16),
          RemoteLayoutPicker(
            style: _layoutStyle,
            grid: _gridLayout,
            onChanged: (style, grid) => setState(() {
              _layoutStyle = style;
              _gridLayout = grid;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.done),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
