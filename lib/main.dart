import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smater_app_ai/screens/Chatbot_page.dart';
import 'package:smater_app_ai/screens/MeteoPage.dart';
import 'package:smater_app_ai/screens/callVideo_page.dart';
import 'package:smater_app_ai/screens/fruitClasifier_page.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/MeteoPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Bousmah_App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Afficher un écran de chargement pendant la vérification
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Si l'utilisateur est connecté, aller à HomePage
          if (snapshot.hasData) {
            return const HomePage();
          }

          // Sinon, afficher LoginPage
          return const LoginPage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/fruitClasifier': (context) => const FruitClassifier(),
        '/chatbot': (context) => const ChatbotPage(),
        '/callVideo': (context) => const VideoCallScreen(),
        '/meteo': (context) => const MeteoPage(),
      },
    );
  }
}
