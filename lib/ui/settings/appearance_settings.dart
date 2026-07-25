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
                  trailing: DropdownButton<int>(
                    value: settings.defaultTab,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value != null) {
                        settingsBloc.setDefaultTab(value);
                      }
                    },
                    items: [
                      DropdownMenuItem(value: 0, child: Text(L.of(context)!.home)),
                      DropdownMenuItem(value: 1, child: Text(L.of(context)!.discover)),
                      DropdownMenuItem(value: 2, child: Text(L.of(context)!.my_tab)),
                    ],
                  ),
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
}
