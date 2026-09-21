import 'package:flutter/material.dart';
import 'package:irblaster_controller/l10n/l10n.dart';

class IrFinderCooldownControl extends StatelessWidget {
  const IrFinderCooldownControl({
    super.key,
    required this.delayMs,
    required this.onChanged,
  });

  final int delayMs;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${context.l10n.irFinderCooldownMs}: $delayMs',
              style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: delayMs.toDouble().clamp(250, 20000),
            min: 250,
            max: 20000,
            divisions: 395,
            label: '$delayMs ms',
            onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
          ),
        ],
      );
}
