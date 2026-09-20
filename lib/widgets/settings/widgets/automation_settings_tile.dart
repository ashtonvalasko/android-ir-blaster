import 'package:flutter/material.dart';
import 'package:irblaster_controller/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutomationSettingsTile extends StatefulWidget {
  const AutomationSettingsTile({super.key});

  // The native receiver reads flutter.<key> from FlutterSharedPreferences.
  static const preferenceKey = 'automation_broadcasts_enabled_v1';

  @override
  State<AutomationSettingsTile> createState() => _AutomationSettingsTileState();
}

class _AutomationSettingsTileState extends State<AutomationSettingsTile> {
  SharedPreferences? _prefs;
  bool _enabled = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(AutomationSettingsTile.preferenceKey) ?? false;
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _enabled = enabled;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _busy = true);
    try {
      final saved =
          await _prefs!.setBool(AutomationSettingsTile.preferenceKey, value);
      if (!saved) throw StateError('Preference was not saved');
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.automationSettingsError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: const Icon(Icons.auto_mode_rounded),
      title: Text(context.l10n.automationBroadcastsTitle),
      subtitle: Text(!_busy && _prefs == null
          ? context.l10n.automationSettingsError
          : context.l10n.automationBroadcastsSubtitle),
      value: _enabled,
      onChanged: _busy || _prefs == null ? null : _setEnabled,
    );
  }
}
