import 'dart:io';

import 'package:dropweb/common/print.dart';
import 'package:win32_registry/win32_registry.dart';

class Protocol {
  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  Protocol._internal();
  static Protocol? _instance;

  /// Registers a Windows URL protocol handler at
  /// `HKCU\Software\Classes\<scheme>\shell\open\command` pointing to this exe.
  ///
  /// When [onlyIfMissing] is true, the call is a no-op if another application
  /// has already claimed the scheme. This is critical for schemes shared
  /// across forks (e.g. `flclash://`) — we must not hijack a handler that
  /// another client legitimately owns. Detection is by reading the existing
  /// command string and checking it doesn't already point to our own exe.
  void register(String scheme, {bool onlyIfMissing = false}) {
    final protocolRegKey = 'Software\\Classes\\$scheme';

    if (onlyIfMissing && _isAlreadyClaimedByOther(protocolRegKey)) {
      commonPrint.log(
        'Protocol.register: skipping "$scheme://" — already claimed by another app',
      );
      return;
    }

    const protocolRegValue = RegistryValue.string('URL Protocol', '');
    const protocolCmdRegKey = r'shell\open\command';
    final protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }

  /// Returns true if the scheme's `shell\open\command` key exists and points
  /// to an executable that is NOT our own [Platform.resolvedExecutable].
  /// Returns false if the key is missing, unreadable, or already points to us
  /// (in which case overwriting is a no-op anyway).
  bool _isAlreadyClaimedByOther(String protocolRegKey) {
    try {
      // win32_registry 2.1.0 API: Registry.openPath is a static method on
      // Registry (NOT an instance method on RegistryKey). Default access
      // rights are readOnly, so no named arg is needed.
      final cmdKey = Registry.openPath(
        RegistryHive.currentUser,
        path: '$protocolRegKey\\shell\\open\\command',
      );
      final existingCmd = cmdKey.getStringValue('');
      cmdKey.close();
      if (existingCmd == null || existingCmd.isEmpty) return false;
      final ourExe = Platform.resolvedExecutable.toLowerCase();
      return !existingCmd.toLowerCase().contains(ourExe);
    } catch (_) {
      // Key doesn't exist or can't be read — treat as unclaimed.
      return false;
    }
  }

  /// Deletes our own handler for the given scheme, if and only if it currently
  /// points to this exe. Used during app-level cleanup and uninstall paths to
  /// avoid leaving a broken registry entry that points to a deleted binary.
  void unregisterIfOurs(String scheme) {
    final protocolRegKey = 'Software\\Classes\\$scheme';
    try {
      // See note in _isAlreadyClaimedByOther about the win32_registry API.
      final cmdKey = Registry.openPath(
        RegistryHive.currentUser,
        path: '$protocolRegKey\\shell\\open\\command',
      );
      final existingCmd = cmdKey.getStringValue('');
      cmdKey.close();
      if (existingCmd == null) return;
      final ourExe = Platform.resolvedExecutable.toLowerCase();
      if (existingCmd.toLowerCase().contains(ourExe)) {
        Registry.currentUser.deleteKey(protocolRegKey, recursive: true);
        commonPrint.log('Protocol.unregisterIfOurs: removed "$scheme://"');
      }
    } catch (_) {
      // Nothing to delete.
    }
  }
}

final protocol = Protocol();
