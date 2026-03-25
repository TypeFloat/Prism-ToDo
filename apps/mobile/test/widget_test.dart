import 'package:ai_todo_mobile/app/app.dart';
import 'package:ai_todo_mobile/app/app_strings.dart';
import 'package:ai_todo_mobile/app/data/task_seed.dart';
import 'package:ai_todo_mobile/app/data/task_storage.dart';
import 'package:ai_todo_mobile/app/features/settings/data/settings_storage.dart';
import 'package:ai_todo_mobile/app/features/settings/domain/ai_settings.dart';
import 'package:ai_todo_mobile/app/logic/task_dedup.dart';
import 'package:ai_todo_mobile/app/models/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryTaskStorage extends TaskStorage {
  InMemoryTaskStorage([List<TaskItem>? initialTasks])
      : _tasks = List<TaskItem>.from(initialTasks ?? seedTasks),
        super(baseDirectory: null);

  List<TaskItem> _tasks;

  @override
  Future<List<TaskItem>> loadTasks() async => List<TaskItem>.from(_tasks);

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    _tasks = List<TaskItem>.from(tasks);
  }
}

class InMemorySettingsStorage extends SettingsStorage {
  InMemorySettingsStorage([this._settings = const AISettings()]) : super(baseDirectory: null);

  AISettings _settings;

  @override
  Future<AISettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AISettings settings) async {
    _settings = settings;
  }
}

void main() {
  test('hasDuplicateTaskTitle ignores case and extra whitespace', () {
    expect(
      hasDuplicateTaskTitle(
        existingTitles: const [AppStrings.sampleTaskReviewToday],
        candidateTitle: '  梳理今天的优先任务  ',
      ),
      isTrue,
    );

    expect(
      hasDuplicateTaskTitle(
        existingTitles: const [AppStrings.sampleTaskReviewToday],
        candidateTitle: '补一条组件冒烟测试',
      ),
      isFalse,
    );
  });

  testWidgets('app smoke test renders workbench shell', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.appTitle), findsWidgets);
    expect(find.text(AppStrings.quickInputTitle), findsOneWidget);
    expect(find.text(AppStrings.today), findsWidgets);
    expect(find.text(AppStrings.inbox), findsWidgets);
    expect(find.text(AppStrings.completed), findsOneWidget);
    expect(find.text(AppStrings.settings), findsOneWidget);
  });

  testWidgets('completed tasks are hidden from inbox and today', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.sampleTaskDemo), findsNothing);
    await tester.tap(find.text(AppStrings.completed));
    await tester.pump();
    expect(find.text(AppStrings.sampleTaskDemo), findsOneWidget);
  });

  testWidgets('settings view can be opened', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.settings).first);
    await tester.pump();

    expect(find.text(AppStrings.settingsTitle), findsWidgets);
    expect(find.text(AppStrings.aiFeatureToggle), findsOneWidget);
  });

  testWidgets('parent task completion asks for subtask confirmation', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.sampleTaskMeetingFollowups), findsOneWidget);
    final checkbox = find.byType(Checkbox).at(0);
    await tester.tap(checkbox);
    await tester.pump();

    expect(find.text(AppStrings.completeWithSubtasksTitle), findsOneWidget);
    expect(find.text(AppStrings.confirmCompleteAll), findsOneWidget);
  });

  testWidgets('cancel parent completion keeps parent and subtasks unchanged', (tester) async {
    final storage = InMemoryTaskStorage();
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: storage,
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    final checkbox = find.byType(Checkbox).at(0);
    await tester.tap(checkbox);
    await tester.pump();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    final reloaded = await storage.loadTasks();
    final parent = reloaded.firstWhere((t) => t.id == 't2');
    final sub1 = reloaded.firstWhere((t) => t.id == 't2-1');
    final sub2 = reloaded.firstWhere((t) => t.id == 't2-2');

    expect(parent.isDone, isFalse);
    expect(sub1.isDone, isFalse);
    expect(sub2.isDone, isFalse);
  });

  testWidgets('confirm parent completion marks parent and subtasks done and persists after restart', (tester) async {
    final storage = InMemoryTaskStorage();
    final settings = InMemorySettingsStorage();

    await tester.pumpWidget(AiTodoApp(taskStorage: storage, settingsStorage: settings));
    await tester.pump();

    final checkbox = find.byType(Checkbox).at(0);
    await tester.tap(checkbox);
    await tester.pump();
    await tester.tap(find.text(AppStrings.confirmCompleteAll));
    await tester.pumpAndSettle();

    var reloaded = await storage.loadTasks();
    var parent = reloaded.firstWhere((t) => t.id == 't2');
    var sub1 = reloaded.firstWhere((t) => t.id == 't2-1');
    var sub2 = reloaded.firstWhere((t) => t.id == 't2-2');

    expect(parent.isDone, isTrue);
    expect(sub1.isDone, isTrue);
    expect(sub2.isDone, isTrue);

    // restart simulation
    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pumpWidget(AiTodoApp(taskStorage: storage, settingsStorage: settings));
    await tester.pump();

    reloaded = await storage.loadTasks();
    parent = reloaded.firstWhere((t) => t.id == 't2');
    sub1 = reloaded.firstWhere((t) => t.id == 't2-1');
    sub2 = reloaded.firstWhere((t) => t.id == 't2-2');

    expect(parent.isDone, isTrue);
    expect(sub1.isDone, isTrue);
    expect(sub2.isDone, isTrue);
  });

  testWidgets('deadline-only tasks are excluded from today standard list', (tester) async {
    final storage = InMemoryTaskStorage([
      const TaskItem(
        id: 's1',
        title: '有开始结束时间的日程',
        bucket: TaskBucket.today,
        timeType: TaskTimeType.schedule,
        startAt: '2099-03-25T10:00:00+08:00',
        endAt: '2099-03-25T11:00:00+08:00',
      ),
      const TaskItem(
        id: 'd1',
        title: '只有截止时间的任务',
        bucket: TaskBucket.today,
        timeType: TaskTimeType.deadlineOnly,
        deadline: '今天 18:00',
      ),
    ]);

    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: storage,
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.today).first);
    await tester.pump();

    expect(find.text('有开始结束时间的日程'), findsOneWidget);
    expect(find.text('只有截止时间的任务'), findsNothing);
  });

  testWidgets('theme mode follows saved settings on app start', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(const AISettings(themeMode: 'dark')),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('theme mode can be changed and persisted', (tester) async {
    final settings = InMemorySettingsStorage();

    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: settings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.settings).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.themeModeDark).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.saveSettings));
    await tester.pumpAndSettle();

    final saved = await settings.loadSettings();
    expect(saved.themeMode, 'dark');

    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: settings,
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('quick input prevents duplicate creation', (tester) async {
    await tester.pumpWidget(
      AiTodoApp(
        taskStorage: InMemoryTaskStorage(),
        settingsStorage: InMemorySettingsStorage(),
      ),
    );
    await tester.pump();

    final input = find.byType(TextField).first;
    expect(input, findsOneWidget);

    const newTaskTitle = '补一条组件冒烟测试';

    await tester.enterText(input, newTaskTitle);
    await tester.tap(find.text(AppStrings.captureToInbox));
    await tester.pump();

    expect(find.text(newTaskTitle), findsOneWidget);

    await tester.enterText(input, '  补一条组件冒烟测试 ');
    await tester.tap(find.text(AppStrings.captureToInbox));
    await tester.pump();

    expect(find.text(newTaskTitle), findsOneWidget);
    expect(find.text(AppStrings.duplicateTaskSnackBar), findsOneWidget);
  });
}
