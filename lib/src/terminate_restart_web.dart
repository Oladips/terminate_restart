import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../terminate_restart_platform_interface.dart';

/// A web implementation of the TerminateRestartPlatform.
///
/// This class implements app restart functionality for web browsers.
/// Note: Web browsers cannot truly "terminate" an app, so terminate mode
/// will perform a full page reload instead.
class TerminateRestartWeb extends TerminateRestartPlatform {
  /// Constructs a TerminateRestartWeb.
  TerminateRestartWeb();

  /// Factory constructor for plugin registration.
  static void registerWith(Registrar registrar) {
    TerminateRestartPlatform.instance = TerminateRestartWeb();
  }

  @override
  Future<bool> restartApp({
    bool clearData = false,
    bool preserveKeychain = false,
    bool preserveUserDefaults = false,
    bool terminate = true,
  }) async {
    try {
      // Clear data if requested
      if (clearData) {
        await _clearBrowserData(
          preserveKeychain: preserveKeychain,
          preserveUserDefaults: preserveUserDefaults,
        );
      }

      // Use a microtask to allow the Future to return before the page reloads
      scheduleMicrotask(() {
        // On web, both modes use location.reload() since the browser
        // cannot distinguish between UI-only and full restart.
        // location.replace(sameUrl) does NOT trigger a reload in most browsers,
        // which is why we always use reload().
        web.window.location.reload();
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> gc() async {
    // Garbage collection is handled by the browser's JavaScript engine
    // We can't force GC in browsers, but we can clear some references
    // This is a no-op for web but maintains API compatibility
  }

  /// Clears browser storage data based on preservation options.
  Future<void> _clearBrowserData({
    required bool preserveKeychain,
    required bool preserveUserDefaults,
  }) async {
    try {
      // Clear localStorage (equivalent to UserDefaults on web)
      if (!preserveUserDefaults) {
        web.window.localStorage.clear();
      }

      // Clear sessionStorage
      if (!preserveKeychain) {
        web.window.sessionStorage.clear();
      }

      // Clear cookies if not preserving keychain
      // Keychain on web is conceptually similar to secure cookies
      if (!preserveKeychain) {
        _clearCookies();
      }

      // Clear IndexedDB databases
      if (!preserveUserDefaults && !preserveKeychain) {
        await _clearIndexedDB();
      }

      // Clear cache storage if available
      await _clearCacheStorage();
    } catch (e) {
      // Silently handle errors - some browsers may restrict these operations
    }
  }

  /// Clears all cookies for the current domain.
  void _clearCookies() {
    try {
      final cookies = web.document.cookie;
      final cookieList = cookies.split(';');

      for (final cookie in cookieList) {
        final cookieName = cookie.split('=').first.trim();
        if (cookieName.isNotEmpty) {
          // Set cookie to expire in the past to delete it
          web.document.cookie =
              '$cookieName=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        }
      }
    } catch (e) {
      // Silently handle cookie clearing errors
    }
  }

  /// Clears IndexedDB databases.
  Future<void> _clearIndexedDB() async {
    try {
      // Get the indexedDB factory
      final indexedDB = web.window.indexedDB;

      // Try to get database names and delete them
      // Note: databases() method might not be available in all browsers
      try {
        final databases = await indexedDB.databases().toDart;
        for (final db in databases.toDart) {
          final name = db.name;
          if (name.isNotEmpty) {
            indexedDB.deleteDatabase(name);
          }
        }
      } catch (e) {
        // databases() not supported, try alternative approach
        // Delete known Flutter/Dart IndexedDB databases
        _deleteKnownDatabases(indexedDB);
      }
    } catch (e) {
      // IndexedDB might not be available
    }
  }

  /// Deletes known Flutter/Dart related IndexedDB databases.
  void _deleteKnownDatabases(web.IDBFactory indexedDB) {
    // Common Flutter/Dart database names
    const knownDatabases = [
      'sembast',
      'hive',
      'moor',
      'drift',
      'isar',
      'objectbox',
      'sqflite',
    ];

    for (final dbName in knownDatabases) {
      try {
        indexedDB.deleteDatabase(dbName);
      } catch (e) {
        // Ignore errors for non-existent databases
      }
    }
  }

  /// Clears the Cache Storage API.
  Future<void> _clearCacheStorage() async {
    try {
      final caches = web.window.caches;
      final keys = await caches.keys().toDart;

      for (final key in keys.toDart) {
        final keyString = key.toDart;
        await caches.delete(keyString).toDart;
      }
    } catch (e) {
      // Cache Storage might not be available or accessible
    }
  }
}
