import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @routingAttribution.
  ///
  /// In en, this message translates to:
  /// **'Valhalla · © OpenStreetMap'**
  String get routingAttribution;

  /// No description provided for @noJoinSegment.
  ///
  /// In en, this message translates to:
  /// **'This GPX has no segment to join.'**
  String get noJoinSegment;

  /// No description provided for @alreadyNearTrail.
  ///
  /// In en, this message translates to:
  /// **'You are already near the trail. Use Go to follow it from here.'**
  String get alreadyNearTrail;

  /// No description provided for @cachedApproach.
  ///
  /// In en, this message translates to:
  /// **'Using a saved route · recalculation unavailable offline'**
  String get cachedApproach;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot find an accurate GPS position. Try again outdoors.'**
  String get gpsUnavailable;

  /// No description provided for @noWatchData.
  ///
  /// In en, this message translates to:
  /// **'No measurements shared for this period. Sync your watch in Zepp, then try again.'**
  String get noWatchData;

  /// No description provided for @watchDataAdded.
  ///
  /// In en, this message translates to:
  /// **'Health Connect measurements added to this walk'**
  String get watchDataAdded;

  /// No description provided for @walkSavedPending.
  ///
  /// In en, this message translates to:
  /// **'Walk saved here · sync pending'**
  String get walkSavedPending;

  /// No description provided for @changesSavedPending.
  ///
  /// In en, this message translates to:
  /// **'Changes saved here · sync pending'**
  String get changesSavedPending;

  /// No description provided for @localMaps.
  ///
  /// In en, this message translates to:
  /// **'Local maps'**
  String get localMaps;

  /// No description provided for @mapsStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Maps not prepared: check available storage.'**
  String get mapsStorageUnavailable;

  /// No description provided for @demoNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo: sample GPX and elevations, real map of Florence.'**
  String get demoNotice;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get syncPending;

  /// No description provided for @itemsSaved.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{No items saved on this phone} =1{One item saved on this phone} other{{arg1} items saved on this phone}}'**
  String itemsSaved(int arg1);

  /// No description provided for @mapSaved.
  ///
  /// In en, this message translates to:
  /// **'Map verified and saved offline'**
  String get mapSaved;

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone · sync will resume'**
  String get syncRetry;

  /// No description provided for @sessionRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the saved session. Please sign in again.'**
  String get sessionRestoreFailed;

  /// No description provided for @localDev.
  ///
  /// In en, this message translates to:
  /// **'Local Dev (Docker)'**
  String get localDev;

  /// No description provided for @missingApiUrl.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: set API_URL in {arg2}, then restart F5. Offline access requires a successful first sign-in.'**
  String missingApiUrl(Object arg1, Object arg2);

  /// No description provided for @invalidApiUrl.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: invalid API URL in {arg2} (no credentials, query or fragment allowed).'**
  String invalidApiUrl(Object arg1, Object arg2);

  /// No description provided for @localhostApiUrl.
  ///
  /// In en, this message translates to:
  /// **'{arg1}: localhost refers to the phone. Use your computer\'s LAN IP in {arg2}.'**
  String localhostApiUrl(Object arg1, Object arg2);

  /// No description provided for @prodHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Prod: API_URL must start with https:// in {arg1}. No request will be sent.'**
  String prodHttpsRequired(Object arg1);

  /// No description provided for @devPrivateIpRequired.
  ///
  /// In en, this message translates to:
  /// **'Dev: HTTP requires a private LAN IPv4 address (10.x, 172.16–31.x or 192.168.x). Otherwise use HTTPS.'**
  String get devPrivateIpRequired;

  /// No description provided for @mapProgress.
  ///
  /// In en, this message translates to:
  /// **'Maps: {arg1}/{arg2} areas · {arg3}%'**
  String mapProgress(Object arg1, Object arg2, Object arg3);

  /// No description provided for @savedAreas.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{0 areas saved on this phone} =1{1 area saved on this phone} other{{arg1} areas saved on this phone}}'**
  String savedAreas(int arg1);

  /// No description provided for @mapPreparationPending.
  ///
  /// In en, this message translates to:
  /// **'Preparation pending · connection or storage unavailable. Maps already received remain available.'**
  String get mapPreparationPending;

  /// No description provided for @freeWalk.
  ///
  /// In en, this message translates to:
  /// **'Free walk'**
  String get freeWalk;

  /// No description provided for @recordingSuspended.
  ///
  /// In en, this message translates to:
  /// **'Recording suspended: {arg1}'**
  String recordingSuspended(Object arg1);

  /// No description provided for @walkSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot save this walk: {arg1}'**
  String walkSaveFailed(Object arg1);

  /// No description provided for @syncRunning.
  ///
  /// In en, this message translates to:
  /// **'Sync in progress'**
  String get syncRunning;

  /// No description provided for @librarySynced.
  ///
  /// In en, this message translates to:
  /// **'Library synced'**
  String get librarySynced;

  /// No description provided for @syncConflicts.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{No conflicts} =1{1 conflict: local copy preserved. Resolve it in settings.} other{{arg1} conflicts: local copies preserved. Resolve them in settings.}}'**
  String syncConflicts(int arg1);

  /// No description provided for @waitForSync.
  ///
  /// In en, this message translates to:
  /// **'Wait for sync to finish.'**
  String get waitForSync;

  /// No description provided for @legacyAccountDenied.
  ///
  /// In en, this message translates to:
  /// **'This account cannot import the previous library.'**
  String get legacyAccountDenied;

  /// No description provided for @libraryAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This library already belongs to another account or server.'**
  String get libraryAlreadyOwned;

  /// No description provided for @approachUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Walking route unavailable. Connect to the server and Internet, then try again. No saved route passes near your position.'**
  String get approachUnavailable;

  /// No description provided for @noNearbyPath.
  ///
  /// In en, this message translates to:
  /// **'No accessible path close enough to your position or the joining point.'**
  String get noNearbyPath;

  /// No description provided for @routeTooLong.
  ///
  /// In en, this message translates to:
  /// **'Route too long'**
  String get routeTooLong;

  /// No description provided for @invalidGeometry.
  ///
  /// In en, this message translates to:
  /// **'Invalid geometry'**
  String get invalidGeometry;

  /// No description provided for @invalidCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Invalid coordinates'**
  String get invalidCoordinates;

  /// No description provided for @emptyRoute.
  ///
  /// In en, this message translates to:
  /// **'Empty route'**
  String get emptyRoute;

  /// No description provided for @invalidDirections.
  ///
  /// In en, this message translates to:
  /// **'Invalid directions'**
  String get invalidDirections;

  /// No description provided for @missingDirections.
  ///
  /// In en, this message translates to:
  /// **'Missing directions'**
  String get missingDirections;

  /// No description provided for @towardsTrail.
  ///
  /// In en, this message translates to:
  /// **'Towards the trail · {arg1}'**
  String towardsTrail(Object arg1);

  /// No description provided for @demo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demo;

  /// No description provided for @demoFlorence.
  ///
  /// In en, this message translates to:
  /// **'Demo · Florence'**
  String get demoFlorence;

  /// No description provided for @damagedGpx.
  ///
  /// In en, this message translates to:
  /// **'This GPX contains damaged text. Correct it in the original file before importing.'**
  String get damagedGpx;

  /// No description provided for @gpxSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit: 50 MB per GPX.'**
  String get gpxSizeLimit;

  /// No description provided for @incompleteUtf16.
  ///
  /// In en, this message translates to:
  /// **'Incomplete UTF-16 file.'**
  String get incompleteUtf16;

  /// No description provided for @invalidUtf16.
  ///
  /// In en, this message translates to:
  /// **'Invalid UTF-16 text.'**
  String get invalidUtf16;

  /// No description provided for @unsupportedGpxEncoding.
  ///
  /// In en, this message translates to:
  /// **'Unsupported GPX encoding: {arg1}. Export the file as UTF-8.'**
  String unsupportedGpxEncoding(Object arg1);

  /// No description provided for @localCopy.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · local copy'**
  String localCopy(Object arg1);

  /// No description provided for @libraryClosed.
  ///
  /// In en, this message translates to:
  /// **'Library closed'**
  String get libraryClosed;

  /// No description provided for @downloadStalled.
  ///
  /// In en, this message translates to:
  /// **'Download stalled'**
  String get downloadStalled;

  /// No description provided for @invalidMapCatalog.
  ///
  /// In en, this message translates to:
  /// **'Invalid map catalog.'**
  String get invalidMapCatalog;

  /// No description provided for @downloadRunning.
  ///
  /// In en, this message translates to:
  /// **'Download already in progress.'**
  String get downloadRunning;

  /// No description provided for @mapHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Package rejected: HTTPS required, except HTTP from the same Dev LAN server.'**
  String get mapHttpsRequired;

  /// No description provided for @incorrectPackageSize.
  ///
  /// In en, this message translates to:
  /// **'Incorrect package size.'**
  String get incorrectPackageSize;

  /// No description provided for @packageIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'Incomplete package or failed integrity check.'**
  String get packageIntegrityFailed;

  /// No description provided for @forbiddenPackagePath.
  ///
  /// In en, this message translates to:
  /// **'Package path not allowed.'**
  String get forbiddenPackagePath;

  /// No description provided for @unpackedPackageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Unpacked package too large.'**
  String get unpackedPackageTooLarge;

  /// No description provided for @waitForDownload.
  ///
  /// In en, this message translates to:
  /// **'Wait for the download to finish.'**
  String get waitForDownload;

  /// No description provided for @missingMapArchive.
  ///
  /// In en, this message translates to:
  /// **'Missing map style or archive.'**
  String get missingMapArchive;

  /// No description provided for @invalidPath.
  ///
  /// In en, this message translates to:
  /// **'Invalid path.'**
  String get invalidPath;

  /// No description provided for @damagedResource.
  ///
  /// In en, this message translates to:
  /// **'Missing or damaged resource.'**
  String get damagedResource;

  /// No description provided for @invalidPmtiles.
  ///
  /// In en, this message translates to:
  /// **'Invalid PMTiles v3 archive.'**
  String get invalidPmtiles;

  /// No description provided for @truncatedPmtiles.
  ///
  /// In en, this message translates to:
  /// **'Truncated PMTiles archive.'**
  String get truncatedPmtiles;

  /// No description provided for @unsupportedMapStyle.
  ///
  /// In en, this message translates to:
  /// **'Unsupported style version.'**
  String get unsupportedMapStyle;

  /// No description provided for @localPmtilesRequired.
  ///
  /// In en, this message translates to:
  /// **'The map must use only local PMTiles archives.'**
  String get localPmtilesRequired;

  /// No description provided for @nonLocalGraphics.
  ///
  /// In en, this message translates to:
  /// **'Graphics resources are not local.'**
  String get nonLocalGraphics;

  /// No description provided for @externalMapResource.
  ///
  /// In en, this message translates to:
  /// **'A map resource depends on the network or an external file.'**
  String get externalMapResource;

  /// No description provided for @unsupportedGlyphTemplate.
  ///
  /// In en, this message translates to:
  /// **'Unsupported glyph template.'**
  String get unsupportedGlyphTemplate;

  /// No description provided for @missingFonts.
  ///
  /// In en, this message translates to:
  /// **'Missing local fonts.'**
  String get missingFonts;

  /// No description provided for @incompleteGlyphs.
  ///
  /// In en, this message translates to:
  /// **'Incomplete glyph set.'**
  String get incompleteGlyphs;

  /// No description provided for @undeclaredResource.
  ///
  /// In en, this message translates to:
  /// **'Undeclared local resource.'**
  String get undeclaredResource;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable location on your phone.'**
  String get enableLocation;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location is required for tracking. Allow it in Android settings.'**
  String get locationPermissionRequired;

  /// No description provided for @recordingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Gpix · walk in progress'**
  String get recordingNotificationTitle;

  /// No description provided for @recordingNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Your walk is being recorded. Open Gpix to pause or finish.'**
  String get recordingNotificationBody;

  /// No description provided for @recordingChannel.
  ///
  /// In en, this message translates to:
  /// **'Walk recording'**
  String get recordingChannel;

  /// No description provided for @incompleteElevations.
  ///
  /// In en, this message translates to:
  /// **'Incomplete elevation response.'**
  String get incompleteElevations;

  /// No description provided for @sessionChanged.
  ///
  /// In en, this message translates to:
  /// **'The session has changed.'**
  String get sessionChanged;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server unavailable (HTTP {arg1}).'**
  String serverUnavailable(Object arg1);

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue.'**
  String get signInRequired;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @mapAddressRejected.
  ///
  /// In en, this message translates to:
  /// **'Map address rejected.'**
  String get mapAddressRejected;

  /// No description provided for @gpxTooLarge.
  ///
  /// In en, this message translates to:
  /// **'GPX too large (50 MB maximum).'**
  String get gpxTooLarge;

  /// No description provided for @xmlEntitiesForbidden.
  ///
  /// In en, this message translates to:
  /// **'XML entities are not allowed.'**
  String get xmlEntitiesForbidden;

  /// No description provided for @notGpx.
  ///
  /// In en, this message translates to:
  /// **'This file is not a GPX.'**
  String get notGpx;

  /// No description provided for @invalidGpxCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Invalid GPX coordinates.'**
  String get invalidGpxCoordinates;

  /// No description provided for @emptyGpx.
  ///
  /// In en, this message translates to:
  /// **'No trail or point of interest in this GPX.'**
  String get emptyGpx;

  /// No description provided for @invalidUsername.
  ///
  /// In en, this message translates to:
  /// **'3 to 32 letters, digits or underscores.'**
  String get invalidUsername;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'The password must contain 8 to 128 characters.'**
  String get invalidPassword;

  /// No description provided for @invalidMapArea.
  ///
  /// In en, this message translates to:
  /// **'Invalid map area'**
  String get invalidMapArea;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gpix · On the trail'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @myTrails.
  ///
  /// In en, this message translates to:
  /// **'My trails'**
  String get myTrails;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @joyOfWalking.
  ///
  /// In en, this message translates to:
  /// **'THE JOY OF MOVING FORWARD'**
  String get joyOfWalking;

  /// No description provided for @nextTrailStartsHere.
  ///
  /// In en, this message translates to:
  /// **'Your next trail\nstarts here.'**
  String get nextTrailStartsHere;

  /// No description provided for @libraryIntro.
  ///
  /// In en, this message translates to:
  /// **'Your trails, your places. Ready to go with you, even without a connection.'**
  String get libraryIntro;

  /// No description provided for @importGpx.
  ///
  /// In en, this message translates to:
  /// **'Import a GPX'**
  String get importGpx;

  /// No description provided for @tryDemo.
  ///
  /// In en, this message translates to:
  /// **'Try the demo · Florence'**
  String get tryDemo;

  /// No description provided for @myLibrary.
  ///
  /// In en, this message translates to:
  /// **'My library'**
  String get myLibrary;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{0 items} =1{1 item} other{{arg1} items}}'**
  String itemCount(int arg1);

  /// No description provided for @oneJourney.
  ///
  /// In en, this message translates to:
  /// **'A whole journey, one trail.'**
  String get oneJourney;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Import your Camino trail or a file of points of interest. No need to split it into stages.'**
  String get importIntro;

  /// No description provided for @pointCount.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{0 points of interest} =1{1 point of interest} other{{arg1} points of interest}}'**
  String pointCount(int arg1);

  /// No description provided for @segmentCount.
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2, plural, =0{0 segments} =1{1 segment} other{{arg2} segments}}'**
  String segmentCount(Object arg1, int arg2);

  /// No description provided for @mapReady.
  ///
  /// In en, this message translates to:
  /// **'Map ready offline'**
  String get mapReady;

  /// No description provided for @mapNeedsPreparation.
  ///
  /// In en, this message translates to:
  /// **'Map needs preparation'**
  String get mapNeedsPreparation;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places saved on this phone'**
  String get savedPlaces;

  /// No description provided for @joinTrail.
  ///
  /// In en, this message translates to:
  /// **'Join the trail'**
  String get joinTrail;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @deleteItemQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteItemQuestion;

  /// No description provided for @deleteItemBody.
  ///
  /// In en, this message translates to:
  /// **'This deletion will also be synced with your server.'**
  String get deleteItemBody;

  /// No description provided for @offlineHeadline.
  ///
  /// In en, this message translates to:
  /// **'Peace of mind.\nEven offline.'**
  String get offlineHeadline;

  /// No description provided for @sharedMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps are shared between your trails and stored on your phone.'**
  String get sharedMaps;

  /// No description provided for @automaticMapsInfo.
  ///
  /// In en, this message translates to:
  /// **'Visible areas load automatically online. Each GPX prepares its maps in the background. Offline, only downloaded areas remain visible.'**
  String get automaticMapsInfo;

  /// No description provided for @resumePreparation.
  ///
  /// In en, this message translates to:
  /// **'Resume preparation'**
  String get resumePreparation;

  /// No description provided for @readyOffline.
  ///
  /// In en, this message translates to:
  /// **'Ready offline'**
  String get readyOffline;

  /// No description provided for @preparingMaps.
  ///
  /// In en, this message translates to:
  /// **'Automatic preparation running or pending'**
  String get preparingMaps;

  /// No description provided for @loadCatalog.
  ///
  /// In en, this message translates to:
  /// **'Load my server\'s catalog'**
  String get loadCatalog;

  /// No description provided for @prepareTrails.
  ///
  /// In en, this message translates to:
  /// **'Prepare my trails · {arg1} MB'**
  String prepareTrails(Object arg1);

  /// No description provided for @completeElevations.
  ///
  /// In en, this message translates to:
  /// **'Complete elevations for the open trail'**
  String get completeElevations;

  /// No description provided for @onMyPhone.
  ///
  /// In en, this message translates to:
  /// **'On my phone'**
  String get onMyPhone;

  /// No description provided for @noInstalledMaps.
  ///
  /// In en, this message translates to:
  /// **'No map installed. Configure your server and its catalog in settings. GPX files remain viewable.'**
  String get noInstalledMaps;

  /// No description provided for @deleteMap.
  ///
  /// In en, this message translates to:
  /// **'Delete this map'**
  String get deleteMap;

  /// No description provided for @availableRegions.
  ///
  /// In en, this message translates to:
  /// **'Available regions'**
  String get availableRegions;

  /// No description provided for @coversOpenTrail.
  ///
  /// In en, this message translates to:
  /// **' · covers the open trail'**
  String get coversOpenTrail;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @removeMapQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this map?'**
  String get removeMapQuestion;

  /// No description provided for @affectedTrails.
  ///
  /// In en, this message translates to:
  /// **'Affected trails: {arg1}. Their map may become unavailable offline.'**
  String affectedTrails(Object arg1);

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get none;

  /// No description provided for @mapSizeVersion.
  ///
  /// In en, this message translates to:
  /// **'{arg1} MB · {arg2}'**
  String mapSizeVersion(Object arg1, Object arg2);

  /// No description provided for @mapSizeCoverage.
  ///
  /// In en, this message translates to:
  /// **'{arg1} MB{arg2}'**
  String mapSizeCoverage(Object arg1, Object arg2);

  /// No description provided for @libraryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open your library. Your data is preserved.'**
  String get libraryOpenFailed;

  /// No description provided for @libraryAdoptFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot attach the library. Existing files are preserved.'**
  String get libraryAdoptFailed;

  /// No description provided for @previousLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your previous library'**
  String get previousLibrary;

  /// No description provided for @previousLibraryInfo.
  ///
  /// In en, this message translates to:
  /// **'Trails and maps from your previous installation are on this phone. Their original server cannot be confirmed.'**
  String get previousLibraryInfo;

  /// No description provided for @adoptLibraryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Attach them to {arg1} on this server?'**
  String adoptLibraryQuestion(Object arg1);

  /// No description provided for @adoptLibraryInfo.
  ///
  /// In en, this message translates to:
  /// **'Importing allows these data and pending changes to sync with this account. With a separate library, the old files are preserved but neither displayed nor synced.'**
  String get adoptLibraryInfo;

  /// No description provided for @importExistingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import my existing library'**
  String get importExistingLibrary;

  /// No description provided for @useSeparateLibrary.
  ///
  /// In en, this message translates to:
  /// **'Use a separate library'**
  String get useSeparateLibrary;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @openingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Opening your space…'**
  String get openingLibrary;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'If this address belongs to an account, an email will explain what to do. Copy its code below.'**
  String get resetEmailSent;

  /// No description provided for @passwordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password saved. Sign in with your new password.'**
  String get passwordSaved;

  /// No description provided for @loginHeading.
  ///
  /// In en, this message translates to:
  /// **'Your trail starts here.'**
  String get loginHeading;

  /// No description provided for @registerHeading.
  ///
  /// In en, this message translates to:
  /// **'Your next adventure.'**
  String get registerHeading;

  /// No description provided for @forgotHeading.
  ///
  /// In en, this message translates to:
  /// **'Recover your account.'**
  String get forgotHeading;

  /// No description provided for @resetHeading.
  ///
  /// In en, this message translates to:
  /// **'A fresh start.'**
  String get resetHeading;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Create my account'**
  String get createMyAccount;

  /// No description provided for @sendInstructions.
  ///
  /// In en, this message translates to:
  /// **'Send instructions'**
  String get sendInstructions;

  /// No description provided for @savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePassword;

  /// No description provided for @authIntro.
  ///
  /// In en, this message translates to:
  /// **'Your trails, your maps, your freedom. Sign in once, then head out even offline.'**
  String get authIntro;

  /// No description provided for @identifier.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get identifier;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get email;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Code or link received by email'**
  String get resetCode;

  /// No description provided for @resetCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Copy the complete code or link from the email.'**
  String get resetCodeHint;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccount;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// No description provided for @haveResetCode.
  ///
  /// In en, this message translates to:
  /// **'I have a reset code'**
  String get haveResetCode;

  /// No description provided for @serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server · {arg1}'**
  String serverLabel(Object arg1);

  /// No description provided for @configureServer.
  ///
  /// In en, this message translates to:
  /// **'Configure the address in the launch profile'**
  String get configureServer;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myAccount;

  /// No description provided for @offlineSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Your session allows offline access to your library. Server revocation is checked when the connection returns.'**
  String get offlineSessionInfo;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @apiConfigurationInfo.
  ///
  /// In en, this message translates to:
  /// **'Set the API address in the launch profile\'s local file, then restart F5.'**
  String get apiConfigurationInfo;

  /// No description provided for @resolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve conflicts: keep both copies'**
  String get resolveConflicts;

  /// No description provided for @signOutInfo.
  ///
  /// In en, this message translates to:
  /// **'Signing out locks this space on this phone. Your local trails are kept for your next sign-in.'**
  String get signOutInfo;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @estimatedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · estimated'**
  String get estimatedSuffix;

  /// No description provided for @partialSuffix.
  ///
  /// In en, this message translates to:
  /// **' · partial'**
  String get partialSuffix;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Around me'**
  String get nearMe;

  /// No description provided for @wholeTrail.
  ///
  /// In en, this message translates to:
  /// **'Whole trail'**
  String get wholeTrail;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable · tracking still works'**
  String get profileUnavailable;

  /// No description provided for @distanceAlongTrail.
  ///
  /// In en, this message translates to:
  /// **'Distance along the trail'**
  String get distanceAlongTrail;

  /// No description provided for @altitudeTitle.
  ///
  /// In en, this message translates to:
  /// **'Altitude{arg1}{arg2}'**
  String altitudeTitle(Object arg1, Object arg2);

  /// No description provided for @finishWalkQuestion.
  ///
  /// In en, this message translates to:
  /// **'Finish this walk?'**
  String get finishWalkQuestion;

  /// No description provided for @finishWalkInfo.
  ///
  /// In en, this message translates to:
  /// **'Your route and measurements will be saved in history and synced with your account.'**
  String get finishWalkInfo;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @saveWalk.
  ///
  /// In en, this message translates to:
  /// **'Save walk'**
  String get saveWalk;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @importWatchData.
  ///
  /// In en, this message translates to:
  /// **'Add watch measurements'**
  String get importWatchData;

  /// No description provided for @watchSettings.
  ///
  /// In en, this message translates to:
  /// **'Watch settings'**
  String get watchSettings;

  /// No description provided for @deleteWalkQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this walk?'**
  String get deleteWalkQuestion;

  /// No description provided for @deleteWalkInfo.
  ///
  /// In en, this message translates to:
  /// **'The deletion will be synced with your account.'**
  String get deleteWalkInfo;

  /// No description provided for @deleteWalk.
  ///
  /// In en, this message translates to:
  /// **'Delete walk'**
  String get deleteWalk;

  /// No description provided for @myWalks.
  ///
  /// In en, this message translates to:
  /// **'My walks'**
  String get myWalks;

  /// No description provided for @walkHistoryInfo.
  ///
  /// In en, this message translates to:
  /// **'The paths you have actually walked.'**
  String get walkHistoryInfo;

  /// No description provided for @recordingActive.
  ///
  /// In en, this message translates to:
  /// **'● Recording in progress'**
  String get recordingActive;

  /// No description provided for @walkPaused.
  ///
  /// In en, this message translates to:
  /// **'Walk paused · ready to resume'**
  String get walkPaused;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @liveStats.
  ///
  /// In en, this message translates to:
  /// **'My live data'**
  String get liveStats;

  /// No description provided for @recordFreeWalk.
  ///
  /// In en, this message translates to:
  /// **'Record a free walk'**
  String get recordFreeWalk;

  /// No description provided for @walkCountDistance.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{0 walks} =1{1 walk} other{{arg1} walks}} · {arg2}'**
  String walkCountDistance(int arg1, Object arg2);

  /// No description provided for @viewAllWalkedPlaces.
  ///
  /// In en, this message translates to:
  /// **'View everywhere I have walked'**
  String get viewAllWalkedPlaces;

  /// No description provided for @allWalks.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allWalks;

  /// No description provided for @withGpx.
  ///
  /// In en, this message translates to:
  /// **'With GPX'**
  String get withGpx;

  /// No description provided for @freeWalks.
  ///
  /// In en, this message translates to:
  /// **'Free walks'**
  String get freeWalks;

  /// No description provided for @noWalks.
  ///
  /// In en, this message translates to:
  /// **'No walks here yet. Start a GPX with Go or record a free walk.'**
  String get noWalks;

  /// No description provided for @unreadableFilename.
  ///
  /// In en, this message translates to:
  /// **'Unreadable file name'**
  String get unreadableFilename;

  /// No description provided for @unreadableFilenameInfo.
  ///
  /// In en, this message translates to:
  /// **'The phone provided a damaged name. Enter the trail name to preserve the correct characters.'**
  String get unreadableFilenameInfo;

  /// No description provided for @trailName.
  ///
  /// In en, this message translates to:
  /// **'Trail name'**
  String get trailName;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get enterName;

  /// No description provided for @replaceDamagedText.
  ///
  /// In en, this message translates to:
  /// **'Replace the damaged characters.'**
  String get replaceDamagedText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @cannotOpenNavigation.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the app or browser.'**
  String get cannotOpenNavigation;

  /// No description provided for @nearestJoinInfo.
  ///
  /// In en, this message translates to:
  /// **'Towards the GPX point closest to your position.'**
  String get nearestJoinInfo;

  /// No description provided for @reverseSuffix.
  ///
  /// In en, this message translates to:
  /// **' · reverse direction'**
  String get reverseSuffix;

  /// No description provided for @walkInGpix.
  ///
  /// In en, this message translates to:
  /// **'Walk with Gpix'**
  String get walkInGpix;

  /// No description provided for @onlineRouteInfo.
  ///
  /// In en, this message translates to:
  /// **'Map guidance · online calculation'**
  String get onlineRouteInfo;

  /// No description provided for @walkInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Walk with Google Maps'**
  String get walkInGoogleMaps;

  /// No description provided for @driveInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Drive with Google Maps'**
  String get driveInGoogleMaps;

  /// No description provided for @routingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The routing service uses your position and the closest point. Gpix saves the calculated route so you can continue offline.'**
  String get routingPrivacy;

  /// No description provided for @myMap.
  ///
  /// In en, this message translates to:
  /// **'My map'**
  String get myMap;

  /// No description provided for @trailMapAvailable.
  ///
  /// In en, this message translates to:
  /// **'Trail map available offline'**
  String get trailMapAvailable;

  /// No description provided for @visibleMapsInfo.
  ///
  /// In en, this message translates to:
  /// **'Visible areas load automatically online.'**
  String get visibleMapsInfo;

  /// No description provided for @offlineMapsInfo.
  ///
  /// In en, this message translates to:
  /// **'Offline, only downloaded areas are visible.'**
  String get offlineMapsInfo;

  /// No description provided for @activeTrail.
  ///
  /// In en, this message translates to:
  /// **'Following: {arg1}'**
  String activeTrail(Object arg1);

  /// No description provided for @compassInfo.
  ///
  /// In en, this message translates to:
  /// **'The arrow points towards the top of your phone. The compass button switches between north-up and heading-up.'**
  String get compassInfo;

  /// No description provided for @discardChangesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Leave this edit?'**
  String get discardChangesQuestion;

  /// No description provided for @discardChangesInfo.
  ///
  /// In en, this message translates to:
  /// **'The current section is not saved. Previously saved days are preserved.'**
  String get discardChangesInfo;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @deleteDayQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete day {arg1}?'**
  String deleteDayQuestion(Object arg1);

  /// No description provided for @deleteDayInfo.
  ///
  /// In en, this message translates to:
  /// **'The GPX and other sections are preserved.'**
  String get deleteDayInfo;

  /// No description provided for @trailsOnMap.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{0 trails on my map} =1{1 trail on my map} other{{arg1} trails on my map}}'**
  String trailsOnMap(int arg1);

  /// No description provided for @walkInProgressData.
  ///
  /// In en, this message translates to:
  /// **'Walk in progress · data'**
  String get walkInProgressData;

  /// No description provided for @walkPausedResume.
  ///
  /// In en, this message translates to:
  /// **'Walk paused · resume'**
  String get walkPausedResume;

  /// No description provided for @walkedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places walked'**
  String get walkedPlaces;

  /// No description provided for @offTrailDetails.
  ///
  /// In en, this message translates to:
  /// **'Off trail · details'**
  String get offTrailDetails;

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {arg1}'**
  String dayNumber(Object arg1);

  /// No description provided for @editDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit day {arg1}'**
  String editDayNumber(Object arg1);

  /// No description provided for @tapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap the start on the trail.'**
  String get tapStart;

  /// No description provided for @tapEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap the end on the trail.'**
  String get tapEnd;

  /// No description provided for @reviewSection.
  ///
  /// In en, this message translates to:
  /// **'Highlighted section: review and save.'**
  String get reviewSection;

  /// No description provided for @startBoundary.
  ///
  /// In en, this message translates to:
  /// **'A · Start{arg1}'**
  String startBoundary(Object arg1);

  /// No description provided for @endBoundary.
  ///
  /// In en, this message translates to:
  /// **'B · End{arg1}'**
  String endBoundary(Object arg1);

  /// No description provided for @minimumSection.
  ///
  /// In en, this message translates to:
  /// **'{arg1}{arg2} · minimum 10 m'**
  String minimumSection(Object arg1, Object arg2);

  /// No description provided for @saveDay.
  ///
  /// In en, this message translates to:
  /// **'Save this day'**
  String get saveDay;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @continueFromLastEnd.
  ///
  /// In en, this message translates to:
  /// **'Continue from the last endpoint'**
  String get continueFromLastEnd;

  /// No description provided for @cancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel edit'**
  String get cancelEdit;

  /// No description provided for @myDays.
  ///
  /// In en, this message translates to:
  /// **'My days'**
  String get myDays;

  /// No description provided for @noDays.
  ///
  /// In en, this message translates to:
  /// **'Your first section will appear here.'**
  String get noDays;

  /// No description provided for @dayDistance.
  ///
  /// In en, this message translates to:
  /// **'Day {arg1} · {arg2}'**
  String dayDistance(Object arg1, Object arg2);

  /// No description provided for @deleteDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Delete day {arg1}'**
  String deleteDayNumber(Object arg1);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get remaining;

  /// No description provided for @distanceToTrail.
  ///
  /// In en, this message translates to:
  /// **'to the trail'**
  String get distanceToTrail;

  /// No description provided for @toggleDetails.
  ///
  /// In en, this message translates to:
  /// **'Expand or collapse details'**
  String get toggleDetails;

  /// No description provided for @trailReached.
  ///
  /// In en, this message translates to:
  /// **'Trail reached'**
  String get trailReached;

  /// No description provided for @readyToFollow.
  ///
  /// In en, this message translates to:
  /// **'Ready to follow your GPX.'**
  String get readyToFollow;

  /// No description provided for @findingAccuratePosition.
  ///
  /// In en, this message translates to:
  /// **'Looking for an accurate GPS position…'**
  String get findingAccuratePosition;

  /// No description provided for @routeEndGap.
  ///
  /// In en, this message translates to:
  /// **'End of the calculated path. Joining point {arg1} m away, marker R: check access on site.'**
  String routeEndGap(Object arg1);

  /// No description provided for @leftApproach.
  ///
  /// In en, this message translates to:
  /// **'You have left the approach route. Recalculate for directions from here.'**
  String get leftApproach;

  /// No description provided for @inMetres.
  ///
  /// In en, this message translates to:
  /// **'In {arg1} m'**
  String inMetres(Object arg1);

  /// No description provided for @followFromHere.
  ///
  /// In en, this message translates to:
  /// **'Follow the GPX from here'**
  String get followFromHere;

  /// No description provided for @exitApproach.
  ///
  /// In en, this message translates to:
  /// **'Exit approach guidance'**
  String get exitApproach;

  /// No description provided for @recalculate.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get recalculate;

  /// No description provided for @otherNavigation.
  ///
  /// In en, this message translates to:
  /// **'Other navigation'**
  String get otherNavigation;

  /// No description provided for @cachedRouteInfo.
  ///
  /// In en, this message translates to:
  /// **'Saved route · online recalculation only'**
  String get cachedRouteInfo;

  /// No description provided for @savedWalkingApproach.
  ///
  /// In en, this message translates to:
  /// **'Walking approach · route saved on this phone'**
  String get savedWalkingApproach;

  /// No description provided for @fixMap.
  ///
  /// In en, this message translates to:
  /// **'Fix the map'**
  String get fixMap;

  /// No description provided for @pauseTracking.
  ///
  /// In en, this message translates to:
  /// **'Pause tracking'**
  String get pauseTracking;

  /// No description provided for @resumeApproach.
  ///
  /// In en, this message translates to:
  /// **'Resume towards the trail'**
  String get resumeApproach;

  /// No description provided for @followTrail.
  ///
  /// In en, this message translates to:
  /// **'Go · follow this trail'**
  String get followTrail;

  /// No description provided for @returnToTracking.
  ///
  /// In en, this message translates to:
  /// **'Return to tracking · {arg1}'**
  String returnToTracking(Object arg1);

  /// No description provided for @findingPosition.
  ///
  /// In en, this message translates to:
  /// **'Finding your position…'**
  String get findingPosition;

  /// No description provided for @poorGps.
  ///
  /// In en, this message translates to:
  /// **'Old position or low GPS accuracy'**
  String get poorGps;

  /// No description provided for @gpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy ± {arg1} m'**
  String gpsAccuracy(Object arg1);

  /// No description provided for @leavingTrail.
  ///
  /// In en, this message translates to:
  /// **'You are moving away from the trail'**
  String get leavingTrail;

  /// No description provided for @muteAlert.
  ///
  /// In en, this message translates to:
  /// **'Mute alert'**
  String get muteAlert;

  /// No description provided for @reverseDirection.
  ///
  /// In en, this message translates to:
  /// **'Reverse direction · change'**
  String get reverseDirection;

  /// No description provided for @gpxDirection.
  ///
  /// In en, this message translates to:
  /// **'GPX direction · change'**
  String get gpxDirection;

  /// No description provided for @currentWalk.
  ///
  /// In en, this message translates to:
  /// **'My current walk'**
  String get currentWalk;

  /// No description provided for @walkControls.
  ///
  /// In en, this message translates to:
  /// **'Pause, finish and history'**
  String get walkControls;

  /// No description provided for @planDays.
  ///
  /// In en, this message translates to:
  /// **'Plan my days'**
  String get planDays;

  /// No description provided for @editDays.
  ///
  /// In en, this message translates to:
  /// **'{arg1, plural, =0{My days} =1{My day} other{My {arg1} days}} · edit'**
  String editDays(int arg1);

  /// No description provided for @offlineAvailability.
  ///
  /// In en, this message translates to:
  /// **'Offline availability'**
  String get offlineAvailability;

  /// No description provided for @myFreeWalk.
  ///
  /// In en, this message translates to:
  /// **'My free walk'**
  String get myFreeWalk;

  /// No description provided for @mapAroundYou.
  ///
  /// In en, this message translates to:
  /// **'Your map, around you'**
  String get mapAroundYou;

  /// No description provided for @allTrailsInfo.
  ///
  /// In en, this message translates to:
  /// **'All your trails are visible. Tap a trail to select it.'**
  String get allTrailsInfo;

  /// No description provided for @accountServer.
  ///
  /// In en, this message translates to:
  /// **'Account and server'**
  String get accountServer;

  /// No description provided for @accountServerInfo.
  ///
  /// In en, this message translates to:
  /// **'Identity, password and sync'**
  String get accountServerInfo;

  /// No description provided for @watchHealthData.
  ///
  /// In en, this message translates to:
  /// **'Watch and health data'**
  String get watchHealthData;

  /// No description provided for @healthBridge.
  ///
  /// In en, this message translates to:
  /// **'Amazfit / Zepp · Health Connect'**
  String get healthBridge;

  /// No description provided for @myData.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get myData;

  /// No description provided for @syncDataInfo.
  ///
  /// In en, this message translates to:
  /// **'Trails, days and walks are saved on this phone, then synced with your API. Sign in to the same account to find them on another phone. Maps must be downloaded again on that device.'**
  String get syncDataInfo;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @watchHealth.
  ///
  /// In en, this message translates to:
  /// **'Watch and health'**
  String get watchHealth;

  /// No description provided for @yourWatchMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Your watch, your measurements'**
  String get yourWatchMeasurements;

  /// No description provided for @compatibleWatches.
  ///
  /// In en, this message translates to:
  /// **'Amazfit Active Max and other compatible watches: measurements pass through Zepp and Health Connect. Other brands can use the same bridge.'**
  String get compatibleWatches;

  /// No description provided for @checkingHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Checking Health Connect…'**
  String get checkingHealthConnect;

  /// No description provided for @healthAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Health Connect access authorized · check measurement availability in a walk'**
  String get healthAuthorized;

  /// No description provided for @healthPermissionsMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing or partial permissions'**
  String get healthPermissionsMissing;

  /// No description provided for @healthInstallRequired.
  ///
  /// In en, this message translates to:
  /// **'Health Connect must be installed or updated'**
  String get healthInstallRequired;

  /// No description provided for @healthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Health Connect unavailable on this device'**
  String get healthUnavailable;

  /// No description provided for @healthSetupSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Sync your watch in Zepp.\n\n2. Enable sharing with Health Connect in Zepp connections.\n\n3. Authorize Gpix below. In a walk, tap “Add watch measurements”.'**
  String get healthSetupSteps;

  /// No description provided for @openZepp.
  ///
  /// In en, this message translates to:
  /// **'Open Zepp'**
  String get openZepp;

  /// No description provided for @installHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Install Health Connect'**
  String get installHealthConnect;

  /// No description provided for @authorizeMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Authorize measurements'**
  String get authorizeMeasurements;

  /// No description provided for @manageHealthPermissions.
  ///
  /// In en, this message translates to:
  /// **'Manage or revoke permissions'**
  String get manageHealthPermissions;

  /// No description provided for @supportedMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Supported measurements'**
  String get supportedMeasurements;

  /// No description provided for @supportedMeasurementsInfo.
  ///
  /// In en, this message translates to:
  /// **'Average and maximum heart rate, steps and active calories during your walk. Data depends on the model and what Zepp shares. This is not a live Bluetooth connection.'**
  String get supportedMeasurementsInfo;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @healthPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data is read only when you request it. Imported measurements are saved with your walk and synced with your personal API. Revoking permission prevents future reads; to erase imported measurements, delete the walk from history.'**
  String get healthPrivacy;

  /// No description provided for @healthDevicePermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions apply to this phone. Grant them again on another device. Health Connect may restrict access to older periods.'**
  String get healthDevicePermissions;

  /// No description provided for @chooseTrailPassage.
  ///
  /// In en, this message translates to:
  /// **'The trail passes here more than once. Which passage do you want?'**
  String get chooseTrailPassage;

  /// No description provided for @atGpxKilometre.
  ///
  /// In en, this message translates to:
  /// **'At GPX kilometre {arg1}'**
  String atGpxKilometre(Object arg1);

  /// No description provided for @tapSelectedTrail.
  ///
  /// In en, this message translates to:
  /// **'Tap the selected trail. Zoom in to place the boundary precisely.'**
  String get tapSelectedTrail;

  /// No description provided for @northUp.
  ///
  /// In en, this message translates to:
  /// **'Switch to north-up'**
  String get northUp;

  /// No description provided for @headingUp.
  ///
  /// In en, this message translates to:
  /// **'Orient with the phone'**
  String get headingUp;

  /// No description provided for @recenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter on my position'**
  String get recenter;

  /// No description provided for @distanceWalked.
  ///
  /// In en, this message translates to:
  /// **'Distance walked'**
  String get distanceWalked;

  /// No description provided for @activeDuration.
  ///
  /// In en, this message translates to:
  /// **'Active duration'**
  String get activeDuration;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total duration'**
  String get totalDuration;

  /// No description provided for @averageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get averageSpeed;

  /// No description provided for @averagePace.
  ///
  /// In en, this message translates to:
  /// **'Average pace'**
  String get averagePace;

  /// No description provided for @maxGpsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max. GPS speed'**
  String get maxGpsSpeed;

  /// No description provided for @ascent.
  ///
  /// In en, this message translates to:
  /// **'Ascent'**
  String get ascent;

  /// No description provided for @descent.
  ///
  /// In en, this message translates to:
  /// **'Descent'**
  String get descent;

  /// No description provided for @altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitude;

  /// No description provided for @minMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Min. / max. altitude'**
  String get minMaxAltitude;

  /// No description provided for @averageHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Average heart rate'**
  String get averageHeartRate;

  /// No description provided for @maxHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Maximum heart rate'**
  String get maxHeartRate;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @activeCalories.
  ///
  /// In en, this message translates to:
  /// **'Active calories'**
  String get activeCalories;

  /// No description provided for @statsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Active duration excludes manual pauses. Average pace and speed use this duration. Elevation changes are estimated from filtered GPS altitudes.'**
  String get statsExplanation;

  /// No description provided for @noImportedWatchData.
  ///
  /// In en, this message translates to:
  /// **'Watch: no measurements imported. Missing values are not estimated.'**
  String get noImportedWatchData;

  /// No description provided for @healthSources.
  ///
  /// In en, this message translates to:
  /// **'Health Connect · {arg1}\nSources: {arg2}'**
  String healthSources(Object arg1, Object arg2);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get systemLanguage;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'This action could not be completed. Check your connection and try again.'**
  String get unexpectedError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Connection unavailable. Your saved data remains on this phone.'**
  String get networkError;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password.'**
  String get invalidCredentials;

  /// No description provided for @invalidSession.
  ///
  /// In en, this message translates to:
  /// **'Invalid session. Please sign in again.'**
  String get invalidSession;

  /// No description provided for @accountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Username or email already in use.'**
  String get accountAlreadyExists;

  /// No description provided for @rateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in 15 minutes.'**
  String get rateLimited;

  /// No description provided for @resetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Email delivery unavailable. Try again later.'**
  String get resetUnavailable;

  /// No description provided for @invalidResetCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code. Request a new code.'**
  String get invalidResetCode;

  /// No description provided for @incorrectCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password.'**
  String get incorrectCurrentPassword;

  /// No description provided for @invalidFields.
  ///
  /// In en, this message translates to:
  /// **'All fields must be text.'**
  String get invalidFields;

  /// No description provided for @unknownOperation.
  ///
  /// In en, this message translates to:
  /// **'Unknown operation.'**
  String get unknownOperation;

  /// No description provided for @formTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Form too large.'**
  String get formTooLarge;

  /// No description provided for @damagedText.
  ///
  /// In en, this message translates to:
  /// **'Text contains a lost character. Correct its name or reimport the original GPX.'**
  String get damagedText;

  /// No description provided for @invalidRouteCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Invalid origin or destination coordinates.'**
  String get invalidRouteCoordinates;

  /// No description provided for @waitBeforeRouting.
  ///
  /// In en, this message translates to:
  /// **'Wait two seconds before recalculating.'**
  String get waitBeforeRouting;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable or resource not found'**
  String get serviceUnavailable;

  /// No description provided for @invalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid request. Check the entered data.'**
  String get invalidRequest;

  /// No description provided for @placesName.
  ///
  /// In en, this message translates to:
  /// **'{name} · places'**
  String placesName(String name);

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @frenchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get frenchLanguage;

  /// No description provided for @guidanceSlightLeft.
  ///
  /// In en, this message translates to:
  /// **'Bear left'**
  String get guidanceSlightLeft;

  /// No description provided for @guidanceLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get guidanceLeft;

  /// No description provided for @guidanceSharpLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp left'**
  String get guidanceSharpLeft;

  /// No description provided for @guidanceUTurn.
  ///
  /// In en, this message translates to:
  /// **'Make a U-turn'**
  String get guidanceUTurn;

  /// No description provided for @guidanceSlightRight.
  ///
  /// In en, this message translates to:
  /// **'Bear right'**
  String get guidanceSlightRight;

  /// No description provided for @guidanceRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get guidanceRight;

  /// No description provided for @guidanceSharpRight.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp right'**
  String get guidanceSharpRight;

  /// No description provided for @guidanceSlightLeftIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, bear left} other{In {metres} metres, bear left}}'**
  String guidanceSlightLeftIn(int metres);

  /// No description provided for @guidanceLeftIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, turn left} other{In {metres} metres, turn left}}'**
  String guidanceLeftIn(int metres);

  /// No description provided for @guidanceSharpLeftIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, turn sharp left} other{In {metres} metres, turn sharp left}}'**
  String guidanceSharpLeftIn(int metres);

  /// No description provided for @guidanceUTurnIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, make a U-turn} other{In {metres} metres, make a U-turn}}'**
  String guidanceUTurnIn(int metres);

  /// No description provided for @guidanceSlightRightIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, bear right} other{In {metres} metres, bear right}}'**
  String guidanceSlightRightIn(int metres);

  /// No description provided for @guidanceRightIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, turn right} other{In {metres} metres, turn right}}'**
  String guidanceRightIn(int metres);

  /// No description provided for @guidanceSharpRightIn.
  ///
  /// In en, this message translates to:
  /// **'{metres, plural, =1{In 1 metre, turn sharp right} other{In {metres} metres, turn sharp right}}'**
  String guidanceSharpRightIn(int metres);

  /// No description provided for @guidanceArrive.
  ///
  /// In en, this message translates to:
  /// **'You have reached the end of the trail'**
  String get guidanceArrive;

  /// No description provided for @guidanceReachTrail.
  ///
  /// In en, this message translates to:
  /// **'You have reached the trail'**
  String get guidanceReachTrail;

  /// No description provided for @guidanceOffTrail.
  ///
  /// In en, this message translates to:
  /// **'You have left the trail'**
  String get guidanceOffTrail;

  /// No description provided for @guidanceOffTrailBody.
  ///
  /// In en, this message translates to:
  /// **'Check the map to rejoin it.'**
  String get guidanceOffTrailBody;

  /// No description provided for @guidanceNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get guidanceNow;

  /// No description provided for @nextDirection.
  ///
  /// In en, this message translates to:
  /// **'Next direction'**
  String get nextDirection;

  /// No description provided for @voiceGuidance.
  ///
  /// In en, this message translates to:
  /// **'Voice guidance'**
  String get voiceGuidance;

  /// No description provided for @voiceGuidanceInfo.
  ///
  /// In en, this message translates to:
  /// **'Speaks each direction change about 100 m ahead during navigation, even with the screen off. While Gpix is in the background, a notification also shows the direction.'**
  String get voiceGuidanceInfo;

  /// No description provided for @voiceGuidanceNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Voice guidance preference not saved on this phone.'**
  String get voiceGuidanceNotSaved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
