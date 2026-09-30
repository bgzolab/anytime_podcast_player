import 'package:anytime/core/utils.dart';
import 'package:anytime/services/notifications/notification_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

class MobileNotificationService extends NotificationService {
  final log = Logger('MobileNotificationService');

  bool _initialised = false;

  /// Set when a platform channel turns out to be missing even though the
  /// platform check said the plugin was supported.
  bool _runtimeUnsupported = false;

  MobileNotificationService() {
    if (!_initialised) {
      _init();
      _initialised = true;
    }
  }

  /// `awesome_notifications` only implements Android and iOS; calling it on a
  /// desktop platform raises a [MissingPluginException]. The check is
  /// synchronous so callers can short-circuit before any side effects.
  @override
  bool get supported =>
      !_runtimeUnsupported &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (!supported) {
      log.fine('Notifications are not supported on this platform; skipping initialisation');

      return;
    }

    try {
      await AwesomeNotifications().initialize(
          'resource://drawable/ic_refresh',
          [
            NotificationChannel(
              channelGroupKey: 'anytime.notifications.groupkey',
              channelKey: 'anytime.notifications.key',
              channelName: 'Anytime notifications',
              channelDescription: 'Notification channel for Anytime library sync notifications',
              groupAlertBehavior: GroupAlertBehavior.Children,
              playSound: false,
              enableVibration: false,
              enableLights: false,
              defaultColor: const Color(0xFF9D50DD),
              ledColor: Colors.white,
            )
          ],
          debug: true);
    } on MissingPluginException catch (e) {
      _runtimeUnsupported = true;

      log.warning('Notifications are not available on this platform: $e');
    }
  }

  @override
  Future<bool> requestPermissionsIfNotGranted() async {
    if (!supported) return false;

    try {
      var isAllowed = await AwesomeNotifications().isNotificationAllowed();

      if (!isAllowed) {
        isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      return isAllowed;
    } on MissingPluginException catch (e) {
      _runtimeUnsupported = true;

      log.warning('Failed to request notification permissions: $e');

      return false;
    }
  }

  @override
  Future<bool> isAllowed() async {
    if (!supported) return false;

    try {
      return await AwesomeNotifications().isNotificationAllowed();
    } on MissingPluginException catch (e) {
      _runtimeUnsupported = true;

      log.warning('Failed to query notification permissions: $e');

      return false;
    }
  }

  @override
  Future<void> clearRefreshNotification() async {
    if (!supported) return;

    try {
      AwesomeNotifications().cancel(10);
    } on MissingPluginException catch (e) {
      _runtimeUnsupported = true;

      log.warning('Failed to clear the refresh notification: $e');
    }
  }

  @override
  Future<bool> createRefreshNotification() async {
    if (!supported) return false;

    final locale = await currentLocale();
    final alertTitle = Intl.message('alert_sync_title_label', locale: locale);
    final alertBody = Intl.message('alert_sync_title_body', locale: locale);

    try {
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 10,
          channelKey: 'anytime.notifications.key',
          customSound: null,
          actionType: ActionType.SilentBackgroundAction,
          wakeUpScreen: false,
          criticalAlert: false,
          category: NotificationCategory.Service,
          title: alertTitle,
          body: alertBody,
        ),
      );
    } on MissingPluginException catch (e) {
      _runtimeUnsupported = true;

      log.warning('Failed to create the refresh notification: $e');

      return false;
    }
  }
}
