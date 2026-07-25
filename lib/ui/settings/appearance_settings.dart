import 'package:anytime/bloc/settings/settings_bloc.dart';
import 'package:anytime/entities/app_settings.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/ui/settings/settings_section_label.dart';
import 'package:anytime/ui/settings/theme_select.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    return StreamBuilder<AppSettings>(
      stream: settingsBloc.settings,
      initialData: settingsBloc.currentSettings,
      builder: (context, snapshot) {
        final settings = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(L.of(context)!.settings_appearance_label),
          ),
          body: ListView(
            children: [
              SettingsDividerLabel(label: L.of(context)!.settings_personalisation_divider_label),
              const ThemeSelectWidget(),
              MergeSemantics(
                child: ListTile(
                  title: Text(L.of(context)!.settings_default_tab_label),
                  subtitle: Text(_tabLabel(context, snapshot.data!.defaultTab)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTabPicker(context, settingsBloc, snapshot.data!.defaultTab),
                ),
              ),
              MergeSemantics(
                child: ListTile(
                  title: Text(L.of(context)!.settings_use_system_font),
                  subtitle: Text(L.of(context)!.settings_use_system_font_subtitle),
                  trailing: Switch.adaptive(
                    value: settings.useSystemFont,
                    onChanged: (value) => settingsBloc.setUseSystemFont(value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  String _tabLabel(BuildContext context, int tab) {
    switch (tab) {
      case 0: return L.of(context)!.home;
      case 1: return L.of(context)!.discover;
      case 2: return L.of(context)!.my_tab;
      default: return '';
    }
  }
  void _showTabPicker(BuildContext context, SettingsBloc bloc, int current) {
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(L.of(context)!.settings_default_tab_label,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            RadioGroup<int>(
              groupValue: current,
              onChanged: (v) {
                bloc.setDefaultTab(v!);
                Navigator.pop(ctx);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(value: 0, title: Text(L.of(context)!.home)),
                  RadioListTile<int>(value: 1, title: Text(L.of(context)!.discover)),
                  RadioListTile<int>(value: 2, title: Text(L.of(context)!.my_tab)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
