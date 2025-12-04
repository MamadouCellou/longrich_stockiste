import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:longrich_stockiste/pages/contenu_partages.dart';
import 'package:longrich_stockiste/pages/list_des_commandes.dart';
import 'package:longrich_stockiste/pages/login_page.dart';
import 'package:longrich_stockiste/services/notification_service.dart';
import 'package:longrich_stockiste/services/user_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'controllers/user_controller.dart';
import 'firebase_options.dart';

// ======================= HANDLER GLOBAL BACKGROUND =======================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print(
      '📬 Notification reçue en arrière-plan: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Permission.notification.request();

  await NotificationService.initialize();

  // Locales pour intl
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseMessaging.instance.requestPermission();

  // Handler background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialiser Supabase
  await Supabase.initialize(
    url: "https://daiddasdeyvgltehlupx.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhaWRkYXNkZXl2Z2x0ZWhsdXB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5Nzg5MjQsImV4cCI6MjA3MzU1NDkyNH0.EOjmxpkyti4sx8XOwhUmR-Yp8f1RpnvK9BMl8Qy9cKk",
  );

  Get.put(UserController(), permanent: true);

  runApp(const MyApp());
}

// ======================= APP PRINCIPALE =======================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _channel = MethodChannel('shared_channel');

  String? _sharedText;
  List<String> _sharedImagePaths = [];
  bool _isReady = false;

  /// flag pour éviter double navigation
  bool _isShowingSharedPage = false;

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler(_handleSharedData);

    // Appel unique pour récupérer les données partagées initiales et l'utilisateur
    initializeApp();
  }

  Future<void> initializeApp() async {
    try {
      // Données partagées initiales
      final Map? data = await _channel.invokeMethod('getSharedData');

      if (data != null) {
        final text = data['text'] as String?;
        final images = (data['images'] as List<dynamic>?)?.cast<String>() ?? [];

        setState(() {
          _sharedText = text;
          _sharedImagePaths = images;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Erreur récupération shared data: $e");
    }

    // Charger utilisateur Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user != null) {
      final userId = session.user!.id;

      // 🔥 On écoute le stream Supabase UNE SEULE FOIS pour initialiser
      final stream = UserService().getUserStream(userId);
      final userData = await stream.first;

      if (userData != null) {
        final controller = Get.find<UserController>();
        controller.currentUser.value = userData;
      }
    }

    setState(() {
      _isReady = true;
    });

    FlutterNativeSplash.remove();
  }

  Future<void> _handleSharedData(MethodCall call) async {
    if (call.method != "onShared") return;

    final args = call.arguments as Map<dynamic, dynamic>;
    final String? text = args['text'] as String?;
    final List<dynamic>? imagesDynamic = args['images'] as List<dynamic>?;
    final images = imagesDynamic?.cast<String>() ?? [];

    if (_isShowingSharedPage) {
      setState(() {
        _sharedText = text;
        _sharedImagePaths = images;
      });
      return;
    }

    if (mounted) {
      _isShowingSharedPage = true;

      setState(() {
        _sharedText = text;
        _sharedImagePaths = images;
      });

      FlutterNativeSplash.remove();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SharedContentPage(
            sharedText: _sharedText,
            sharedPaths: _sharedImagePaths,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isShowingSharedPage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const SizedBox.shrink();

    final hasInitialShared = (_sharedText != null && _sharedText!.isNotEmpty) ||
        _sharedImagePaths.isNotEmpty;

    return GetMaterialApp(
      title: 'Gestion de Stock Longrich',
      theme: ThemeData(primarySwatch: Colors.green),
      debugShowCheckedModeBanner: false,
      home: hasInitialShared
          ? SharedContentPage(
              sharedText: _sharedText,
              sharedPaths: _sharedImagePaths,
            )
          : (Supabase.instance.client.auth.currentSession?.user != null &&
                  Get.find<UserController>().currentUser.value != null)
              ? PurchasesListPage()
              : const LoginPage(),
    );
  }
}
