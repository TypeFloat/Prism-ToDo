import 'package:ai_todo_mobile/app/app.dart';
import 'package:ai_todo_mobile/app/app_strings.dart';
import 'package:ai_todo_mobile/app/data/task_seed.dart';
import 'package:ai_todo_mobile/app/data/task_storage.dart';
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

  testWidgets('app smoke test renders macOS shell', (tester) async {
    await tester.pumpWidget(AiTodoApp(taskStorage: InMemoryTaskStorage()));
    await tester.pump();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.quickInputTitle), findsOneWidget);
    expect(find.text(AppStrings.today), findsWidgets);
    expect(find.text(AppStrings.inbox), findsWidgets);
  });

  testWidgets('quick input prevents duplicate creation', (tester) async {
    await tester.pumpWidget(AiTodoApp(taskStorage: InMemoryTaskStorage()));
    await tester.pump();

    final input = find.byType(TextField);
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
