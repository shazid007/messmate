import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
// import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('messmate_box');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    // await NotificationService.init();
  } catch (e) {
    debugPrint('Notification disabled: $e'); // Notification system removed
  }

  await AppThemeController.loadSavedTheme();

  runApp(const MessMateApp());
}

class MessMateApp extends StatelessWidget {
  const MessMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppThemeController.notifier,
      builder: (context, preset, _) {
        return MaterialApp(
          title: 'MessMate',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(preset),
          home: const AuthGate(),
        );
      },
    );
  }
}