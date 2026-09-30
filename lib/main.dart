import 'data/health_connect.dart';
import 'data/approach_source.dart';
import 'data/android_guidance.dart';
import 'data/android_step_counter.dart';
import 'data/photon_place_search.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'application/library.dart';
import 'application/collaborative_trails.dart';
import 'data/shared_trail_api.dart';
import 'data/trail_identity_hash.dart';
import 'application/announce_progress.dart';
import 'application/guide_navigation.dart';
import 'domain/guidance.dart';
import 'domain/walk_recap.dart';
import 'application/record_walk.dart';
import 'data/recording_store.dart';
import 'application/prepare_maps.dart';
import 'data/native_automatic_maps.dart';
import 'application/backend_environment.dart';
import 'application/auth_controller.dart';
import 'application/synchronize_library.dart';
import 'data/account_storage.dart';
import 'data/local_database.dart';
import 'data/offline_maps.dart';
import 'data/platform_services.dart';
import 'data/server_connection.dart';
import 'data/secure_credentials.dart';
import 'data/trail_codec.dart';
import 'data/demo_seed.dart';
import 'application/app_controller.dart';
import 'presentation/auth.dart';
import 'presentation/guidance_text.dart';
import 'presentation/localization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kilometre summaries format clock times even while no screen is visible.
  await initializeDateFormatting();
  final locale = LocaleController(
    store: const SecureCredentials(),
    applyNative: (language) =>
        const MethodChannel('gpix/locale')
            .invokeMethod<void>('select', {'language': language}),
  );
  await locale.load();
  final environment = BackendEnvironment(
    appFlavor == 'dev' ? BackendMode.dev : BackendMode.prod,
    const String.fromEnvironment('API_URL'),
  );
  final server = ServerConnection(
    http.Client(),
    environment: environment,
    credentials: const SecureCredentials(),
    languageCode: () => locale.languageCode,
  );
  final auth = AuthController(server, environment);
  await auth.restore();
  final runtime = _LibraryRuntime(server, locale);
  runApp(
    AuthShell(
      localeController: locale,
      auth: auth,
      openLibrary: runtime.open,
      closeLibrary: runtime.close,
      decideLegacyImport: runtime.decideLegacyImport,
      initialIdentifier: kDebugMode
          ? const String.fromEnvironment('AUTH_PREFILL_IDENTIFIER')
          : '',
      initialPassword: kDebugMode
          ? const String.fromEnvironment('AUTH_PREFILL_PASSWORD')
          : '',
    ),
  );
}

