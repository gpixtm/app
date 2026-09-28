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
  String get noJoinSegment => 'This GPX has no segment to join.';

  @override
  String get alreadyNearTrail =>
      'You are already near the trail. Use Go to follow it from here.';

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
      'Demo: sample GPX and elevations, real map of Florence.';

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
      'This GPX contains damaged text. Correct it in the original file before importing.';

  @override
  String get gpxSizeLimit => 'Limit: 50 MB per GPX.';

  @override
  String get incompleteUtf16 => 'Incomplete UTF-16 file.';

  @override
  String get invalidUtf16 => 'Invalid UTF-16 text.';

  @override
  String unsupportedGpxEncoding(Object arg1) {
    return 'Unsupported GPX encoding: $arg1. Export the file as UTF-8.';
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
  String get gpxTooLarge => 'GPX too large (50 MB maximum).';

  @override
  String get xmlEntitiesForbidden => 'XML entities are not allowed.';

  @override
  String get notGpx => 'This file is not a GPX.';

  @override
  String get invalidGpxCoordinates => 'Invalid GPX coordinates.';

  @override
  String get emptyGpx => 'No trail or point of interest in this GPX.';

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
  String get go => 'Go';

  @override
  String get keep => 'Keep';

  @override
  String get joyOfWalking => 'THE JOY OF MOVING FORWARD';

  @override
  String get nextTrailStartsHere => 'Your next trail\nstarts here.';

  @override
  String get libraryIntro =>
      'Your trails, your places. Ready to go with you, even without a connection.';

  @override
  String get importGpx => 'Import a GPX';

  @override
  String get tryDemo => 'Try the demo · Florence';

  @override
  String get myLibrary => 'My library';

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
  String get oneJourney => 'A whole journey, one trail.';

  @override
  String get importIntro =>
      'Import your Camino trail or a file of points of interest. No need to split it into stages.';

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
  String get joinTrail => 'Join the trail';

  @override
  String get days => 'Days';

  @override
  String get deleteItemQuestion => 'Delete this item?';

  @override
  String get deleteItemBody =>
      'This deletion will also be synced with your server.';

  @override
  String get offlineHeadline => 'Peace of mind.\nEven offline.';

  @override
  String get sharedMaps =>
      'Maps are shared between your trails and stored on your phone.';

  @override
  String get automaticMapsInfo =>
      'Visible areas load automatically online. Each GPX prepares its maps in the background. Offline, only downloaded areas remain visible.';

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
      'No map installed. Configure your server and its catalog in settings. GPX files remain viewable.';

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
  String get myWalks => 'My walks';

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
  String get recordFreeWalk => 'Record a free walk';

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
  String get withGpx => 'With GPX';

  @override
  String get freeWalks => 'Free walks';

  @override
  String get noWalks =>
      'No walks here yet. Start a GPX with Go or record a free walk.';

  @override
  String get unreadableFilename => 'Unreadable file name';

  @override
  String get unreadableFilenameInfo =>
      'The phone provided a damaged name. Enter the trail name to preserve the correct characters.';

  @override
  String get trailName => 'Trail name';

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
  String get nearestJoinInfo =>
      'Towards the GPX point closest to your position.';

  @override
  String get reverseSuffix => ' · reverse direction';

  @override
  String get walkInGpix => 'Walk with Gpix';

  @override
  String get onlineRouteInfo => 'Map guidance · online calculation';

  @override
  String get walkInGoogleMaps => 'Walk with Google Maps';

  @override
  String get driveInGoogleMaps => 'Drive with Google Maps';

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
  String get deleteDayInfo => 'The GPX and other sections are preserved.';

  @override
  String trailsOnMap(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 trails on my map',
      one: '1 trail on my map',
      zero: '0 trails on my map',
    );
    return '$_temp0';
  }

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
  String get readyToFollow => 'Ready to follow your GPX.';

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
  String get followFromHere => 'Follow the GPX from here';

  @override
  String get exitApproach => 'Exit approach guidance';

  @override
  String get recalculate => 'Recalculate';

  @override
  String get otherNavigation => 'Other navigation';

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
  String get followTrail => 'Go · follow this trail';

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
  String get gpxDirection => 'GPX direction · change';

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
  String get myFreeWalk => 'My free walk';

  @override
  String get mapAroundYou => 'Your map, around you';

  @override
  String get allTrailsInfo =>
      'All your trails are visible. Tap a trail to select it.';

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
    return 'At GPX kilometre $arg1';
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
      'Text contains a lost character. Correct its name or reimport the original GPX.';

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
}
