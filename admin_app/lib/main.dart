import 'package:flutter/material.dart';

import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'session.dart';

/// Social Stories Admin: review what subscribers send (new stories, story
/// changes, quiz questions) and manage subscriptions.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AdminApp(session: Session()..load()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stories Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB), brightness: Brightness.dark, useMaterial3: true),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (!session.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final api = session.api;
          return api == null
              ? ConnectScreen(session: session)
              : HomeScreen(key: ValueKey(api), api: api, session: session);
        },
      ),
    );
  }
}
