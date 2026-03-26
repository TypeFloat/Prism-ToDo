import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data/task_storage.dart';
import 'features/settings/data/settings_storage.dart';
import 'features/settings/domain/ai_settings.dart';
import 'features/workbench/presentation/workbench_page.dart';

void runAiTodoApp() {
  runApp(const AiTodoApp());
}

class AiTodoApp extends StatefulWidget {
  const AiTodoApp({
    super.key,
    this.taskStorage = const TaskStorage(),
    this.settingsStorage = const SettingsStorage(),
  });

  final TaskStorage taskStorage;
  final SettingsStorage settingsStorage;

  @override
  State<AiTodoApp> createState() => _AiTodoAppState();
}

class _AiTodoAppState extends State<AiTodoApp> {
  AISettings _settings = const AISettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await widget.settingsStorage.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
    });
  }

  ThemeMode _themeModeFromSettings() {
    switch (_settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: _themeModeFromSettings(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121420),
      ),
      home: WorkbenchPage(
        taskStorage: widget.taskStorage,
        settingsStorage: widget.settingsStorage,
        onSettingsChanged: (next) {
          setState(() {
            _settings = next;
          });
        },
      ),
    );
  }
}
