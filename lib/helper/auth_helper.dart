import 'package:local_auth/local_auth.dart';

class AuthHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticateUser() async {
    try {
      // Vérifie les capacités de l’appareil
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      print("📱 canCheckBiometrics: $canCheck, isDeviceSupported: $isSupported");

      // Si rien n’est dispo, on retourne false
      if (!canCheck && !isSupported) {
        print("❌ Aucun moyen d'authentification disponible !");
        return false;
      }

      // Vérifie quelles méthodes sont disponibles
      final available = await _auth.getAvailableBiometrics();
      print("🧩 Méthodes disponibles: $available");

      // Lance l’authentification
      final didAuthenticate = await _auth.authenticate(
        localizedReason:
        'Veuillez confirmer votre identité pour exécuter cette action sécurisée',
        options: const AuthenticationOptions(
          biometricOnly: false, // 👈 autorise le code PIN si pas de biométrie
          stickyAuth: true,     // garde l’état même si l’app passe en background
          useErrorDialogs: true,
        ),
      );

      print("✅ didAuthenticate: $didAuthenticate");
      return didAuthenticate;
    } catch (e) {
      print("⚠️ Erreur d'authentification: $e");
      return false;
    }
  }
}