class _LibraryRuntime {
  _LibraryRuntime(this.server, this.locale);
  final ServerConnection server;
  final LocaleController locale;
  AppLocalizations get messages =>
      lookupAppLocalizations(Locale(locale.languageCode));
  Future<void> _queue = Future.value();
  Future<void> Function()? _close;
  Future<T> _serialize<T>(Future<T> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> close() => _serialize(() async {
    final close = _close;
    _close = null;
    await close?.call();
  });
  Future<void> decideLegacyImport(AuthSession session, bool adopt) =>
      _serialize(() async {
        if (server.session?.user.id != session.user.id) {
          throw MessageFailure(AppMessage.sessionChanged);
        }
        final directory = await getApplicationSupportDirectory();
        await AccountStorage.decideLegacyImport(
          directory,
          server.scope,
          session.user,
          adopt,
        );
      });
  Future<AppController> open(AuthSession session) => _serialize(() async {
    final previous = _close;
    _close = null;
    await previous?.call();
    if (server.session?.user.id != session.user.id) {
      throw MessageFailure(AppMessage.sessionChanged);
    }
    final scopedServer = server.bindAccount();
    final directory = await getApplicationSupportDirectory();
    final previousServer = await server.credentials.read('server');
    final trustedPreviousOrigin =
        previousServer != null &&
        previousServer.trim().replaceFirst(RegExp(r'/+$'), '') == server.base;
    final storage = await AccountStorage.resolve(
      directory,
      server.scope,
      session.user,
      trustedPreviousOrigin: trustedPreviousOrigin,
    );
    final db = await openLocalDatabase(storage.databasePath);
    // Device preference: speech depends on this phone's audio, not the account.
    const preferences = SecureCredentials();
    String announcementKey(AnnouncementSetting setting) => switch (setting) {
      AnnouncementSetting.directionVoice => 'gpix.voiceGuidance',
      AnnouncementSetting.directionNotification => 'gpix.guidanceNotification',
      AnnouncementSetting.recapVoice => 'gpix.recapVoice',
      AnnouncementSetting.recapNotification => 'gpix.recapNotification',
    };
    Future<bool?> announcement(AnnouncementSetting setting) async =>
        switch (await preferences.read(announcementKey(setting))) {
          'true' => true,
          'false' => false,
          _ => null,
        };
    final voice =
        await announcement(AnnouncementSetting.directionVoice) ?? true;
    // The summary voice once followed the direction voice switch: keep it.
    final recapVoice =
        await announcement(AnnouncementSetting.recapVoice) ?? voice;
    final directionNotification =
        await announcement(AnnouncementSetting.directionNotification) ?? true;
    final recapNotification =
        await announcement(AnnouncementSetting.recapNotification) ?? true;
    final spokenRecap = RecapItem.parse(
      await preferences.read('gpix.spokenRecap'),
    );
    // Health Connect permissions are per phone, so is sharing.
    final shareWithHealth =
        await preferences.read('gpix.shareHealth') == 'true';
    final statistics = SqliteTrailStatisticsStore(db);
    final profiles = SqliteProfileStore(db);
    final sharedTrails = SqliteSharedTrailStore(db);
    final sharedTransport = ApiSharedTrailTransport(scopedServer);
    final guidance = AndroidGuidance(
      sentences: (instruction) => describeGuidance(messages, instruction),
      recapSentences: (recap) => describeRecap(messages, recap),
      languageCode: () => locale.languageCode,
    );
    final library = Library(
      SqliteTrailRepository(db),
      XmlGpxDecoder(placesName: (name) => messages.placesName(name)),
      ApiElevationSource(scopedServer),
      identity: const HashedTrailIdentity(),
    );
    final placesClient = http.Client();
    final controller = AppController(
      placeSearch: PhotonPlaceSearch(
        placesClient,
        base: const String.fromEnvironment('PLACE_SEARCH_URL'),
        languageCode: () => locale.languageCode,
      ),
      approachSource: ApiApproachSource(
        scopedServer,
        db,
        languageCode: () => locale.languageCode,
        routeName: (name) => messages.towardsTrail(name),
      ),
      health: const AndroidHealthConnect(),
      recorder: RecordWalk(
        SqliteRecordingStore(db),
        library.repository,
        GpsPositionSource(
          recording: true,
          languageCode: () => locale.languageCode,
        ),
        const Uuid().v4,
        freeWalkName: () => messages.freeWalk,
        routeName: (started) => messages.walkedRouteName(started),
        identity: const HashedTrailIdentity(),
        steps: const AndroidStepCounter(),
      ),
      profiles: profiles,
      library: library,
      loadDemo: () => seedDemo(db, storage.mapsDirectory, library),
      maps: OfflineMaps(db, storage.mapsDirectory, scopedServer),
      automaticMaps: PrepareMaps(NativeAutomaticMaps(storage.mapsDirectory)),
      gps: GpsPositionSource(languageCode: () => locale.languageCode),
      sync: SynchronizeLibrary(
        SqliteSyncStore(db, localCopyName: (name) => messages.localCopy(name)),
        ApiSyncTransport(scopedServer),
        statistics: (
          transport: ApiStatisticsTransport(scopedServer),
          store: statistics,
        ),
        shared: (transport: sharedTransport, store: sharedTrails),
        profile: (
          transport: ApiProfileTransport(scopedServer),
          store: profiles,
        ),
      ),
      setAwake: (on) => WakelockPlus.toggle(enable: on),
      vibrate: HapticFeedback.heavyImpact,
      connectionDetails: () => server.details,
      guide: GuideNavigation(
        guidance,
        voice: voice,
        notify: directionNotification,
      ),
      saveAnnouncement: (setting, enabled) =>
          preferences.write(announcementKey(setting), '$enabled'),
      statistics: statistics,
      recap: AnnounceProgress(
        guidance,
        statistics: statistics,
        spoken: spokenRecap,
        voice: recapVoice,
        notify: recapNotification,
      ),
      saveSpokenRecap: (items) =>
          preferences.write('gpix.spokenRecap', RecapItem.format(items)),
      shareWithHealth: shareWithHealth,
      saveShareWithHealth: (enabled) =>
          preferences.write('gpix.shareHealth', '$enabled'),
      collaborative: CollaborativeTrails(
        sharedTrails,
        sharedTransport,
        library.repository,
        newId: const Uuid().v4,
        catalogue: sharedTransport,
      ),
    );
    _close = () async {
      await controller.shutdown();
      placesClient.close();
      await db.close();
    };
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      await _close!();
      _close = null;
      rethrow;
    }
  });
}
