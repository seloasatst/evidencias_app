import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:safe_device/safe_device.dart';

class DeviceIntegrityResult {
  final bool isSecure;
  final bool isJailBroken;
  final bool isRealDevice;
  final bool isDevModeEnabled;
  final String? failureReason;

  DeviceIntegrityResult({
    required this.isSecure,
    required this.isJailBroken,
    required this.isRealDevice,
    required this.isDevModeEnabled,
    this.failureReason,
  });
}

class SecurityService {

  static Future<DeviceIntegrityResult> checkDeviceIntegrity() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DeviceIntegrityResult(
        isSecure: true,
        isJailBroken: false,
        isRealDevice: true,
        isDevModeEnabled: false,
      );
    }

    try {
      final results = await Future.wait([
        SafeDevice.isJailBroken.timeout(const Duration(milliseconds: 2500), onTimeout: () => false),
        SafeDevice.isRealDevice.timeout(const Duration(milliseconds: 2500), onTimeout: () => true),
      ]);

      final isJailBroken = results[0];
      final isRealDevice = results[1];

      if (isJailBroken) {
        return DeviceIntegrityResult(
          isSecure: false,
          isJailBroken: true,
          isRealDevice: isRealDevice,
          isDevModeEnabled: false,
          failureReason: '¡ALERTA DE SEGURIDAD!\nDispositivo con Root o Jailbreak detectado.',
        );
      }

      if (!isRealDevice) {
        return DeviceIntegrityResult(
          isSecure: false,
          isJailBroken: isJailBroken,
          isRealDevice: false,
          isDevModeEnabled: false,
          failureReason: '¡ALERTA DE SEGURIDAD!\nSe ha detectado un emulador o máquina virtual.',
        );
      }

      return DeviceIntegrityResult(
        isSecure: true,
        isJailBroken: false,
        isRealDevice: true,
        isDevModeEnabled: false,
      );
    } catch (_) {
      return DeviceIntegrityResult(
        isSecure: true,
        isJailBroken: false,
        isRealDevice: true,
        isDevModeEnabled: false,
      );
    }
  }

  static Future<String> getDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo.timeout(const Duration(seconds: 2));
        return 'AND_${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}'.replaceAll(' ', '_');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo.timeout(const Duration(seconds: 2));
        return 'IOS_${iosInfo.model}_${iosInfo.identifierForVendor ?? "unknown"}';
      }
    } catch (_) {}
    return 'DEV_UNKNOWN_${Platform.operatingSystem}';
  }

  static Future<String> getDeviceDisplayName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo.timeout(const Duration(seconds: 2));
        return '${info.brand.toUpperCase()} ${info.model} (Android ${info.version.release})';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo.timeout(const Duration(seconds: 2));
        return '${info.name} (${info.model} iOS ${info.systemVersion})';
      }
    } catch (_) {}
    return 'Dispositivo Móvil';
  }
}
