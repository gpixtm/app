import 'localization.dart';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/health_data.dart';
import '../domain/walk_recap.dart';
import 'guidance_text.dart';
import 'walker_profile.dart';

class SettingsView extends StatelessWidget {
  const SettingsView(this.app, {required this.account, super.key});
  final AppController app;
  final VoidCallback account;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const LanguageSelector(),
      const SizedBox(height: 20),
      if (app.guide != null)
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_outlined),
            title: Text(context.l10n.voiceGuidance),
            subtitle: Text(context.l10n.voiceGuidanceInfo),
            value: app.voiceGuidance,
            onChanged: app.setVoiceGuidance,
          ),
        ),
      if (app.profiles != null) WalkerProfileCard(app),
      if (app.health != null)
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.ios_share),
            title: Text(context.l10n.shareHealth),
            subtitle: Text(context.l10n.shareHealthInfo),
            value: app.shareWithHealth,
            onChanged: app.setShareWithHealth,
          ),
        ),
      if (app.recap != null)
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(context.l10n.recapSettings),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.l10n.recapSettingsInfo),
              ),
              for (final item in RecapItem.values)
                CheckboxListTile(
                  dense: true,
                  title: Text(recapItemLabel(context.l10n, item)),
                  value: app.spokenRecap.contains(item),
                  onChanged: app.voiceGuidance
                      ? (spoken) => app.setSpokenRecap(item, spoken == true)
                      : null,
                ),
            ],
          ),
        ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(context.l10n.accountServer),
          subtitle: Text(context.l10n.accountServerInfo),
          trailing: const Icon(Icons.chevron_right),
          onTap: account,
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.watch_outlined),
          title: Text(context.l10n.watchHealthData),
          subtitle: Text(context.l10n.healthBridge),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HealthSettings(
                app.health,
                onAuthorized: app.refreshHealthWeight,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        context.l10n.myData,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      const SizedBox(height: 8),
      Text(context.message(app.syncStatus)),
      Text(context.l10n.syncDataInfo),
      TextButton.icon(
        onPressed: app.busy ? null : app.synchronize,
        icon: const Icon(Icons.sync),
        label: Text(context.l10n.syncNow),
      ),
    ],
  );
}

class HealthSettings extends StatefulWidget {
  const HealthSettings(this.source, {this.onAuthorized, super.key});
  final HealthDataSource? source;

  /// Called after access changes, e.g. to pick up the Health Connect weight.
  final Future<void> Function()? onAuthorized;
  @override
  State<HealthSettings> createState() => _HealthSettingsState();
}

class _HealthSettingsState extends State<HealthSettings>
    with WidgetsBindingObserver {
  HealthAvailability? status;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) refresh();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> refresh() => run(() async {
    status = await widget.source?.status() ?? HealthAvailability.unavailable;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.watchHealth)),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Icon(Icons.watch_outlined, size: 52),
        const SizedBox(height: 16),
        Text(
          context.l10n.yourWatchMeasurements,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(context.l10n.compatibleWatches),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(switch (status) {
              null => context.l10n.checkingHealthConnect,
              HealthAvailability.connected => context.l10n.healthAuthorized,
              HealthAvailability.needsPermission =>
                context.l10n.healthPermissionsMissing,
              HealthAvailability.needsInstall =>
                context.l10n.healthInstallRequired,
              HealthAvailability.unavailable => context.l10n.healthUnavailable,
            }),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            context.message(error!),
            style: const TextStyle(color: Colors.deepOrange),
          ),
        const SizedBox(height: 14),
        Text(context.l10n.healthSetupSteps),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: busy || widget.source == null
              ? null
              : () => run(() => widget.source!.openZepp()),
          icon: const Icon(Icons.open_in_new),
          label: Text(context.l10n.openZepp),
        ),
        FilledButton.icon(
          onPressed:
              busy ||
                  status == HealthAvailability.unavailable ||
                  widget.source == null
              ? null
              : () => run(() async {
                  if (status == HealthAvailability.needsInstall) {
                    await widget.source!.openSettings();
                  } else {
                    status = await widget.source!.authorize();
                    await widget.onAuthorized?.call();
                  }
                }),
          icon: const Icon(Icons.favorite_outline),
          label: Text(
            status == HealthAvailability.needsInstall
                ? context.l10n.installHealthConnect
                : context.l10n.authorizeMeasurements,
          ),
        ),
        TextButton(
          onPressed: busy || widget.source == null
              ? null
              : () => run(() => widget.source!.openSettings()),
          child: Text(context.l10n.manageHealthPermissions),
        ),
        const Divider(),
        Text(
          context.l10n.supportedMeasurements,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(context.l10n.supportedMeasurementsInfo),
        const SizedBox(height: 16),
        Text(
          context.l10n.privacy,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(context.l10n.healthPrivacy),
        const SizedBox(height: 12),
        Text(context.l10n.healthDevicePermissions),
      ],
    ),
  );
}
