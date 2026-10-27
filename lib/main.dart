import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// main() is the first function that runs when the app starts.
// It is "async" because starting Firebase takes a short time.
Future<void> main() async {
  // Flutter must be ready before we call any plugin (like Firebase).
  WidgetsFlutterBinding.ensureInitialized();

  // Connect the app to our Firebase project (ada-rasa-foods).
  // The settings come from firebase_options.dart, made by FlutterFire CLI.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AdaRasaApp());
}

// The root widget of the whole app.
class AdaRasaApp extends StatelessWidget {
  const AdaRasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ada Rasa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: FirebaseCheckScreen(
        projectId: Firebase.app().options.projectId,
      ),
    );
  }
}

// A simple test screen.
// It shows the Firebase project ID, so we can see the connection works.
// We will replace this screen with the real login screen later.
class FirebaseCheckScreen extends StatelessWidget {
  const FirebaseCheckScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant, size: 72, color: Colors.deepOrange),
              const SizedBox(height: 16),
              Text(
                'Ada Rasa',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(height: 8),
              const Text('Firebase connected'),
              const SizedBox(height: 4),
              Text(
                'Project: $projectId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}