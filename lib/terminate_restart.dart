library terminate_restart;

export 'terminate_restart_platform_interface.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'terminate_restart_platform_interface.dart';

/// Options for restarting the app
class TerminateRestartOptions {
  /// Whether to terminate the app or just restart the UI
  final bool terminate;

  /// Whether to clear app data
  final bool clearData;

  /// Whether to preserve keychain data
  final bool preserveKeychain;

  /// Whether to preserve user defaults
  final bool preserveUserDefaults;

  /// Constructor
  const TerminateRestartOptions({
    this.terminate = true,
    this.clearData = false,
    this.preserveKeychain = false,
    this.preserveUserDefaults = false,
  });
}

/// Enum to specify the restart mode
enum RestartMode {
  /// Restart immediately without showing a dialog
  immediate,

  /// Show a confirmation dialog before restarting
  withConfirmation,
}

/// The main plugin class for restarting Flutter apps
class TerminateRestart {
  static TerminateRestart? _instance;

  /// Get the singleton instance
  static TerminateRestart get instance {
    _instance ??= TerminateRestart._();
    return _instance!;
  }

  /// Private constructor
  TerminateRestart._();

  final MethodChannel _internalChannel =
      const MethodChannel('com.ahmedsleem.terminate_restart/internal');

  bool _initialized = false;
  VoidCallback? _onRootReset;

  /// Notifier used by [wrapWithRestart] to trigger a full widget tree rebuild.
  static final ValueNotifier<int> _restartNotifier = ValueNotifier<int>(0);

  /// Wraps your app to enable UI-only restart (terminate: false).
  ///
  /// When a UI-only restart is triggered, the entire widget tree is rebuilt
  /// from scratch (splash screen, initial state, etc.).
  ///
  /// Usage:
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   TerminateRestart.instance.initialize();
  ///   runApp(TerminateRestart.wrapWithRestart(child: MyApp()));
  /// }
  /// ```
  static Widget wrapWithRestart({required Widget child}) {
    return _RestartWrapper(child: child);
  }

  /// Initialize the plugin and set up internal handlers
  void initialize({VoidCallback? onRootReset}) {
    if (!_initialized) {
      _onRootReset = onRootReset;
      // Only set up method channel handler on non-web platforms
      if (!kIsWeb) {
        _internalChannel.setMethodCallHandler(_handleInternalMessages);
      }
      _initialized = true;
    }
  }

  Future<dynamic> _handleInternalMessages(MethodCall call) async {
    switch (call.method) {
      case 'resetToRoot':
        if (_onRootReset != null) {
          _onRootReset!();
        } else {
          // Default: trigger full widget tree rebuild via wrapWithRestart
          _restartNotifier.value++;
        }
        break;
    }
  }

  /// Restarts the app with the given options.
  ///
  /// Uses the platform interface to delegate to the correct
  /// platform implementation (Android, iOS, or Web).
  Future<bool> restartApp({
    required TerminateRestartOptions options,
  }) async {
    try {
      return await TerminateRestartPlatform.instance.restartApp(
        terminate: options.terminate,
        clearData: options.clearData,
        preserveKeychain: options.preserveKeychain,
        preserveUserDefaults: options.preserveUserDefaults,
      );
    } catch (e) {
      debugPrint('Error restarting app: $e');
      return false;
    }
  }

  /// Shows a confirmation dialog before restarting
  Future<bool> restartAppWithConfirmation(
    BuildContext context, {
    String title = 'Restart Required',
    String message = 'The app needs to restart to apply changes.',
    String confirmText = 'Restart Now',
    String cancelText = 'Later',
    bool clearData = false,
    bool preserveKeychain = false,
    bool preserveUserDefaults = false,
    bool terminate = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      return restartApp(
        options: TerminateRestartOptions(
          clearData: clearData,
          preserveKeychain: preserveKeychain,
          preserveUserDefaults: preserveUserDefaults,
          terminate: terminate,
        ),
      );
    }

    return false;
  }
}

/// Internal widget that listens to restart notifications and rebuilds
/// the entire child widget tree by changing its key.
class _RestartWrapper extends StatelessWidget {
  final Widget child;
  const _RestartWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TerminateRestart._restartNotifier,
      builder: (_, value, __) => KeyedSubtree(
        key: ValueKey('terminate_restart_$value'),
        child: child,
      ),
    );
  }
}
