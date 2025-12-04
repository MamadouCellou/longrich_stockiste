import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const int _downloadNotificationId = 0;

  /// 🔹 Initialisation
  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  /// 🔹 Notification de progression du téléchargement
  static Future<void> showDownloadProgress(int progress) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Téléchargements',
      channelDescription: 'Progression des téléchargements',
      importance: Importance.high,
      priority: Priority.high,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
    );

    await _plugin.show(
      _downloadNotificationId,
      'Téléchargement en cours...',
      '$progress%',
      NotificationDetails(android: androidDetails),
    );
  }

  /// 🔹 Notification de succès du téléchargement
  static Future<void> showDownloadSuccess(String message) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Téléchargements',
      channelDescription: 'Résultat des téléchargements',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      _downloadNotificationId,
      'Téléchargement terminé ✅',
      message,
      NotificationDetails(android: androidDetails),
    );
  }

  /// 🔹 Notification d’erreur
  static Future<void> showError(String message) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Téléchargements',
      channelDescription: 'Erreurs pendant le téléchargement',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      999, // ID différent pour éviter conflit
      'Erreur ❌',
      message,
      NotificationDetails(android: androidDetails),
    );
  }
}
