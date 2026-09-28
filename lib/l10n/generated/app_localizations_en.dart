// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get routingAttribution => 'Valhalla · © OpenStreetMap';

  @override
  String get noJoinSegment => 'This trail has no segment to join.';

  @override
  String get alreadyNearTrail =>
      'You are already on the trail: tracking starts here.';

  @override
  String get cachedApproach =>
      'Using a saved route · recalculation unavailable offline';

  @override
  String get gpsUnavailable =>
      'Cannot find an accurate GPS position. Try again outdoors.';

  @override
  String get noWatchData =>
      'No measurements shared for this period. Sync your watch in Zepp, then try again.';

  @override
  String get watchDataAdded => 'Health Connect measurements added to this walk';

  @override
  String get walkSavedPending => 'Walk saved here · sync pending';

  @override
  String get changesSavedPending => 'Changes saved here · sync pending';

  @override
  String get localMaps => 'Local maps';

  @override
  String get mapsStorageUnavailable =>
      'Maps not prepared: check available storage.';

  @override
  String get demoNotice =>
      'Demo: sample trails and elevations, real map of Florence.';

  @override
  String get syncPending => 'Sync pending';

  @override
  String itemsSaved(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 items saved on this phone',
      one: 'One item saved on this phone',
      zero: 'No items saved on this phone',
    );
    return '$_temp0';
  }

  @override
  String get mapSaved => 'Map verified and saved offline';

  @override
  String get syncRetry => 'Saved on this phone · sync will resume';

  @override
  String get sessionRestoreFailed =>
      'Cannot open the saved session. Please sign in again.';

  @override
  String get localDev => 'Local Dev (Docker)';

  @override
  String missingApiUrl(Object arg1, Object arg2) {
    return '$arg1: set API_URL in $arg2, then restart F5. Offline access requires a successful first sign-in.';
  }

  @override
  String invalidApiUrl(Object arg1, Object arg2) {
    return '$arg1: invalid API URL in $arg2 (no credentials, query or fragment allowed).';
  }

  @override
  String localhostApiUrl(Object arg1, Object arg2) {
    return '$arg1: localhost refers to the phone. Use your computer\'s LAN IP in $arg2.';
  }

  @override
  String prodHttpsRequired(Object arg1) {
    return 'Prod: API_URL must start with https:// in $arg1. No request will be sent.';
  }

  @override
  String get devPrivateIpRequired =>
      'Dev: HTTP requires a private LAN IPv4 address (10.x, 172.16–31.x or 192.168.x). Otherwise use HTTPS.';

  @override
  String mapProgress(Object arg1, Object arg2, Object arg3) {
    return 'Maps: $arg1/$arg2 areas · $arg3%';
  }

  @override
  String savedAreas(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 areas saved on this phone',
      one: '1 area saved on this phone',
      zero: '0 areas saved on this phone',
    );
    return '$_temp0';
  }

  @override
  String get mapPreparationPending =>
      'Preparation pending · connection or storage unavailable. Maps already received remain available.';

  @override
  String get freeWalk => 'Free walk';

  @override
  String recordingSuspended(Object arg1) {
    return 'Recording suspended: $arg1';
  }

  @override
  String walkSaveFailed(Object arg1) {
    return 'Cannot save this walk: $arg1';
  }

  @override
  String get syncRunning => 'Sync in progress';

  @override
  String get librarySynced => 'Library synced';

  @override
  String syncConflicts(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other:
          '$arg1 conflicts: local copies preserved. Resolve them in settings.',
      one: '1 conflict: local copy preserved. Resolve it in settings.',
      zero: 'No conflicts',
    );
    return '$_temp0';
  }

  @override
  String get waitForSync => 'Wait for sync to finish.';

  @override
  String get legacyAccountDenied =>
      'This account cannot import the previous library.';

  @override
  String get libraryAlreadyOwned =>
      'This library already belongs to another account or server.';

  @override
  String get approachUnavailable =>
      'Walking route unavailable. Connect to the server and Internet, then try again. No saved route passes near your position.';

  @override
  String get noNearbyPath =>
      'No accessible path close enough to your position or the joining point.';

  @override
  String get routeTooLong => 'Route too long';

  @override
  String get invalidGeometry => 'Invalid geometry';

  @override
  String get invalidCoordinates => 'Invalid coordinates';

  @override
  String get emptyRoute => 'Empty route';

  @override
  String get invalidDirections => 'Invalid directions';

  @override
  String get missingDirections => 'Missing directions';

  @override
  String towardsTrail(Object arg1) {
    return 'Towards the trail · $arg1';
  }

  @override
  String get demo => 'Demo';

  @override
  String get demoFlorence => 'Demo · Florence';

  @override
  String get damagedGpx =>
      'This trail file contains damaged text. Correct it in the original file before importing.';

  @override
  String get gpxSizeLimit => 'Limit: 50 MB per trail file.';

  @override
  String get incompleteUtf16 => 'Incomplete UTF-16 file.';

  @override
  String get invalidUtf16 => 'Invalid UTF-16 text.';

  @override
  String unsupportedGpxEncoding(Object arg1) {
    return 'Unsupported file encoding: $arg1. Export the file as UTF-8.';
  }

  @override
  String localCopy(Object arg1) {
    return '$arg1 · local copy';
  }

  @override
  String get libraryClosed => 'Library closed';

  @override
  String get downloadStalled => 'Download stalled';

  @override
  String get invalidMapCatalog => 'Invalid map catalog.';

  @override
  String get downloadRunning => 'Download already in progress.';

  @override
  String get mapHttpsRequired =>
      'Package rejected: HTTPS required, except HTTP from the same Dev LAN server.';

  @override
  String get incorrectPackageSize => 'Incorrect package size.';

  @override
  String get packageIntegrityFailed =>
      'Incomplete package or failed integrity check.';

  @override
  String get forbiddenPackagePath => 'Package path not allowed.';

  @override
  String get unpackedPackageTooLarge => 'Unpacked package too large.';

  @override
  String get waitForDownload => 'Wait for the download to finish.';

  @override
  String get missingMapArchive => 'Missing map style or archive.';

  @override
  String get invalidPath => 'Invalid path.';

  @override
  String get damagedResource => 'Missing or damaged resource.';

  @override
  String get invalidPmtiles => 'Invalid PMTiles v3 archive.';

  @override
  String get truncatedPmtiles => 'Truncated PMTiles archive.';

  @override
  String get unsupportedMapStyle => 'Unsupported style version.';

  @override
  String get localPmtilesRequired =>
      'The map must use only local PMTiles archives.';

  @override
  String get nonLocalGraphics => 'Graphics resources are not local.';

  @override
  String get externalMapResource =>
      'A map resource depends on the network or an external file.';

  @override
  String get unsupportedGlyphTemplate => 'Unsupported glyph template.';

  @override
  String get missingFonts => 'Missing local fonts.';

  @override
  String get incompleteGlyphs => 'Incomplete glyph set.';

  @override
  String get undeclaredResource => 'Undeclared local resource.';

  @override
  String get enableLocation => 'Enable location on your phone.';

  @override
  String get locationPermissionRequired =>
      'Location is required for tracking. Allow it in Android settings.';

  @override
  String get recordingNotificationTitle => 'Gpix · walk in progress';

  @override
  String get recordingNotificationBody =>
      'Your walk is being recorded. Open Gpix to pause or finish.';

  @override
  String get recordingChannel => 'Walk recording';

  @override
  String get incompleteElevations => 'Incomplete elevation response.';

  @override
  String get sessionChanged => 'The session has changed.';

  @override
  String serverUnavailable(Object arg1) {
    return 'Server unavailable (HTTP $arg1).';
  }

  @override
  String get signInRequired => 'Sign in to continue.';

  @override
  String get sessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get mapAddressRejected => 'Map address rejected.';

  @override
  String get gpxTooLarge => 'Trail file too large (50 MB maximum).';

  @override
  String get xmlEntitiesForbidden => 'XML entities are not allowed.';

  @override
  String get notGpx => 'This file is not a trail file (.gpx).';

  @override
  String get invalidGpxCoordinates => 'Invalid trail coordinates.';

  @override
  String get emptyGpx => 'No trail or point of interest in this file.';

  @override
  String get invalidUsername => '3 to 32 letters, digits or underscores.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get invalidPassword =>
      'The password must contain 8 to 128 characters.';

  @override
  String get invalidMapArea => 'Invalid map area';

  @override
  String get appTitle => 'Gpix · On the trail';

  @override
  String get settings => 'Settings';

  @override
  String get myTrails => 'My trails';

  @override
  String get offline => 'Offline';

  @override
  String get map => 'Map';

  @override
  String get history => 'History';

  @override
  String get sync => 'Sync';

  @override
  String get delete => 'Delete';

  @override
  String get view => 'View';

  @override
  String get go => 'Start';

  @override
  String get keep => 'Keep';

  @override
  String get importGpx => 'Import a trail';

  @override
  String get tryDemo => 'Try the demo · Florence';

  @override
  String itemCount(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 items',
      one: '1 item',
      zero: '0 items',
    );
    return '$_temp0';
  }

  @override
  String get importIntro =>
      'Import a trail (.gpx file): a Camino, a hike or a list of places. No need to split it into stages.';

  @override
  String pointCount(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 points of interest',
      one: '1 point of interest',
      zero: '0 points of interest',
    );
    return '$_temp0';
  }

  @override
  String segmentCount(Object arg1, int arg2) {
    String _temp0 = intl.Intl.pluralLogic(
      arg2,
      locale: localeName,
      other: '$arg2 segments',
      one: '1 segment',
      zero: '0 segments',
    );
    return '$arg1 · $_temp0';
  }

  @override
  String get mapReady => 'Map ready offline';

  @override
  String get mapNeedsPreparation => 'Map needs preparation';

  @override
  String get savedPlaces => 'Places saved on this phone';

  @override
  String get days => 'Days';

  @override
  String get deleteItemQuestion => 'Delete this item?';

  @override
  String get deleteItemBody =>
      'This deletion will also be synced with your server.';

  @override
  String get sharedMaps =>
      'Maps are shared between your trails and stored on your phone.';

  @override
  String get automaticMapsInfo =>
      'Visible areas load automatically online. Each trail prepares its maps in the background. Offline, only downloaded areas remain visible.';

  @override
  String get resumePreparation => 'Resume preparation';

  @override
  String get readyOffline => 'Ready offline';

  @override
  String get preparingMaps => 'Automatic preparation running or pending';

  @override
  String get loadCatalog => 'Load my server\'s catalog';

  @override
  String prepareTrails(Object arg1) {
    return 'Prepare my trails · $arg1 MB';
  }

  @override
  String get completeElevations => 'Complete elevations for the open trail';

  @override
  String get onMyPhone => 'On my phone';

  @override
  String get noInstalledMaps =>
      'No map installed. Configure your server and its catalog in settings. Trails remain viewable.';

  @override
  String get deleteMap => 'Delete this map';

  @override
  String get availableRegions => 'Available regions';

  @override
  String get coversOpenTrail => ' · covers the open trail';

  @override
  String get download => 'Download';

  @override
  String get removeMapQuestion => 'Remove this map?';

  @override
  String affectedTrails(Object arg1) {
    return 'Affected trails: $arg1. Their map may become unavailable offline.';
  }

  @override
  String get none => 'none';

  @override
  String mapSizeVersion(Object arg1, Object arg2) {
    return '$arg1 MB · $arg2';
  }

  @override
  String mapSizeCoverage(Object arg1, Object arg2) {
    return '$arg1 MB$arg2';
  }

  @override
  String get libraryOpenFailed =>
      'Cannot open your library. Your data is preserved.';

  @override
  String get libraryAdoptFailed =>
      'Cannot attach the library. Existing files are preserved.';

  @override
  String get previousLibrary => 'Your previous library';

  @override
  String get previousLibraryInfo =>
      'Trails and maps from your previous installation are on this phone. Their original server cannot be confirmed.';

  @override
  String adoptLibraryQuestion(Object arg1) {
    return 'Attach them to $arg1 on this server?';
  }

  @override
  String get adoptLibraryInfo =>
      'Importing allows these data and pending changes to sync with this account. With a separate library, the old files are preserved but neither displayed nor synced.';

  @override
  String get importExistingLibrary => 'Import my existing library';

  @override
  String get useSeparateLibrary => 'Use a separate library';

  @override
  String get signOut => 'Sign out';

  @override
  String get openingLibrary => 'Opening your space…';

  @override
  String get resetEmailSent =>
      'If this address belongs to an account, an email will explain what to do. Copy its code below.';

  @override
  String get passwordSaved => 'Password saved. Sign in with your new password.';

  @override
  String get loginHeading => 'Your trail starts here.';

  @override
  String get registerHeading => 'Your next adventure.';

  @override
  String get forgotHeading => 'Recover your account.';

  @override
  String get resetHeading => 'A fresh start.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createMyAccount => 'Create my account';

  @override
  String get sendInstructions => 'Send instructions';

  @override
  String get savePassword => 'Save password';

  @override
  String get authIntro =>
      'Your trails, your maps, your freedom. Sign in once, then head out even offline.';

  @override
  String get identifier => 'Email or username';

  @override
  String get email => 'Email address';

  @override
  String get username => 'Username';

  @override
  String get resetCode => 'Code or link received by email';

  @override
  String get resetCodeHint => 'Copy the complete code or link from the email.';

  @override
  String get newPassword => 'New password';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get createAccount => 'Create an account';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get haveResetCode => 'I have a reset code';

  @override
  String serverLabel(Object arg1) {
    return 'Server · $arg1';
  }

  @override
  String get configureServer => 'Configure the address in the launch profile';

  @override
  String get myAccount => 'My account';

  @override
  String get offlineSessionInfo =>
      'Your session allows offline access to your library. Server revocation is checked when the connection returns.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get changePassword => 'Change password';

  @override
  String get apiConfigurationInfo =>
      'Set the API address in the launch profile\'s local file, then restart F5.';

  @override
  String get resolveConflicts => 'Resolve conflicts: keep both copies';

  @override
  String get signOutInfo =>
      'Signing out locks this space on this phone. Your local trails are kept for your next sign-in.';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get estimatedSuffix => ' · estimated';

  @override
  String get partialSuffix => ' · partial';

  @override
  String get nearMe => 'Around me';

  @override
  String get wholeTrail => 'Whole trail';

  @override
  String get profileUnavailable => 'Profile unavailable · tracking still works';

  @override
  String get distanceAlongTrail => 'Distance along the trail';

  @override
  String altitudeTitle(Object arg1, Object arg2) {
    return 'Altitude$arg1$arg2';
  }

  @override
  String get finishWalkQuestion => 'Finish this walk?';

  @override
  String get finishWalkInfo =>
      'Your route and measurements will be saved in history and synced with your account.';

  @override
  String get continueAction => 'Continue';

  @override
  String get saveWalk => 'Save walk';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get importWatchData => 'Add watch measurements';

  @override
  String get watchSettings => 'Watch settings';

  @override
  String get deleteWalkQuestion => 'Delete this walk?';

  @override
  String get deleteWalkInfo => 'The deletion will be synced with your account.';

  @override
  String get deleteWalk => 'Delete walk';

  @override
  String get walkHistoryInfo => 'The paths you have actually walked.';

  @override
  String get recordingActive => '● Recording in progress';

  @override
  String get walkPaused => 'Walk paused · ready to resume';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get finish => 'Finish';

  @override
  String get liveStats => 'My live data';

  @override
  String get startRoute => 'Start a route';

  @override
  String walkCountDistance(int arg1, Object arg2) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 walks',
      one: '1 walk',
      zero: '0 walks',
    );
    return '$_temp0 · $arg2';
  }

  @override
  String get viewAllWalkedPlaces => 'View everywhere I have walked';

  @override
  String get allWalks => 'All';

  @override
  String get withGpx => 'On a trail';

  @override
  String get freeWalks => 'Free walks';

  @override
  String get noWalks =>
      'No walks here yet. Start a trail or record a free walk.';

  @override
  String get unreadableFilename => 'Unreadable file name';

  @override
  String get unreadableFilenameInfo =>
      'The phone provided a damaged name. Enter the trail name to preserve the correct characters.';

  @override
  String get trailName => 'Trail name';

  @override
  String get routeDescriptionOptional => 'Description (optional)';

  @override
  String get enterName => 'Enter a name.';

  @override
  String get replaceDamagedText => 'Replace the damaged characters.';

  @override
  String get cancel => 'Cancel';

  @override
  String get importAction => 'Import';

  @override
  String get cannotOpenNavigation => 'Cannot open the app or browser.';

  @override
  String get reverseSuffix => ' · reverse direction';

  @override
  String get routingPrivacy =>
      'The routing service uses your position and the closest point. Gpix saves the calculated route so you can continue offline.';

  @override
  String get myMap => 'My map';

  @override
  String get trailMapAvailable => 'Trail map available offline';

  @override
  String get visibleMapsInfo => 'Visible areas load automatically online.';

  @override
  String get offlineMapsInfo => 'Offline, only downloaded areas are visible.';

  @override
  String activeTrail(Object arg1) {
    return 'Following: $arg1';
  }

  @override
  String get compassInfo =>
      'The arrow points towards the top of your phone. The compass button switches between north-up and heading-up.';

  @override
  String get discardChangesQuestion => 'Leave this edit?';

  @override
  String get discardChangesInfo =>
      'The current section is not saved. Previously saved days are preserved.';

  @override
  String get leave => 'Leave';

  @override
  String deleteDayQuestion(Object arg1) {
    return 'Delete day $arg1?';
  }

  @override
  String get deleteDayInfo => 'The trail and other sections are preserved.';

  @override
  String get walkInProgressData => 'Walk in progress · data';

  @override
  String get walkPausedResume => 'Walk paused · resume';

  @override
  String get walkedPlaces => 'Places walked';

  @override
  String get offTrailDetails => 'Off trail · details';

  @override
  String dayNumber(Object arg1) {
    return 'Day $arg1';
  }

  @override
  String editDayNumber(Object arg1) {
    return 'Edit day $arg1';
  }

  @override
  String get tapStart => 'Tap the start on the trail.';

  @override
  String get tapEnd => 'Tap the end on the trail.';

  @override
  String get reviewSection => 'Highlighted section: review and save.';

  @override
  String startBoundary(Object arg1) {
    return 'A · Start$arg1';
  }

  @override
  String endBoundary(Object arg1) {
    return 'B · End$arg1';
  }

  @override
  String minimumSection(Object arg1, Object arg2) {
    return '$arg1$arg2 · minimum 10 m';
  }

  @override
  String get saveDay => 'Save this day';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get continueFromLastEnd => 'Continue from the last endpoint';

  @override
  String get cancelEdit => 'Cancel edit';

  @override
  String get myDays => 'My days';

  @override
  String get noDays => 'Your first section will appear here.';

  @override
  String dayDistance(Object arg1, Object arg2) {
    return 'Day $arg1 · $arg2';
  }

  @override
  String deleteDayNumber(Object arg1) {
    return 'Delete day $arg1';
  }

  @override
  String get remaining => 'remaining';

  @override
  String get distanceToTrail => 'to the trail';

  @override
  String get toggleDetails => 'Expand or collapse details';

  @override
  String get trailReached => 'Trail reached';

  @override
  String get readyToFollow => 'Ready to follow your trail.';

  @override
  String get findingAccuratePosition => 'Looking for an accurate GPS position…';

  @override
  String routeEndGap(Object arg1) {
    return 'End of the calculated path. Joining point $arg1 m away, marker R: check access on site.';
  }

  @override
  String get leftApproach =>
      'You have left the approach route. Recalculate for directions from here.';

  @override
  String inMetres(Object arg1) {
    return 'In $arg1 m';
  }

  @override
  String get followFromHere => 'Follow the trail from here';

  @override
  String get exitApproach => 'Exit approach guidance';

  @override
  String get recalculate => 'Recalculate';

  @override
  String get cachedRouteInfo => 'Saved route · online recalculation only';

  @override
  String get savedWalkingApproach =>
      'Walking approach · route saved on this phone';

  @override
  String get fixMap => 'Fix the map';

  @override
  String get pauseTracking => 'Pause tracking';

  @override
  String get resumeApproach => 'Resume towards the trail';

  @override
  String get followTrail => 'Start the trail';

  @override
  String returnToTracking(Object arg1) {
    return 'Return to tracking · $arg1';
  }

  @override
  String get findingPosition => 'Finding your position…';

  @override
  String get poorGps => 'Old position or low GPS accuracy';

  @override
  String gpsAccuracy(Object arg1) {
    return 'GPS accuracy ± $arg1 m';
  }

  @override
  String get leavingTrail => 'You are moving away from the trail';

  @override
  String get muteAlert => 'Mute alert';

  @override
  String get reverseDirection => 'Reverse direction · change';

  @override
  String get gpxDirection => 'Original direction · change';

  @override
  String get currentWalk => 'My current walk';

  @override
  String get walkControls => 'Pause, finish and history';

  @override
  String get planDays => 'Plan my days';

  @override
  String editDays(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: 'My $arg1 days',
      one: 'My day',
      zero: 'My days',
    );
    return '$_temp0 · edit';
  }

  @override
  String get offlineAvailability => 'Offline availability';

  @override
  String get routeInProgress => 'Route in progress';

  @override
  String get mapAroundYou => 'Your map, around you';

  @override
  String get accountServer => 'Account and server';

  @override
  String get accountServerInfo => 'Identity, password and sync';

  @override
  String get watchHealthData => 'Watch and health data';

  @override
  String get healthBridge => 'Amazfit / Zepp · Health Connect';

  @override
  String get myData => 'My data';

  @override
  String get syncDataInfo =>
      'Trails, days and walks are saved on this phone, then synced with your API. Sign in to the same account to find them on another phone. Maps must be downloaded again on that device.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get watchHealth => 'Watch and health';

  @override
  String get yourWatchMeasurements => 'Your watch, your measurements';

  @override
  String get compatibleWatches =>
      'Amazfit Active Max and other compatible watches: measurements pass through Zepp and Health Connect. Other brands can use the same bridge.';

  @override
  String get checkingHealthConnect => 'Checking Health Connect…';

  @override
  String get healthAuthorized =>
      'Health Connect access authorized · check measurement availability in a walk';

  @override
  String get healthPermissionsMissing => 'Missing or partial permissions';

  @override
  String get healthInstallRequired =>
      'Health Connect must be installed or updated';

  @override
  String get healthUnavailable => 'Health Connect unavailable on this device';

  @override
  String get healthSetupSteps =>
      '1. Sync your watch in Zepp.\n\n2. Enable sharing with Health Connect in Zepp connections.\n\n3. Authorize Gpix below. In a walk, tap “Add watch measurements”.';

  @override
  String get openZepp => 'Open Zepp';

  @override
  String get installHealthConnect => 'Install Health Connect';

  @override
  String get authorizeMeasurements => 'Authorize measurements';

  @override
  String get manageHealthPermissions => 'Manage or revoke permissions';

  @override
  String get supportedMeasurements => 'Supported measurements';

  @override
  String get supportedMeasurementsInfo =>
      'Average and maximum heart rate, steps and active calories during your walk. Data depends on the model and what Zepp shares. This is not a live Bluetooth connection.';

  @override
  String get privacy => 'Privacy';

  @override
  String get healthPrivacy =>
      'Data is read only when you request it. Imported measurements are saved with your walk and synced with your personal API. Revoking permission prevents future reads; to erase imported measurements, delete the walk from history.';

  @override
  String get healthDevicePermissions =>
      'Permissions apply to this phone. Grant them again on another device. Health Connect may restrict access to older periods.';

  @override
  String get chooseTrailPassage =>
      'The trail passes here more than once. Which passage do you want?';

  @override
  String atGpxKilometre(Object arg1) {
    return 'At trail kilometre $arg1';
  }

  @override
  String get tapSelectedTrail =>
      'Tap the selected trail. Zoom in to place the boundary precisely.';

  @override
  String get northUp => 'Switch to north-up';

  @override
  String get headingUp => 'Orient with the phone';

  @override
  String get recenter => 'Recenter on my position';

  @override
  String get distanceWalked => 'Distance walked';

  @override
  String get activeDuration => 'Active duration';

  @override
  String get totalDuration => 'Total duration';

  @override
  String get averageSpeed => 'Average speed';

  @override
  String get averagePace => 'Average pace';

  @override
  String get maxGpsSpeed => 'Max. GPS speed';

  @override
  String get ascent => 'Ascent';

  @override
  String get descent => 'Descent';

  @override
  String get altitude => 'Altitude';

  @override
  String get minMaxAltitude => 'Min. / max. altitude';

  @override
  String get averageHeartRate => 'Average heart rate';

  @override
  String get maxHeartRate => 'Maximum heart rate';

  @override
  String get steps => 'Steps';

  @override
  String get activeCalories => 'Active calories';

  @override
  String get statsExplanation =>
      'Active duration excludes manual pauses. Average pace and speed use this duration. Elevation changes are estimated from filtered GPS altitudes.';

  @override
  String get noImportedWatchData =>
      'Watch: no measurements imported. Missing values are not estimated.';

  @override
  String healthSources(Object arg1, Object arg2) {
    return 'Health Connect · $arg1\nSources: $arg2';
  }

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'Device language';

  @override
  String get unexpectedError =>
      'This action could not be completed. Check your connection and try again.';

  @override
  String get networkError =>
      'Connection unavailable. Your saved data remains on this phone.';

  @override
  String get invalidCredentials => 'Incorrect username or password.';

  @override
  String get invalidSession => 'Invalid session. Please sign in again.';

  @override
  String get accountAlreadyExists => 'Username or email already in use.';

  @override
  String get rateLimited => 'Too many attempts. Try again in 15 minutes.';

  @override
  String get resetUnavailable => 'Email delivery unavailable. Try again later.';

  @override
  String get invalidResetCode => 'Invalid or expired code. Request a new code.';

  @override
  String get incorrectCurrentPassword => 'Incorrect current password.';

  @override
  String get invalidFields => 'All fields must be text.';

  @override
  String get unknownOperation => 'Unknown operation.';

  @override
  String get formTooLarge => 'Form too large.';

  @override
  String get damagedText =>
      'Text contains a lost character. Correct its name or reimport the original file.';

  @override
  String get invalidRouteCoordinates =>
      'Invalid origin or destination coordinates.';

  @override
  String get waitBeforeRouting => 'Wait two seconds before recalculating.';

  @override
  String get serviceUnavailable => 'Service unavailable or resource not found';

  @override
  String get invalidRequest => 'Invalid request. Check the entered data.';

  @override
  String placesName(String name) {
    return '$name · places';
  }

  @override
  String get englishLanguage => 'English';

  @override
  String get frenchLanguage => 'Français';

  @override
  String get guidanceSlightLeft => 'Bear left';

  @override
  String get guidanceLeft => 'Turn left';

  @override
  String get guidanceSharpLeft => 'Turn sharp left';

  @override
  String get guidanceUTurn => 'Make a U-turn';

  @override
  String get guidanceSlightRight => 'Bear right';

  @override
  String get guidanceRight => 'Turn right';

  @override
  String get guidanceSharpRight => 'Turn sharp right';

  @override
  String guidanceSlightLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, bear left',
      one: 'In 1 metre, bear left',
    );
    return '$_temp0';
  }

  @override
  String guidanceLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, turn left',
      one: 'In 1 metre, turn left',
    );
    return '$_temp0';
  }

  @override
  String guidanceSharpLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, turn sharp left',
      one: 'In 1 metre, turn sharp left',
    );
    return '$_temp0';
  }

  @override
  String guidanceUTurnIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, make a U-turn',
      one: 'In 1 metre, make a U-turn',
    );
    return '$_temp0';
  }

  @override
  String guidanceSlightRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, bear right',
      one: 'In 1 metre, bear right',
    );
    return '$_temp0';
  }

  @override
  String guidanceRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, turn right',
      one: 'In 1 metre, turn right',
    );
    return '$_temp0';
  }

  @override
  String guidanceSharpRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'In $metres metres, turn sharp right',
      one: 'In 1 metre, turn sharp right',
    );
    return '$_temp0';
  }

  @override
  String get guidanceArrive => 'You have reached the end of the trail';

  @override
  String get guidanceReachTrail => 'You have reached the trail';

  @override
  String get guidanceOffTrail => 'You have left the trail';

  @override
  String get guidanceOffTrailBody => 'Check the map to rejoin it.';

  @override
  String get guidanceNow => 'Now';

  @override
  String get nextDirection => 'Next direction';

  @override
  String get voiceGuidance => 'Voice guidance';

  @override
  String get voiceGuidanceInfo =>
      'Speaks each direction change about 100 m ahead during navigation, even with the screen off. While Gpix is in the background, a notification also shows the direction.';

  @override
  String get voiceGuidanceNotSaved =>
      'Voice guidance preference not saved on this phone.';

  @override
  String get menu => 'Menu';

  @override
  String get backToMap => 'Back to the map';

  @override
  String get searchPlaces => 'Search a town, an address…';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noPlaceFound => 'No place found.';

  @override
  String get placeSearchUnavailable =>
      'Place search needs a connection. Try again once online.';

  @override
  String trailCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trails',
      one: '1 trail',
    );
    return '$_temp0';
  }

  @override
  String trailsHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trails here',
      one: '1 trail here',
    );
    return '$_temp0';
  }

  @override
  String showTrail(String name) {
    return 'Show $name';
  }

  @override
  String get closeTrail => 'Close the trail';

  @override
  String get close => 'Close';

  @override
  String get openInGoogleMaps => 'Get there with Google Maps';

  @override
  String get searchTrails => 'Search my trails';

  @override
  String noTrailMatch(String query) {
    return 'No trail matches “$query”.';
  }

  @override
  String get approachFallback =>
      'Route to the trail unavailable offline: the trail itself is followed and your distance to it stays visible.';

  @override
  String get finishRoute => 'Finish the route';

  @override
  String get finishRouteQuestion => 'Finish this route?';

  @override
  String get finishRouteInfo =>
      'Your walk will be saved in history and, unless it exactly follows an existing route, become a new route on the map. Everything syncs with your account.';

  @override
  String routeCreated(String arg1) {
    return 'Route “$arg1” created and shown on the map · sync pending';
  }

  @override
  String routeAlreadyKnown(String arg1) {
    return 'This walk follows “$arg1”: no duplicate route was created.';
  }

  @override
  String get routeTooShort =>
      'Walk saved in history; too short to become a route.';

  @override
  String walkedRouteName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Route of $dateString';
  }

  @override
  String recapTitle(int kilometre) {
    return 'Kilometre $kilometre';
  }

  @override
  String recapDistance(String distance) {
    return '$distance km walked.';
  }

  @override
  String recapDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Walking for $minutes minutes.',
      one: 'Walking for 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String recapDurationHours(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Walking for $hours hours',
      one: 'Walking for 1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 and $_temp1.';
  }

  @override
  String recapCurrentSpeed(String speed) {
    return 'Last kilometre at $speed km/h.';
  }

  @override
  String recapAverageSpeed(String speed) {
    return 'Average speed $speed km/h.';
  }

  @override
  String recapFaster(String difference, String usual) {
    return '$difference km/h faster than your usual $usual km/h.';
  }

  @override
  String recapSlower(String difference, String usual) {
    return '$difference km/h slower than your usual $usual km/h.';
  }

  @override
  String recapAsUsual(String usual) {
    return 'Same speed as usual, $usual km/h.';
  }

  @override
  String recapPreviousWalks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Walked $count times before.',
      one: 'Walked once before.',
    );
    return '$_temp0';
  }

  @override
  String recapRemaining(String distance) {
    return '$distance km to go.';
  }

  @override
  String recapArrival(String time) {
    return 'Estimated arrival at $time.';
  }

  @override
  String recapAscent(int metres) {
    return '$metres m climbed.';
  }

  @override
  String recapClock(String time) {
    return 'It is $time.';
  }

  @override
  String get recapSettings => 'Kilometre summary';

  @override
  String get recapSettingsInfo =>
      'Every kilometre walked, a summary is spoken and, while Gpix is in the background, shown in a notification. Choose what the voice reads. Comparisons need earlier walks on the same trail; remaining distance and arrival need a followed trail.';

  @override
  String get recapItemDistance => 'Distance walked';

  @override
  String get recapItemDuration => 'Walking time';

  @override
  String get recapItemCurrentSpeed => 'Current speed (last kilometre)';

  @override
  String get recapItemAverageSpeed => 'Average speed';

  @override
  String get recapItemComparison => 'Comparison with your usual speed';

  @override
  String get recapItemRemaining => 'Remaining distance';

  @override
  String get recapItemArrival => 'Estimated arrival time';

  @override
  String get recapItemAscent => 'Elevation gain';

  @override
  String get recapItemClock => 'Current time';

  @override
  String get reviews => 'Reviews';

  @override
  String sharedBy(String author) {
    return 'Shared by $author';
  }

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String reviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String averageRating(String rating) {
    return 'Rated $rating out of 5';
  }

  @override
  String get writeReview => 'Give my review';

  @override
  String get editReview => 'Edit my review';

  @override
  String get deleteMyReview => 'Delete my review';

  @override
  String get deleteReviewQuestion => 'Delete your review?';

  @override
  String get reviewCompletionRequired =>
      'Walk the whole trail once with Gpix recording to give your review.';

  @override
  String reviewProgress(int percent) {
    return 'Your best recorded walk covers $percent% of this trail.';
  }

  @override
  String get reviewsOffline =>
      'Reviews saved on this phone · connect to refresh';

  @override
  String get reviewDialogTitle => 'Your review';

  @override
  String get reviewComment => 'Comment (optional)';

  @override
  String giveRating(int rating) {
    return '$rating out of 5';
  }

  @override
  String get publish => 'Publish';

  @override
  String get you => 'You';

  @override
  String get formerWalker => 'Former walker';

  @override
  String get removeSharedTrailBody =>
      'It is removed from your trails on all your phones. The shared trail stays visible to other walkers.';

  @override
  String get sharingNotice =>
      'Trails you add are shared with all Gpix walkers. Your walks, speeds and statistics stay private.';

  @override
  String get sharedTrailUnavailable =>
      'Connect to the internet to download this trail.';

  @override
  String get reviewsUnavailable => 'Reviews are unavailable offline.';

  @override
  String get invalidReview =>
      'Choose 1 to 5 stars and at most 2,000 characters.';

  @override
  String get reviewSaved => 'Review published';

  @override
  String get reviewDeleted => 'Review deleted';

  @override
  String trailsAlreadyShared(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: 'These $arg1 trails already exist: the shared trails are reused',
      one: 'This trail already exists: the shared trail is reused',
    );
    return '$_temp0';
  }

  @override
  String get completionRequired => 'Walk the whole trail before reviewing it.';

  @override
  String get invalidRating => 'Choose a rating from 1 to 5 stars.';

  @override
  String get reviewTooLong =>
      'Your comment is too long (2,000 characters maximum).';

  @override
  String get addPlaceHere => 'Add a place here';

  @override
  String get newPlaceTitle => 'New place';

  @override
  String get editPlaceTitle => 'Edit the place';

  @override
  String get placeAtPosition =>
      'It is placed at your current position and shared with every walker on this trail.';

  @override
  String get placeName => 'Name (for example: Viewpoint)';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String placeAddedBy(String author) {
    return 'Added by $author';
  }

  @override
  String get placePending => 'Saved on this phone · shared once online';

  @override
  String get deletePlaceQuestion => 'Delete this place?';

  @override
  String get invalidPlace => 'Give the place a name (200 characters maximum).';

  @override
  String get placeTooFar =>
      'Move within 100 m of the trail to add a place here.';

  @override
  String get placeNotYours => 'Only its author can change this place.';

  @override
  String get placeSaved => 'Place saved on the trail';

  @override
  String get placeDeleted => 'Place deleted';

  @override
  String get allTrails => 'All trails';

  @override
  String get searchAllTrails => 'Search trails, GR 20, Compostela…';

  @override
  String get catalogueNeedsConnection =>
      'The catalogue needs a connection. Your trails and those made available offline stay usable.';

  @override
  String get catalogueEmpty => 'No trails in the catalogue yet.';

  @override
  String get retry => 'Retry';

  @override
  String get myGroups => 'My groups';

  @override
  String get ownTrailsLegend => 'My trails (on this phone)';

  @override
  String get catalogueTrailsLegend => 'Catalogue trails';

  @override
  String get ownTrailLabel => 'your trail';

  @override
  String get catalogueTrailLabel => 'catalogue trail';

  @override
  String get itinerary => 'Itinerary';

  @override
  String get collection => 'Collection';

  @override
  String get itineraryInfo =>
      'Trails in order, as stages walked one after another.';

  @override
  String get collectionInfo =>
      'Trails gathered by theme, in no particular order.';

  @override
  String get stJamesCollection => 'Ways of St James (Camino de Santiago)';

  @override
  String get stJamesDescription =>
      'Every pilgrim route to Santiago de Compostela in the catalogue, with its stages and variants.';

  @override
  String get mainRoute => 'Main route';

  @override
  String get variantRoute => 'Variant';

  @override
  String get linkRoute => 'Link';

  @override
  String get excursionRoute => 'Excursion';

  @override
  String get approachRoute => 'Access route';

  @override
  String stageNumber(int stage) {
    return 'Stage $stage';
  }

  @override
  String stageOf(int stage) {
    return 'Stage $stage of';
  }

  @override
  String get partOf => 'Part of';

  @override
  String get waymarks => 'Waymarks';

  @override
  String get internationalNetwork => 'International trail';

  @override
  String get nationalNetwork => 'National trail';

  @override
  String get regionalNetwork => 'Regional trail';

  @override
  String get localNetwork => 'Local trail';

  @override
  String fromTo(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get loopTrail => 'Loop';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get trailWithdrawn =>
      'This trail is no longer in its source; it stays available for your walks.';

  @override
  String get website => 'Website';

  @override
  String get wikipedia => 'Wikipedia';

  @override
  String get openStreetMapAttribution =>
      'Trail data © OpenStreetMap contributors, ODbL licence';

  @override
  String openDataAttribution(String source) {
    return 'Trail data: $source';
  }

  @override
  String get viewOnOpenStreetMap => 'View on OpenStreetMap';

  @override
  String get makeAvailableOffline => 'Make available offline';

  @override
  String get availableOfflineLabel => 'Available offline on this phone';

  @override
  String get removeFromPhone => 'Remove';

  @override
  String get addToGroup => 'Add to a group';

  @override
  String byAuthor(String author) {
    return 'By $author';
  }

  @override
  String get editGroup => 'Edit the group';

  @override
  String get deleteGroup => 'Delete the group';

  @override
  String get deleteGroupQuestion => 'Delete this group?';

  @override
  String get deleteGroupInfo =>
      'The group disappears for every walker. Its trails stay in the catalogue.';

  @override
  String get emptyGroup => 'No trails in this group yet.';

  @override
  String get makeGroupAvailableOffline =>
      'Make all its trails available offline';

  @override
  String get groupTooLargeOffline =>
      'Too many trails to keep them all offline: open them one by one';

  @override
  String get memberActions => 'Trail actions';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get removeFromGroup => 'Remove from the group';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupDescription => 'Description (optional)';

  @override
  String get groupsArePublic =>
      'Groups are shared with every walker, like trails.';

  @override
  String get noGroupsYet => 'You have no groups yet.';

  @override
  String get catalogueUnavailable =>
      'The catalogue is unavailable. Check your connection.';

  @override
  String get invalidGroup => 'Give the group a name (200 characters maximum).';

  @override
  String get availableOffline =>
      'Trail available offline; its maps are being prepared.';

  @override
  String get offlineRemoved => 'Trail removed from this phone';

  @override
  String get groupSaved => 'Group saved';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String addedToGroup(String arg1) {
    return 'Added to “$arg1”';
  }

  @override
  String groupAvailableOffline(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 trails of the group are available offline',
      one: '1 trail of the group is available offline',
    );
    return '$_temp0';
  }

  @override
  String get unknownGroupMember =>
      'Sync your trails before adding them to a group.';

  @override
  String get groupContainsItself => 'A group cannot contain itself.';

  @override
  String get groupNotYours => 'Only its author can change this group.';

  @override
  String get searchTooLong => 'Search too long (200 characters maximum).';

  @override
  String get invalidRecordingReference =>
      'The trail this walk followed could not be saved with it.';

  @override
  String get catalogueTrailKeptOffline =>
      'Catalogue trail kept offline on this phone';

  @override
  String get trailDistance => 'distance';

  @override
  String get trailAscent => 'ascent';
}
