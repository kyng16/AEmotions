import 'package:flutter/material.dart';
import 'pages/chat_page.dart';

void main() {
  runApp(const MyApp());
}

/// Minimal, clean Flutter app without the demo counter.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
  title: 'AppEmotions',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const ChatPage(),
    );
  }
}

// HomePage replaced by ChatPage
