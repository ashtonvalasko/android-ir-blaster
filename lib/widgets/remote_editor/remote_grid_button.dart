import 'dart:io';
import 'package:flutter/material.dart';
import 'package:irblaster_controller/l10n/icon_picker_names.dart';
import 'package:irblaster_controller/l10n/l10n.dart';
import 'package:irblaster_controller/utils/button_color_accessibility.dart';
import 'package:irblaster_controller/utils/button_label.dart';
import 'package:irblaster_controller/utils/remote.dart';
import 'package:irblaster_controller/utils/remote_grid_layout.dart';
import 'package:irblaster_controller/widgets/remote_editor/remote_custom_grid.dart';

class RemoteGridButton extends StatelessWidget {
  const RemoteGridButton({
    super.key,
    required this.button,
    required this.shape,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final IRButton button;
  final RemoteButtonShape shape;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = button.buttonColor == null ? null : Color(button.buttonColor!);
    final foreground = resolveButtonForeground(bg, cs.onSurface);
    final label = displayButtonLabel(button,
        fallback: context.l10n.buttonFallbackTitle,
        iconFallback: context.l10n.iconFallback,
        iconNameLocalizer: (name) =>
            localizedIconPickerName(context.l10n, name));
    final fallback = Center(
        child: Text(label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground)));
    Widget visual = fallback;
    if (button.iconCodePoint != null) {
      visual = Center(
          child: Icon(
              IconData(button.iconCodePoint!,
                  fontFamily: button.iconFontFamily,
                  fontPackage: button.iconFontPackage),
              size: 28,
              color: button.iconColor == null
                  ? foreground
                  : Color(button.iconColor!)));
    } else if (button.isImage && button.image.isNotEmpty) {
      visual = button.image.startsWith('assets/')
          ? Image.asset(button.image,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback)
          : Image.file(File(button.image),
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
    }
    final border = remoteGridButtonShape(shape);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: resolveButtonBackground(bg, cs.primary.withValues(alpha: 0.20)),
        shape: selected
            ? border.copyWith(side: BorderSide(color: cs.tertiary, width: 3))
            : border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: border,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: ExcludeSemantics(child: visual)),
        ),
      ),
    );
  }
}
