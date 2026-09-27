import '../domain/app_message.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/auth.dart';

class AccountStorage {
  const AccountStorage(this.databasePath, this.mapsDirectory);
  final String databasePath;
  final Directory mapsDirectory;
  static String _identity(String scope, AuthUser user) =>
      sha256.convert(utf8.encode('$scope:${user.id}')).toString();
  static Directory _root(Directory support, String identity) =>
      Directory('${support.path}/accounts/$identity');
  // Retain existing absolute map paths, WAL, revisions and outbox in place.
  static Future<AccountStorage> resolve(
    Directory support,
    String scope,
    AuthUser user, {
    bool trustedPreviousOrigin = false,
  }) async {
    await support.create(recursive: true);
    final identity = _identity(scope, user);
    final legacy = File('${support.path}/gpix.sqlite');
    final claim = File('${support.path}/legacy-library-owner.json');
    final root = _root(support, identity);
    if (user.legacyOwner && await legacy.exists()) {
      if (!await claim.exists()) {
        if (trustedPreviousOrigin) {
          await decideLegacyImport(support, scope, user, true);
        } else if (!await File('${root.path}/keep-legacy-separate').exists()) {
          throw const LegacyLibraryConsentRequired();
        }
      }
      if (await claim.exists()) {
        final owner = jsonDecode(await claim.readAsString());
        if (owner is Map && owner['identity'] == identity) {
          return AccountStorage(legacy.path, Directory('${support.path}/maps'));
        }
      }
    }
    await root.create(recursive: true);
    return AccountStorage(
      '${root.path}/gpix.sqlite',
      Directory('${root.path}/maps'),
    );
  }

  static Future<void> decideLegacyImport(
    Directory support,
    String scope,
    AuthUser user,
    bool adopt,
  ) async {
    if (!user.legacyOwner) {
      throw MessageFailure(AppMessage.legacyAccountDenied);
    }
    final identity = _identity(scope, user);
    await support.create(recursive: true);
    final claim = File('${support.path}/legacy-library-owner.json');
    if (adopt) {
      if (await claim.exists()) {
        final existing = jsonDecode(await claim.readAsString());
        if (existing is! Map || existing['identity'] != identity) {
          throw MessageFailure(AppMessage.libraryAlreadyOwned);
        }
        return;
      }
      await claim.writeAsString(
        jsonEncode({'identity': identity}),
        flush: true,
      );
    } else {
      final root = _root(support, identity);
      await root.create(recursive: true);
      await File('${root.path}/keep-legacy-separate')
          .writeAsString('1', flush: true);
    }
  }
}
