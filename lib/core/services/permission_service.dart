import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStatusModel {
  bool cameraGranted;
  bool contactsGranted;
  bool notificationsGranted;
  bool internetActive;

  PermissionStatusModel({
    this.cameraGranted = false,
    this.contactsGranted = false,
    this.notificationsGranted = false,
    this.internetActive = true,
  });
}

class PermissionService extends ChangeNotifier {
  PermissionStatusModel _status = PermissionStatusModel();

  PermissionStatusModel get status => _status;

  Future<void> checkAllPermissions() async {
    if (kIsWeb) {
      _status = PermissionStatusModel(
        cameraGranted: true,
        contactsGranted: true,
        notificationsGranted: true,
        internetActive: true,
      );
      notifyListeners();
      return;
    }

    try {
      final cam = await Permission.camera.status;
      final cont = await Permission.contacts.status;
      final notif = await Permission.notification.status;

      _status = PermissionStatusModel(
        cameraGranted: cam.isGranted,
        contactsGranted: cont.isGranted,
        notificationsGranted: notif.isGranted,
        internetActive: true,
      );
    } catch (_) {
      // Fallback
    }
    notifyListeners();
  }

  Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    final res = await Permission.camera.request();
    _status.cameraGranted = res.isGranted;
    notifyListeners();
    return res.isGranted;
  }

  Future<bool> requestContacts() async {
    if (kIsWeb) return true;
    final res = await Permission.contacts.request();
    _status.contactsGranted = res.isGranted;
    notifyListeners();
    return res.isGranted;
  }

  Future<bool> requestNotifications() async {
    if (kIsWeb) return true;
    final res = await Permission.notification.request();
    _status.notificationsGranted = res.isGranted;
    notifyListeners();
    return res.isGranted;
  }

  Future<void> requestAllPermissions() async {
    await requestCamera();
    await requestContacts();
    await requestNotifications();
  }
}
