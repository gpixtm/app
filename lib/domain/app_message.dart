/// Locale-independent message code and arguments. Resolve at the UI boundary.
class AppMessage {
  const AppMessage(this.code, [this.arguments = const []]);
  final String code;
  final List<Object?> arguments;
  @override
  String toString() => code;
  static const noJoinSegment = AppMessage('noJoinSegment');
  static const alreadyNearTrail = AppMessage('alreadyNearTrail');
  static const cachedApproach = AppMessage('cachedApproach');
  static const gpsUnavailable = AppMessage('gpsUnavailable');
  static const noWatchData = AppMessage('noWatchData');
  static const watchDataAdded = AppMessage('watchDataAdded');
  static const walkSavedPending = AppMessage('walkSavedPending');
  static const changesSavedPending = AppMessage('changesSavedPending');
  static const localMaps = AppMessage('localMaps');
  static const mapsStorageUnavailable = AppMessage('mapsStorageUnavailable');
  static const demoNotice = AppMessage('demoNotice');
  static const syncPending = AppMessage('syncPending');
  static AppMessage itemsSaved(Object? arg1) =>
      AppMessage('itemsSaved', [arg1]);
  static const mapSaved = AppMessage('mapSaved');
  static const syncRetry = AppMessage('syncRetry');
  static const sessionRestoreFailed = AppMessage('sessionRestoreFailed');
  static AppMessage missingApiUrl(Object? arg1, Object? arg2) =>
      AppMessage('missingApiUrl', [arg1, arg2]);
  static AppMessage invalidApiUrl(Object? arg1, Object? arg2) =>
      AppMessage('invalidApiUrl', [arg1, arg2]);
  static AppMessage localhostApiUrl(Object? arg1, Object? arg2) =>
      AppMessage('localhostApiUrl', [arg1, arg2]);
  static AppMessage prodHttpsRequired(Object? arg1) =>
      AppMessage('prodHttpsRequired', [arg1]);
  static const devPrivateIpRequired = AppMessage('devPrivateIpRequired');
  static AppMessage mapProgress(Object? arg1, Object? arg2, Object? arg3) =>
      AppMessage('mapProgress', [arg1, arg2, arg3]);
  static AppMessage savedAreas(Object? arg1) =>
      AppMessage('savedAreas', [arg1]);
  static const mapPreparationPending = AppMessage('mapPreparationPending');
  static AppMessage recordingSuspended(Object? arg1) =>
      AppMessage('recordingSuspended', [arg1]);
  static AppMessage walkSaveFailed(Object? arg1) =>
      AppMessage('walkSaveFailed', [arg1]);
  static const syncRunning = AppMessage('syncRunning');
  static const librarySynced = AppMessage('librarySynced');
  static AppMessage syncConflicts(Object? arg1) =>
      AppMessage('syncConflicts', [arg1]);
  static const waitForSync = AppMessage('waitForSync');
  static const legacyAccountDenied = AppMessage('legacyAccountDenied');
  static const libraryAlreadyOwned = AppMessage('libraryAlreadyOwned');
  static const approachUnavailable = AppMessage('approachUnavailable');
  static const noNearbyPath = AppMessage('noNearbyPath');
  static const routeTooLong = AppMessage('routeTooLong');
  static const invalidGeometry = AppMessage('invalidGeometry');
  static const invalidCoordinates = AppMessage('invalidCoordinates');
  static const emptyRoute = AppMessage('emptyRoute');
  static const invalidDirections = AppMessage('invalidDirections');
  static const missingDirections = AppMessage('missingDirections');
  static const damagedGpx = AppMessage('damagedGpx');
  static const gpxSizeLimit = AppMessage('gpxSizeLimit');
  static const incompleteUtf16 = AppMessage('incompleteUtf16');
  static const invalidUtf16 = AppMessage('invalidUtf16');
  static AppMessage unsupportedGpxEncoding(Object? arg1) =>
      AppMessage('unsupportedGpxEncoding', [arg1]);
  static const libraryClosed = AppMessage('libraryClosed');
  static const downloadStalled = AppMessage('downloadStalled');
  static const invalidMapCatalog = AppMessage('invalidMapCatalog');
  static const downloadRunning = AppMessage('downloadRunning');
  static const mapHttpsRequired = AppMessage('mapHttpsRequired');
  static const incorrectPackageSize = AppMessage('incorrectPackageSize');
  static const packageIntegrityFailed = AppMessage('packageIntegrityFailed');
  static const forbiddenPackagePath = AppMessage('forbiddenPackagePath');
  static const unpackedPackageTooLarge = AppMessage('unpackedPackageTooLarge');
  static const waitForDownload = AppMessage('waitForDownload');
  static const missingMapArchive = AppMessage('missingMapArchive');
  static const invalidPath = AppMessage('invalidPath');
  static const damagedResource = AppMessage('damagedResource');
  static const invalidPmtiles = AppMessage('invalidPmtiles');
  static const truncatedPmtiles = AppMessage('truncatedPmtiles');
  static const unsupportedMapStyle = AppMessage('unsupportedMapStyle');
  static const localPmtilesRequired = AppMessage('localPmtilesRequired');
  static const voiceGuidanceNotSaved = AppMessage('voiceGuidanceNotSaved');
  static const nonLocalGraphics = AppMessage('nonLocalGraphics');
  static const externalMapResource = AppMessage('externalMapResource');
  static const unsupportedGlyphTemplate = AppMessage(
    'unsupportedGlyphTemplate',
  );
  static const missingFonts = AppMessage('missingFonts');
  static const incompleteGlyphs = AppMessage('incompleteGlyphs');
  static const undeclaredResource = AppMessage('undeclaredResource');
  static const enableLocation = AppMessage('enableLocation');
  static const locationPermissionRequired = AppMessage(
    'locationPermissionRequired',
  );
  static const incompleteElevations = AppMessage('incompleteElevations');
  static const sessionChanged = AppMessage('sessionChanged');
  static AppMessage serverUnavailable(Object? arg1) =>
      AppMessage('serverUnavailable', [arg1]);
  static const signInRequired = AppMessage('signInRequired');
  static const sessionExpired = AppMessage('sessionExpired');
  static const mapAddressRejected = AppMessage('mapAddressRejected');
  static const gpxTooLarge = AppMessage('gpxTooLarge');
  static const xmlEntitiesForbidden = AppMessage('xmlEntitiesForbidden');
  static const notGpx = AppMessage('notGpx');
  static const invalidGpxCoordinates = AppMessage('invalidGpxCoordinates');
  static const emptyGpx = AppMessage('emptyGpx');
  static const invalidUsername = AppMessage('invalidUsername');
  static const invalidEmail = AppMessage('invalidEmail');
  static const invalidPassword = AppMessage('invalidPassword');
  static const invalidMapArea = AppMessage('invalidMapArea');
  static const libraryOpenFailed = AppMessage('libraryOpenFailed');
  static const libraryAdoptFailed = AppMessage('libraryAdoptFailed');
  static const resetEmailSent = AppMessage('resetEmailSent');
  static const passwordSaved = AppMessage('passwordSaved');
}

/// Preserve the failure category while exposing a translatable payload.
class MessageFailure extends StateError {
  MessageFailure(this.detail) : super(detail.code);
  final AppMessage detail;
}

class MessageFormatException extends FormatException {
  MessageFormatException(this.detail) : super(detail.code);
  final AppMessage detail;
}

class RemoteFailure implements Exception {
  RemoteFailure(this.status, this.message);
  final int status;
  final Object message;
  @override
  String toString() => message.toString();
}
