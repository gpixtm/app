// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get routingAttribution => 'Valhalla · © OpenStreetMap';

  @override
  String get noJoinSegment =>
      'Ce parcours ne contient aucun segment à rejoindre.';

  @override
  String get alreadyNearTrail =>
      'Vous êtes déjà sur le parcours : le suivi démarre ici.';

  @override
  String get cachedApproach =>
      'Trajet conservé utilisé · recalcul indisponible hors ligne';

  @override
  String get gpsUnavailable =>
      'Position GPS précise introuvable. Réessayez dehors.';

  @override
  String get noWatchData =>
      'Aucune mesure partagée pour cette période. Synchronisez la montre dans Zepp, puis réessayez.';

  @override
  String get watchDataAdded => 'Mesures Health Connect ajoutées à cette sortie';

  @override
  String get walkSavedPending =>
      'Sortie enregistrée ici · synchronisation en attente';

  @override
  String get changesSavedPending =>
      'Modifications enregistrées ici · synchronisation en attente';

  @override
  String get localMaps => 'Cartes locales';

  @override
  String get mapsStorageUnavailable =>
      'Cartes non préparées : vérifiez le stockage disponible.';

  @override
  String get demoNotice =>
      'Démonstration : parcours et altitudes fictifs, carte réelle de Florence.';

  @override
  String get syncPending => 'Synchronisation en attente';

  @override
  String itemsSaved(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 éléments enregistrés sur ce téléphone',
      one: 'Un élément enregistré sur ce téléphone',
      zero: 'Aucun élément enregistré sur ce téléphone',
    );
    return '$_temp0';
  }

  @override
  String get mapSaved => 'Carte vérifiée et enregistrée hors ligne';

  @override
  String get syncRetry =>
      'Enregistré sur ce téléphone · synchronisation à reprendre';

  @override
  String get sessionRestoreFailed =>
      'La session enregistrée ne peut pas être ouverte. Reconnectez-vous.';

  @override
  String get localDev => 'Dev local (Docker)';

  @override
  String missingApiUrl(Object arg1, Object arg2) {
    return '$arg1 : renseignez API_URL dans $arg2, puis relancez F5. Le mode hors ligne nécessite une première connexion réussie.';
  }

  @override
  String invalidApiUrl(Object arg1, Object arg2) {
    return '$arg1 : URL API invalide dans $arg2 (adresse sans identifiants, requête ni fragment).';
  }

  @override
  String localhostApiUrl(Object arg1, Object arg2) {
    return '$arg1 : localhost désigne le téléphone. Utilisez l’IP LAN du PC dans $arg2.';
  }

  @override
  String prodHttpsRequired(Object arg1) {
    return 'Prod : API_URL doit commencer par https:// dans $arg1. Aucune requête ne sera envoyée.';
  }

  @override
  String get devPrivateIpRequired =>
      'Dev : HTTP est réservé à une adresse IPv4 privée du LAN (10.x, 172.16–31.x ou 192.168.x). Sinon, utilisez HTTPS.';

  @override
  String mapProgress(Object arg1, Object arg2, Object arg3) {
    return 'Cartes : $arg1/$arg2 zones · $arg3 %';
  }

  @override
  String savedAreas(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 zones conservées sur ce téléphone',
      one: '1 zone conservée sur ce téléphone',
      zero: '0 zones conservées sur ce téléphone',
    );
    return '$_temp0';
  }

  @override
  String get mapPreparationPending =>
      'Préparation en attente · connexion ou stockage indisponible. Les cartes déjà reçues restent accessibles.';

  @override
  String get freeWalk => 'Marche libre';

  @override
  String recordingSuspended(Object arg1) {
    return 'Enregistrement suspendu : $arg1';
  }

  @override
  String walkSaveFailed(Object arg1) {
    return 'Sauvegarde de la sortie impossible : $arg1';
  }

  @override
  String get syncRunning => 'Synchronisation en cours';

  @override
  String get librarySynced => 'Bibliothèque synchronisée';

  @override
  String syncConflicts(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other:
          '$arg1 conflits : copies locales conservées. Résolution dans les réglages.',
      one: '1 conflit : copie locale conservée. Résolution dans les réglages.',
      zero: 'Aucun conflit',
    );
    return '$_temp0';
  }

  @override
  String get waitForSync => 'Attendez la fin de la synchronisation.';

  @override
  String get legacyAccountDenied =>
      'Ce compte ne peut pas importer la bibliothèque historique.';

  @override
  String get libraryAlreadyOwned =>
      'Cette bibliothèque appartient déjà à un autre compte ou serveur.';

  @override
  String get approachUnavailable =>
      'Calcul à pied indisponible. Connectez-vous au serveur et à Internet, puis réessayez. Aucun trajet conservé ne passe près de votre position.';

  @override
  String get noNearbyPath =>
      'Aucun chemin accessible assez proche du point à rejoindre ou de votre position.';

  @override
  String get routeTooLong => 'Trajet trop long';

  @override
  String get invalidGeometry => 'Géométrie invalide';

  @override
  String get invalidCoordinates => 'Coordonnées invalides';

  @override
  String get emptyRoute => 'Trajet vide';

  @override
  String get invalidDirections => 'Consignes invalides';

  @override
  String get missingDirections => 'Consignes absentes';

  @override
  String towardsTrail(Object arg1) {
    return 'Vers le parcours · $arg1';
  }

  @override
  String get demo => 'Démonstration';

  @override
  String get demoFlorence => 'Démonstration · Florence';

  @override
  String get damagedGpx =>
      'Ce fichier de parcours contient un nom ou un texte dont l’encodage est abîmé. Corrigez-le dans le fichier d’origine avant de l’importer.';

  @override
  String get gpxSizeLimit => 'Limite : 50 Mo par fichier de parcours.';

  @override
  String get incompleteUtf16 => 'Fichier UTF-16 incomplet.';

  @override
  String get invalidUtf16 => 'Texte UTF-16 invalide.';

  @override
  String unsupportedGpxEncoding(Object arg1) {
    return 'Encodage du fichier non pris en charge : $arg1. Exportez le fichier en UTF-8.';
  }

  @override
  String localCopy(Object arg1) {
    return '$arg1 · copie locale';
  }

  @override
  String get libraryClosed => 'Bibliothèque fermée';

  @override
  String get downloadStalled => 'Téléchargement sans progression';

  @override
  String get invalidMapCatalog => 'Catalogue cartographique invalide.';

  @override
  String get downloadRunning => 'Téléchargement déjà en cours.';

  @override
  String get mapHttpsRequired =>
      'Paquet refusé : HTTPS requis, sauf HTTP vers le même serveur LAN en Dev.';

  @override
  String get incorrectPackageSize => 'Taille du paquet incorrecte.';

  @override
  String get packageIntegrityFailed =>
      'Paquet incomplet ou contrôle d’intégrité incorrect.';

  @override
  String get forbiddenPackagePath => 'Chemin de paquet interdit.';

  @override
  String get unpackedPackageTooLarge => 'Paquet décompressé trop volumineux.';

  @override
  String get waitForDownload => 'Attendez la fin du téléchargement.';

  @override
  String get missingMapArchive => 'Style ou archive cartographique manquants.';

  @override
  String get invalidPath => 'Chemin invalide.';

  @override
  String get damagedResource => 'Ressource absente ou corrompue.';

  @override
  String get invalidPmtiles => 'Archive PMTiles v3 invalide.';

  @override
  String get truncatedPmtiles => 'Archive PMTiles tronquée.';

  @override
  String get unsupportedMapStyle => 'Version de style non prise en charge.';

  @override
  String get localPmtilesRequired =>
      'Le fond de carte doit utiliser exclusivement des archives PMTiles locales.';

  @override
  String get nonLocalGraphics => 'Ressources graphiques non locales.';

  @override
  String get externalMapResource =>
      'Une ressource cartographique dépend du réseau ou d’un fichier externe.';

  @override
  String get unsupportedGlyphTemplate =>
      'Modèle de glyphes non pris en charge.';

  @override
  String get missingFonts => 'Polices locales absentes.';

  @override
  String get incompleteGlyphs => 'Jeu de glyphes incomplet.';

  @override
  String get undeclaredResource => 'Ressource locale non déclarée.';

  @override
  String get enableLocation => 'Activez la localisation du téléphone.';

  @override
  String get locationPermissionRequired =>
      'La localisation est nécessaire au suivi. Autorisez-la dans les réglages Android.';

  @override
  String get recordingNotificationTitle => 'Gpix · marche en cours';

  @override
  String get recordingNotificationBody =>
      'Votre trajet est enregistré. Ouvrez Gpix pour suspendre ou terminer.';

  @override
  String get recordingChannel => 'Enregistrement des marches';

  @override
  String get incompleteElevations => 'Réponse altitude incomplète.';

  @override
  String get sessionChanged => 'La session a changé.';

  @override
  String serverUnavailable(Object arg1) {
    return 'Serveur indisponible (HTTP $arg1).';
  }

  @override
  String get signInRequired => 'Connectez-vous pour continuer.';

  @override
  String get sessionExpired => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get mapAddressRejected => 'Adresse de carte refusée.';

  @override
  String get gpxTooLarge =>
      'Fichier de parcours trop volumineux (50 Mo maximum).';

  @override
  String get xmlEntitiesForbidden => 'Entités XML interdites.';

  @override
  String get notGpx => 'Ce fichier n’est pas un fichier de parcours (.gpx).';

  @override
  String get invalidGpxCoordinates => 'Coordonnées du parcours invalides.';

  @override
  String get emptyGpx => 'Aucun parcours ni point d’intérêt dans ce fichier.';

  @override
  String get invalidUsername => '3 à 32 lettres, chiffres ou caractères _.';

  @override
  String get invalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get invalidPassword =>
      'Le mot de passe doit contenir de 8 à 128 caractères.';

  @override
  String get invalidMapArea => 'Zone cartographique invalide';

  @override
  String get appTitle => 'Gpix · En chemin';

  @override
  String get settings => 'Réglages';

  @override
  String get myTrails => 'Mes parcours';

  @override
  String get offline => 'Hors ligne';

  @override
  String get map => 'Carte';

  @override
  String get history => 'Historique';

  @override
  String get sync => 'Synchroniser';

  @override
  String get delete => 'Supprimer';

  @override
  String get view => 'Voir';

  @override
  String get go => 'Lancer';

  @override
  String get keep => 'Garder';

  @override
  String get importGpx => 'Importer un parcours';

  @override
  String get tryDemo => 'Essayer la démonstration · Florence';

  @override
  String itemCount(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 éléments',
      one: '1 élément',
      zero: '0 éléments',
    );
    return '$_temp0';
  }

  @override
  String get importIntro =>
      'Importez un parcours (fichier .gpx) : chemin de Compostelle, randonnée ou liste de lieux. Aucun découpage en étapes nécessaire.';

  @override
  String pointCount(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 points d’intérêt',
      one: '1 point d’intérêt',
      zero: '0 points d’intérêt',
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
  String get mapReady => 'Carte prête hors ligne';

  @override
  String get mapNeedsPreparation => 'Carte à préparer';

  @override
  String get savedPlaces => 'Lieux enregistrés sur le téléphone';

  @override
  String get days => 'Journées';

  @override
  String get deleteItemQuestion => 'Supprimer cet élément ?';

  @override
  String get deleteItemBody =>
      'Cette suppression sera aussi synchronisée avec votre serveur.';

  @override
  String get sharedMaps =>
      'Les cartes sont partagées entre vos parcours et conservées sur votre téléphone.';

  @override
  String get automaticMapsInfo =>
      'Les zones visibles se chargent automatiquement en ligne. Chaque parcours prépare ses cartes en arrière-plan. Hors ligne, seules les zones reçues restent visibles.';

  @override
  String get resumePreparation => 'Reprendre la préparation';

  @override
  String get readyOffline => 'Prêt hors ligne';

  @override
  String get preparingMaps => 'Préparation automatique en cours ou en attente';

  @override
  String get loadCatalog => 'Charger le catalogue de mon serveur';

  @override
  String prepareTrails(Object arg1) {
    return 'Préparer mes parcours · $arg1 Mo';
  }

  @override
  String get completeElevations => 'Compléter les altitudes du parcours ouvert';

  @override
  String get onMyPhone => 'Sur mon téléphone';

  @override
  String get noInstalledMaps =>
      'Aucune carte installée. Configurez votre serveur et son catalogue dans les réglages. Les parcours restent consultables.';

  @override
  String get deleteMap => 'Supprimer cette carte';

  @override
  String get availableRegions => 'Régions disponibles';

  @override
  String get coversOpenTrail => ' · couvre le parcours ouvert';

  @override
  String get download => 'Télécharger';

  @override
  String get removeMapQuestion => 'Libérer cette carte ?';

  @override
  String affectedTrails(Object arg1) {
    return 'Parcours concernés : $arg1. Leur fond de carte peut devenir indisponible hors ligne.';
  }

  @override
  String get none => 'aucun';

  @override
  String mapSizeVersion(Object arg1, Object arg2) {
    return '$arg1 Mo · $arg2';
  }

  @override
  String mapSizeCoverage(Object arg1, Object arg2) {
    return '$arg1 Mo$arg2';
  }

  @override
  String get libraryOpenFailed =>
      'Impossible d’ouvrir votre bibliothèque. Vos données sont conservées.';

  @override
  String get libraryAdoptFailed =>
      'Impossible de rattacher la bibliothèque. Les fichiers existants sont conservés.';

  @override
  String get previousLibrary => 'Votre bibliothèque précédente';

  @override
  String get previousLibraryInfo =>
      'Des parcours et cartes de votre ancienne installation sont présents sur ce téléphone. Leur serveur d’origine ne peut pas être confirmé.';

  @override
  String adoptLibraryQuestion(Object arg1) {
    return 'Voulez-vous les rattacher à $arg1 sur ce serveur ?';
  }

  @override
  String get adoptLibraryInfo =>
      'En important, ces données et les changements en attente pourront être synchronisés avec ce compte. En choisissant une bibliothèque séparée, les anciens fichiers restent conservés et ne sont ni affichés ni synchronisés.';

  @override
  String get importExistingLibrary => 'Importer ma bibliothèque existante';

  @override
  String get useSeparateLibrary => 'Utiliser une bibliothèque séparée';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get openingLibrary => 'Ouverture de votre espace…';

  @override
  String get resetEmailSent =>
      'Si cette adresse correspond à un compte, un email vous indiquera la marche à suivre. Copiez son code ci-dessous.';

  @override
  String get passwordSaved =>
      'Mot de passe enregistré. Connectez-vous avec votre nouveau mot de passe.';

  @override
  String get loginHeading => 'Le chemin commence ici.';

  @override
  String get registerHeading => 'Votre prochain départ.';

  @override
  String get forgotHeading => 'Retrouver votre compte.';

  @override
  String get resetHeading => 'Un nouveau départ.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createMyAccount => 'Créer mon compte';

  @override
  String get sendInstructions => 'Recevoir les instructions';

  @override
  String get savePassword => 'Enregistrer le mot de passe';

  @override
  String get authIntro =>
      'Vos parcours, vos cartes, votre liberté. Connectez-vous une première fois, puis partez même sans réseau.';

  @override
  String get identifier => 'Email ou nom d’utilisateur';

  @override
  String get email => 'Adresse email';

  @override
  String get username => 'Nom d’utilisateur';

  @override
  String get resetCode => 'Code ou lien reçu par email';

  @override
  String get resetCodeHint =>
      'Copiez le code complet ou le lien présent dans l’email.';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get backToLogin => 'Revenir à la connexion';

  @override
  String get haveResetCode => 'J’ai un code de réinitialisation';

  @override
  String serverLabel(Object arg1) {
    return 'Serveur · $arg1';
  }

  @override
  String get configureServer =>
      'Adresse à configurer dans le profil de lancement';

  @override
  String get myAccount => 'Mon compte';

  @override
  String get offlineSessionInfo =>
      'Votre session vous permet d’utiliser votre bibliothèque hors ligne. La révocation depuis le serveur sera vérifiée au retour du réseau.';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get passwordChanged => 'Mot de passe modifié.';

  @override
  String get changePassword => 'Modifier le mot de passe';

  @override
  String get apiConfigurationInfo =>
      'L’adresse API se règle dans le fichier local du profil de lancement, puis en relançant F5.';

  @override
  String get resolveConflicts =>
      'Résoudre les conflits : conserver les deux copies';

  @override
  String get signOutInfo =>
      'La déconnexion verrouille cet espace sur ce téléphone. Vos parcours locaux sont conservés pour votre prochaine connexion.';

  @override
  String get requiredField => 'Ce champ est obligatoire.';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get estimatedSuffix => ' · estimée';

  @override
  String get partialSuffix => ' · partielle';

  @override
  String get nearMe => 'Autour de moi';

  @override
  String get wholeTrail => 'Tout le parcours';

  @override
  String get profileUnavailable =>
      'Profil indisponible · le suivi reste utilisable';

  @override
  String get distanceAlongTrail => 'Distance le long du parcours';

  @override
  String altitudeTitle(Object arg1, Object arg2) {
    return 'Altitude$arg1$arg2';
  }

  @override
  String get finishWalkQuestion => 'Terminer cette marche ?';

  @override
  String get finishWalkInfo =>
      'Votre trajet et ses mesures seront conservés dans l’historique et synchronisés avec votre compte.';

  @override
  String get continueAction => 'Continuer';

  @override
  String get saveWalk => 'Enregistrer la sortie';

  @override
  String get viewOnMap => 'Voir sur la carte';

  @override
  String get importWatchData => 'Compléter avec ma montre';

  @override
  String get watchSettings => 'Réglages de la montre';

  @override
  String get deleteWalkQuestion => 'Supprimer cette sortie ?';

  @override
  String get deleteWalkInfo =>
      'La suppression sera synchronisée avec votre compte.';

  @override
  String get deleteWalk => 'Supprimer la sortie';

  @override
  String get walkHistoryInfo =>
      'Les chemins que vous avez réellement parcourus.';

  @override
  String get recordingActive => '● Enregistrement en cours';

  @override
  String get walkPaused => 'Sortie en pause · prête à reprendre';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get finish => 'Terminer';

  @override
  String get liveStats => 'Mes données en direct';

  @override
  String get startRoute => 'Démarrer un parcours';

  @override
  String walkCountDistance(int arg1, Object arg2) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: '$arg1 sorties',
      one: '1 sortie',
      zero: '0 sorties',
    );
    return '$_temp0 · $arg2';
  }

  @override
  String get viewAllWalkedPlaces => 'Voir tous mes lieux parcourus';

  @override
  String get allWalks => 'Toutes';

  @override
  String get withGpx => 'Sur un parcours';

  @override
  String get freeWalks => 'Libres';

  @override
  String get noWalks =>
      'Aucune sortie ici pour le moment. Lancez un parcours ou enregistrez une marche libre.';

  @override
  String get unreadableFilename => 'Nom de fichier illisible';

  @override
  String get unreadableFilenameInfo =>
      'Le téléphone a fourni un nom abîmé. Saisissez le nom du parcours pour conserver les bons caractères.';

  @override
  String get trailName => 'Nom du parcours';

  @override
  String get enterName => 'Saisissez un nom.';

  @override
  String get replaceDamagedText => 'Remplacez les caractères abîmés.';

  @override
  String get cancel => 'Annuler';

  @override
  String get importAction => 'Importer';

  @override
  String get cannotOpenNavigation =>
      'Impossible d’ouvrir l’application ou le navigateur.';

  @override
  String get reverseSuffix => ' · sens inverse';

  @override
  String get routingPrivacy =>
      'Votre position et le point le plus proche sont utilisés par le service d’itinéraires. Dans Gpix, le trajet calculé est conservé pour continuer sans réseau.';

  @override
  String get myMap => 'Ma carte';

  @override
  String get trailMapAvailable => 'Carte du parcours disponible hors ligne';

  @override
  String get visibleMapsInfo =>
      'Les zones visibles se chargent automatiquement en ligne.';

  @override
  String get offlineMapsInfo =>
      'Hors ligne, seules les zones déjà reçues sont visibles.';

  @override
  String activeTrail(Object arg1) {
    return 'Suivi actif : $arg1';
  }

  @override
  String get compassInfo =>
      'La flèche montre le haut du téléphone. Le bouton boussole alterne nord en haut et cap devant.';

  @override
  String get discardChangesQuestion => 'Quitter cette modification ?';

  @override
  String get discardChangesInfo =>
      'La portion en cours n’est pas enregistrée. Les journées déjà enregistrées sont conservées.';

  @override
  String get leave => 'Quitter';

  @override
  String deleteDayQuestion(Object arg1) {
    return 'Supprimer la journée $arg1 ?';
  }

  @override
  String get deleteDayInfo =>
      'Le parcours et les autres portions sont conservés.';

  @override
  String get walkInProgressData => 'Marche en cours · données';

  @override
  String get walkPausedResume => 'Marche en pause · reprendre';

  @override
  String get walkedPlaces => 'Lieux parcourus';

  @override
  String get offTrailDetails => 'Écart au parcours · détails';

  @override
  String dayNumber(Object arg1) {
    return 'Journée $arg1';
  }

  @override
  String editDayNumber(Object arg1) {
    return 'Modifier la journée $arg1';
  }

  @override
  String get tapStart => 'Touchez le départ sur le parcours.';

  @override
  String get tapEnd => 'Touchez l’arrivée sur le parcours.';

  @override
  String get reviewSection => 'Portion surlignée : vérifiez puis enregistrez.';

  @override
  String startBoundary(Object arg1) {
    return 'A · Départ$arg1';
  }

  @override
  String endBoundary(Object arg1) {
    return 'B · Arrivée$arg1';
  }

  @override
  String minimumSection(Object arg1, Object arg2) {
    return '$arg1$arg2 · minimum 10 m';
  }

  @override
  String get saveDay => 'Enregistrer cette journée';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get continueFromLastEnd => 'Reprendre depuis la dernière arrivée';

  @override
  String get cancelEdit => 'Annuler la modification';

  @override
  String get myDays => 'Mes journées';

  @override
  String get noDays => 'Votre première portion apparaîtra ici.';

  @override
  String dayDistance(Object arg1, Object arg2) {
    return 'Journée $arg1 · $arg2';
  }

  @override
  String deleteDayNumber(Object arg1) {
    return 'Supprimer la journée $arg1';
  }

  @override
  String get remaining => 'restants';

  @override
  String get distanceToTrail => 'du parcours';

  @override
  String get toggleDetails => 'Ouvrir ou réduire les détails';

  @override
  String get trailReached => 'Parcours rejoint';

  @override
  String get readyToFollow => 'Prêt à suivre votre parcours.';

  @override
  String get findingAccuratePosition => 'Recherche d’une position GPS précise…';

  @override
  String routeEndGap(Object arg1) {
    return 'Fin du chemin calculé. Point de jonction à $arg1 m, repère R : vérifiez l’accès sur place.';
  }

  @override
  String get leftApproach =>
      'Vous avez quitté le trajet d’accès. Recalculez pour être guidé depuis ici.';

  @override
  String inMetres(Object arg1) {
    return 'Dans $arg1 m';
  }

  @override
  String get followFromHere => 'Suivre le parcours depuis ici';

  @override
  String get exitApproach => 'Quitter le guidage d’accès';

  @override
  String get recalculate => 'Recalculer';

  @override
  String get cachedRouteInfo =>
      'Trajet conservé · recalcul en ligne uniquement';

  @override
  String get savedWalkingApproach =>
      'Accès à pied · trajet conservé sur ce téléphone';

  @override
  String get fixMap => 'Corriger la carte';

  @override
  String get pauseTracking => 'Suspendre le suivi';

  @override
  String get resumeApproach => 'Reprendre vers le parcours';

  @override
  String get followTrail => 'Lancer le parcours';

  @override
  String returnToTracking(Object arg1) {
    return 'Revenir au suivi · $arg1';
  }

  @override
  String get findingPosition => 'Recherche de votre position…';

  @override
  String get poorGps => 'Position ancienne ou précision GPS faible';

  @override
  String gpsAccuracy(Object arg1) {
    return 'Précision GPS ± $arg1 m';
  }

  @override
  String get leavingTrail => 'Vous vous éloignez du parcours';

  @override
  String get muteAlert => 'Suspendre l’alerte';

  @override
  String get reverseDirection => 'Sens inverse · changer';

  @override
  String get gpxDirection => 'Sens d’origine · changer';

  @override
  String get currentWalk => 'Ma marche en cours';

  @override
  String get walkControls => 'Pause, terminer et historique';

  @override
  String get planDays => 'Planifier mes journées';

  @override
  String editDays(int arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      arg1,
      locale: localeName,
      other: 'Mes $arg1 journées',
      one: 'Ma journée',
      zero: 'Mes journées',
    );
    return '$_temp0 · modifier';
  }

  @override
  String get offlineAvailability => 'Disponibilité hors ligne';

  @override
  String get routeInProgress => 'Parcours en cours';

  @override
  String get mapAroundYou => 'Votre carte, autour de vous';

  @override
  String get accountServer => 'Compte et serveur';

  @override
  String get accountServerInfo => 'Identité, mot de passe et synchronisation';

  @override
  String get watchHealthData => 'Montre et données de santé';

  @override
  String get healthBridge => 'Amazfit / Zepp · Health Connect';

  @override
  String get myData => 'Mes données';

  @override
  String get syncDataInfo =>
      'Les parcours, journées et sorties sont enregistrés sur ce téléphone, puis synchronisés avec votre API. Une nouvelle connexion au même compte permet de les retrouver sur un autre téléphone. Les fonds de carte doivent y être téléchargés à nouveau.';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get watchHealth => 'Montre et santé';

  @override
  String get yourWatchMeasurements => 'Votre montre, vos mesures';

  @override
  String get compatibleWatches =>
      'Amazfit Active Max et autres montres compatibles : les mesures passent par Zepp et Health Connect. D’autres marques peuvent utiliser la même passerelle.';

  @override
  String get checkingHealthConnect => 'Vérification de Health Connect…';

  @override
  String get healthAuthorized =>
      'Accès Health Connect autorisé · disponibilité des mesures à vérifier dans une sortie';

  @override
  String get healthPermissionsMissing =>
      'Autorisations manquantes ou partielles';

  @override
  String get healthInstallRequired =>
      'Health Connect doit être installé ou mis à jour';

  @override
  String get healthUnavailable =>
      'Health Connect indisponible sur cet appareil';

  @override
  String get healthSetupSteps =>
      '1. Synchronisez votre montre dans Zepp.\n\n2. Dans les connexions de Zepp, activez le partage vers Health Connect.\n\n3. Autorisez Gpix ci-dessous. Dans une sortie, touchez « Compléter avec ma montre ».';

  @override
  String get openZepp => 'Ouvrir Zepp';

  @override
  String get installHealthConnect => 'Installer Health Connect';

  @override
  String get authorizeMeasurements => 'Autoriser les mesures';

  @override
  String get manageHealthPermissions => 'Gérer ou retirer les autorisations';

  @override
  String get supportedMeasurements => 'Mesures prises en charge';

  @override
  String get supportedMeasurementsInfo =>
      'Fréquence cardiaque moyenne et maximale, nombre de pas, calories actives, pour la période de votre marche. Les données dépendent du modèle et de ce que Zepp partage. Ce n’est pas une liaison Bluetooth en direct.';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get healthPrivacy =>
      'La lecture se fait uniquement à votre demande. Les mesures importées sont conservées dans votre sortie et synchronisées avec votre API personnelle. Retirer une autorisation empêche les prochaines lectures ; pour effacer les mesures déjà importées, supprimez la sortie de l’historique.';

  @override
  String get healthDevicePermissions =>
      'Les autorisations sont propres à ce téléphone. Elles devront être accordées à nouveau sur un autre appareil. Les périodes anciennes peuvent être limitées par Health Connect.';

  @override
  String get chooseTrailPassage =>
      'Le parcours passe plusieurs fois ici. Quel passage choisir ?';

  @override
  String atGpxKilometre(Object arg1) {
    return 'Au km $arg1 du parcours';
  }

  @override
  String get tapSelectedTrail =>
      'Touchez le parcours sélectionné. Zoomez pour placer la limite précisément.';

  @override
  String get northUp => 'Passer au nord en haut';

  @override
  String get headingUp => 'Orienter selon le téléphone';

  @override
  String get recenter => 'Recentrer sur ma position';

  @override
  String get distanceWalked => 'Distance parcourue';

  @override
  String get activeDuration => 'Durée active';

  @override
  String get totalDuration => 'Durée totale';

  @override
  String get averageSpeed => 'Vitesse moyenne';

  @override
  String get averagePace => 'Allure moyenne';

  @override
  String get maxGpsSpeed => 'Vitesse max. GPS';

  @override
  String get ascent => 'Dénivelé positif';

  @override
  String get descent => 'Dénivelé négatif';

  @override
  String get altitude => 'Altitude';

  @override
  String get minMaxAltitude => 'Altitude min. / max.';

  @override
  String get averageHeartRate => 'Fréquence cardiaque moy.';

  @override
  String get maxHeartRate => 'Fréquence cardiaque max.';

  @override
  String get steps => 'Pas';

  @override
  String get activeCalories => 'Calories actives';

  @override
  String get statsExplanation =>
      'Durée active : hors pauses manuelles. Allure et vitesse moyennes calculées sur cette durée. Dénivelés estimés à partir des altitudes GPS filtrées.';

  @override
  String get noImportedWatchData =>
      'Montre : aucune mesure importée. Les valeurs manquantes ne sont pas estimées.';

  @override
  String healthSources(Object arg1, Object arg2) {
    return 'Health Connect · $arg1\nSources : $arg2';
  }

  @override
  String get language => 'Langue';

  @override
  String get systemLanguage => 'Langue de l’appareil';

  @override
  String get unexpectedError =>
      'Cette action n’a pas abouti. Vérifiez votre connexion et réessayez.';

  @override
  String get networkError =>
      'Connexion indisponible. Vos données enregistrées restent sur ce téléphone.';

  @override
  String get invalidCredentials => 'Identifiant ou mot de passe incorrect.';

  @override
  String get invalidSession => 'Session invalide. Reconnectez-vous.';

  @override
  String get accountAlreadyExists => 'Identifiant ou email déjà utilisé.';

  @override
  String get rateLimited => 'Trop de tentatives. Réessayez dans 15 minutes.';

  @override
  String get resetUnavailable => 'Envoi indisponible. Réessayez plus tard.';

  @override
  String get invalidResetCode =>
      'Code invalide ou expiré. Demandez un nouveau code.';

  @override
  String get incorrectCurrentPassword => 'Mot de passe actuel incorrect.';

  @override
  String get invalidFields => 'Tous les champs doivent être du texte.';

  @override
  String get unknownOperation => 'Opération inconnue.';

  @override
  String get formTooLarge => 'Formulaire trop volumineux.';

  @override
  String get damagedText =>
      'Un texte contient un caractère perdu. Corrigez son nom ou réimportez le fichier d’origine.';

  @override
  String get invalidRouteCoordinates =>
      'Coordonnées de départ ou d’arrivée invalides.';

  @override
  String get waitBeforeRouting =>
      'Patientez deux secondes avant de recalculer.';

  @override
  String get serviceUnavailable =>
      'Service indisponible ou ressource introuvable';

  @override
  String get invalidRequest =>
      'Requête invalide. Vérifiez les données saisies.';

  @override
  String placesName(String name) {
    return '$name · lieux';
  }

  @override
  String get englishLanguage => 'English';

  @override
  String get frenchLanguage => 'Français';

  @override
  String get guidanceSlightLeft => 'Tournez légèrement à gauche';

  @override
  String get guidanceLeft => 'Tournez à gauche';

  @override
  String get guidanceSharpLeft => 'Tournez franchement à gauche';

  @override
  String get guidanceUTurn => 'Faites demi-tour';

  @override
  String get guidanceSlightRight => 'Tournez légèrement à droite';

  @override
  String get guidanceRight => 'Tournez à droite';

  @override
  String get guidanceSharpRight => 'Tournez franchement à droite';

  @override
  String guidanceSlightLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez légèrement à gauche',
      one: 'Dans 1 mètre, tournez légèrement à gauche',
    );
    return '$_temp0';
  }

  @override
  String guidanceLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez à gauche',
      one: 'Dans 1 mètre, tournez à gauche',
    );
    return '$_temp0';
  }

  @override
  String guidanceSharpLeftIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez franchement à gauche',
      one: 'Dans 1 mètre, tournez franchement à gauche',
    );
    return '$_temp0';
  }

  @override
  String guidanceUTurnIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, faites demi-tour',
      one: 'Dans 1 mètre, faites demi-tour',
    );
    return '$_temp0';
  }

  @override
  String guidanceSlightRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez légèrement à droite',
      one: 'Dans 1 mètre, tournez légèrement à droite',
    );
    return '$_temp0';
  }

  @override
  String guidanceRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez à droite',
      one: 'Dans 1 mètre, tournez à droite',
    );
    return '$_temp0';
  }

  @override
  String guidanceSharpRightIn(int metres) {
    String _temp0 = intl.Intl.pluralLogic(
      metres,
      locale: localeName,
      other: 'Dans $metres mètres, tournez franchement à droite',
      one: 'Dans 1 mètre, tournez franchement à droite',
    );
    return '$_temp0';
  }

  @override
  String get guidanceArrive => 'Vous avez atteint la fin du parcours';

  @override
  String get guidanceReachTrail => 'Vous avez rejoint le parcours';

  @override
  String get guidanceOffTrail => 'Vous avez quitté le parcours';

  @override
  String get guidanceOffTrailBody => 'Consultez la carte pour le rejoindre.';

  @override
  String get guidanceNow => 'Maintenant';

  @override
  String get nextDirection => 'Prochaine direction';

  @override
  String get voiceGuidance => 'Guidage vocal';

  @override
  String get voiceGuidanceInfo =>
      'Annonce chaque changement de direction environ 100 m avant pendant la navigation, même écran éteint. Quand Gpix est en arrière-plan, une notification indique aussi la direction.';

  @override
  String get voiceGuidanceNotSaved =>
      'Préférence de guidage vocal non enregistrée sur ce téléphone.';

  @override
  String get menu => 'Menu';

  @override
  String get backToMap => 'Retour à la carte';

  @override
  String get searchPlaces => 'Rechercher une ville, une adresse…';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get noPlaceFound => 'Aucun lieu trouvé.';

  @override
  String get placeSearchUnavailable =>
      'La recherche de lieux nécessite une connexion. Réessayez une fois en ligne.';

  @override
  String trailCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcours',
      one: '1 parcours',
    );
    return '$_temp0';
  }

  @override
  String trailsHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcours ici',
      one: '1 parcours ici',
    );
    return '$_temp0';
  }

  @override
  String showTrail(String name) {
    return 'Afficher $name';
  }

  @override
  String get closeTrail => 'Fermer le parcours';

  @override
  String get close => 'Fermer';

  @override
  String get openInGoogleMaps => 'Y aller avec Google Maps';

  @override
  String get searchTrails => 'Rechercher un parcours';

  @override
  String noTrailMatch(String query) {
    return 'Aucun parcours ne correspond à « $query ».';
  }

  @override
  String get approachFallback =>
      'Itinéraire vers le parcours indisponible hors ligne : le parcours est suivi directement et la distance qui vous en sépare reste affichée.';

  @override
  String get finishRoute => 'Terminer le parcours';

  @override
  String get finishRouteQuestion => 'Terminer ce parcours ?';

  @override
  String get finishRouteInfo =>
      'Votre marche sera conservée dans l’historique et, sauf si elle suit exactement un parcours existant, deviendra un nouveau parcours sur la carte. Tout est synchronisé avec votre compte.';

  @override
  String routeCreated(String arg1) {
    return 'Parcours « $arg1 » créé et affiché sur la carte · synchronisation en attente';
  }

  @override
  String routeAlreadyKnown(String arg1) {
    return 'Cette marche suit « $arg1 » : aucun parcours en double n’a été créé.';
  }

  @override
  String get routeTooShort =>
      'Marche conservée dans l’historique ; trop courte pour devenir un parcours.';

  @override
  String walkedRouteName(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Parcours du $dateString';
  }
}
