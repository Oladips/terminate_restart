import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminate_restart/terminate_restart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminateRestartOptions', () {
    test('default values', () {
      const options = TerminateRestartOptions();

      expect(options.terminate, true);
      expect(options.clearData, false);
      expect(options.preserveKeychain, false);
      expect(options.preserveUserDefaults, false);
    });

    test('custom values', () {
      const options = TerminateRestartOptions(
        terminate: false,
        clearData: true,
        preserveKeychain: true,
        preserveUserDefaults: true,
      );

      expect(options.terminate, false);
      expect(options.clearData, true);
      expect(options.preserveKeychain, true);
      expect(options.preserveUserDefaults, true);
    });
  });

  group('TerminateRestart', () {
    late List<MethodCall> log;

    setUp(() {
      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ahmedsleem.terminate_restart/restart'),
        (MethodCall methodCall) async {
          log.add(methodCall);
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ahmedsleem.terminate_restart/restart'),
        null,
      );
    });

    test('singleton instance', () {
      final instance1 = TerminateRestart.instance;
      final instance2 = TerminateRestart.instance;

      expect(identical(instance1, instance2), true);
    });

    test('restartApp calls platform with correct arguments', () async {
      final result = await TerminateRestart.instance.restartApp(
        options: const TerminateRestartOptions(
          terminate: true,
          clearData: true,
          preserveKeychain: false,
          preserveUserDefaults: true,
        ),
      );

      expect(result, true);
      expect(log.length, 1);
      expect(log[0].method, 'restart');
      expect(log[0].arguments, {
        'terminate': true,
        'clearData': true,
        'preserveKeychain': false,
        'preserveUserDefaults': true,
      });
    });

    test('restartApp with default options', () async {
      final result = await TerminateRestart.instance.restartApp(
        options: const TerminateRestartOptions(),
      );

      expect(result, true);
      expect(log.length, 1);
      expect(log[0].method, 'restart');
      expect(log[0].arguments, {
        'terminate': true,
        'clearData': false,
        'preserveKeychain': false,
        'preserveUserDefaults': false,
      });
    });

    test('restartApp handles platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ahmedsleem.terminate_restart/restart'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Test error');
        },
      );

      final result = await TerminateRestart.instance.restartApp(
        options: const TerminateRestartOptions(),
      );

      expect(result, false);
    });
  });

  group('RestartMode', () {
    test('has correct values', () {
      expect(RestartMode.values.length, 2);
      expect(RestartMode.immediate.index, 0);
      expect(RestartMode.withConfirmation.index, 1);
    });
  });
}
