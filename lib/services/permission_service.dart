import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;

class PermissionService {
  static void _log(String message) {
    debugPrint("[PERMISSION] $message");
  }

  /// Request all required permissions for Mesh Networking
  static Future<bool> requestAllPermissions() async {
    _log("Requesting all required permissions...");

    // Basic permissions for any Android version
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    // Device discovery specific permissions
    if (Platform.isAndroid) {
      // Android 12 (API 31) and higher
      // We check the version via simple SDK check if needed, but permission_handler handles it well enough
      // by just requesting and it being granted/ignored on older versions.
      // However, to be strict with user requirements:
      
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ].request();

      // Android 13 (API 33) and higher
      await [
        Permission.nearbyWifiDevices,
        Permission.notification,
      ].request();
    }

    bool locationGranted = await Permission.location.isGranted;
    bool btScanGranted = await Permission.bluetoothScan.isGranted;
    bool btConnectGranted = await Permission.bluetoothConnect.isGranted;
    bool btAdvertiseGranted = await Permission.bluetoothAdvertise.isGranted;
    
    _log("Location granted: $locationGranted");
    _log("Bluetooth Scan granted: $btScanGranted");
    _log("Bluetooth Connect granted: $btConnectGranted");
    _log("Bluetooth Advertise granted: $btAdvertiseGranted");

    // Check if location services are enabled (required for discovery)
    bool locationServiceEnabled = await isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      _log("Location services are DISABLED");
    }

    // Returns true if core networking permissions are granted
    // On older Android, some might return 'granted' automatically if in manifest.
    return locationGranted && (btScanGranted || !Platform.isAndroid);
  }

  static Future<bool> checkBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    return await Permission.bluetoothScan.isGranted && 
           await Permission.bluetoothConnect.isGranted &&
           await Permission.bluetoothAdvertise.isGranted;
  }

  static Future<bool> checkLocationPermissions() async {
    return await Permission.location.isGranted;
  }

  static Future<bool> checkCameraPermissions() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    _log("Camera granted: ${status.isGranted}");
    return status.isGranted;
  }

  static Future<bool> checkSmsPermissions() async {
    return await Permission.sms.isGranted;
  }

  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    _log("SMS granted: ${status.isGranted}");
    return status.isGranted;
  }

  static Future<bool> isLocationServiceEnabled() async {
    loc.Location location = loc.Location();
    return await location.serviceEnabled();
  }

  static Future<bool> requestLocationService() async {
    loc.Location location = loc.Location();
    bool enabled = await location.serviceEnabled();
    if (!enabled) {
      enabled = await location.requestService();
    }
    return enabled;
  }
}
