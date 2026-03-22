import 'package:ai_todo_mobile/app/app.dart';
import 'package:ai_todo_mobile/app/app_strings.dart';
import 'package:ai_todo_mobile/app/logic/task_dedup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(const AiTodoApp());

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.quickInputTitle), findsOneWidget);
    expect(find.text(AppStrings.today), findsWidgets);
    expect(find.text(AppStrings.inbox), findsWidgets);
  });

  testWidgets('quick input prevents duplicate creation', (tester) async {
    await tester.pumpWidget(const AiTodoApp());

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    const newTaskTitle = '补一条组件冒烟测试';

    await tester.enterText(input, newTaskTitle);
    await tester.tap(find.text(AppStrings.captureToInbox));
    await tester.pumpAndSettle();

    expect(find.text(newTaskTitle), findsOneWidget);

    await tester.enterText(input, '  补一条组件冒烟测试 ');
    await tester.tap(find.text(AppStrings.captureToInbox));
    await tester.pumpAndSettle();

    expect(find.text(newTaskTitle), findsOneWidget);
    expect(find.text(AppStrings.duplicateTaskSnackBar), findsOneWidget);
  });
}
