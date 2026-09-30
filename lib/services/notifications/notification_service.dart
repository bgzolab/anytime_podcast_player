abstract class NotificationService {
  /// Whether local notifications are supported on the current platform.
  ///
  /// Used by settings to hide the notification option where the platform
  /// implementation is unavailable (e.g. Windows).
  bool get supported;

  Future<bool> requestPermissionsIfNotGranted();

  Future<bool> isAllowed();

  Future<bool> createRefreshNotification();

  Future<void> clearRefreshNotification();
}
