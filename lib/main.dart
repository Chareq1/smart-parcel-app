import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:smart_parcel_box_app/screens/dashboard_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:smart_parcel_box_app/theme/theme_provider.dart';
import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const SmartParcelBoxApp(),
    )
  );
}

class SmartParcelBoxApp extends StatelessWidget {
  const SmartParcelBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    MediaKit.ensureInitialized();

    return MaterialApp(
      title: 'Smart Parcel Box App',
      theme: Provider.of<ThemeProvider>(context).currentThemeData,
      home: const DashboardPage(),
    );
  }
}
