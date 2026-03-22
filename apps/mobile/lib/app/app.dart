import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data/task_storage.dart';
import 'screens/macos_home_page.dart';

void runAiTodoApp() {
  runApp(const AiTodoApp());
}

class AiTodoApp extends StatelessWidget {
  const AiTodoApp({super.key, this.taskStorage = const TaskStorage()});

  final TaskStorage taskStorage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      home: MacosHomePage(taskStorage: taskStorage),
    );
  }
}
