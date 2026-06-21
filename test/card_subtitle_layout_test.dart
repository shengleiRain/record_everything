import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/bill/widgets/bill_card.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/life_item/widgets/life_item_card.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/project/providers/project_providers.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  group('card subtitle layout', () {
    testWidgets('life item date is not scaled by a long project name', (
      tester,
    ) async {
      final project = _longProject();
      final item = LifeItem(
        id: 1,
        title: '确认交付',
        amountType: 'none',
        dueTime: DateTime(2027, 12, 31),
        status: 'pending',
        projectDateManuallyEdited: false,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        projectId: project.id,
      );

      await _pumpNarrowCard(tester, project, LifeItemCard(item: item));

      final dateText = find.text('2027-12-31');
      expect(dateText, findsOneWidget);
      expect(
        find.ancestor(of: dateText, matching: find.byType(FittedBox)),
        findsNothing,
      );
    });

    testWidgets('life item card separates title project and date lines', (
      tester,
    ) async {
      final project = _longProject();
      final item = LifeItem(
        id: 2,
        title: '确认交付',
        amountType: 'none',
        dueTime: DateTime(2027, 12, 31),
        status: 'pending',
        projectDateManuallyEdited: false,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        projectId: project.id,
      );

      await _pumpNarrowCard(tester, project, LifeItemCard(item: item));

      final titleTop = tester.getTopLeft(find.text('确认交付')).dy;
      final projectTop = tester.getTopLeft(find.text(project.title)).dy;
      final dateTop = tester.getTopLeft(find.text('2027-12-31')).dy;

      expect(projectTop, greaterThan(titleTop));
      expect(dateTop, greaterThan(projectTop));
    });

    testWidgets('bill time is not scaled by a long project name', (
      tester,
    ) async {
      final project = _longProject();
      final bill = BillRecord(
        id: 1,
        title: '材料采购',
        amount: 12800,
        amountType: 'expense',
        billTime: DateTime(2026, 6, 1, 9),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        projectId: project.id,
      );

      await _pumpNarrowCard(tester, project, BillCard(bill: bill));

      final timeText = find.text('09:00');
      expect(timeText, findsOneWidget);
      expect(
        find.ancestor(of: timeText, matching: find.byType(FittedBox)),
        findsNothing,
      );
    });

    testWidgets('bill card keeps project and note-time on separate rows', (
      tester,
    ) async {
      final project = _longProject();
      const longNote = '这是一段很长很长的备注文本用于确认省略号只发生在备注区域';
      final bill = BillRecord(
        id: 2,
        title: '材料采购',
        note: longNote,
        amount: 12800,
        amountType: 'expense',
        billTime: DateTime(2026, 6, 1, 9),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        projectId: project.id,
      );

      await _pumpNarrowCard(tester, project, BillCard(bill: bill));

      final titleTop = tester.getTopLeft(find.text('材料采购')).dy;
      final projectTop = tester.getTopLeft(find.text(project.title)).dy;
      final noteTop = tester.getTopLeft(find.text(longNote)).dy;
      final timeTop = tester.getTopLeft(find.text('09:00')).dy;

      expect(projectTop, greaterThan(titleTop));
      expect(noteTop, greaterThan(projectTop));
      expect(timeTop, moreOrLessEquals(noteTop, epsilon: 1));
      expect(
        find.ancestor(of: find.text('09:00'), matching: find.byType(FittedBox)),
        findsNothing,
      );
    });
  });
}

Project _longProject() {
  return Project(
    id: 1,
    title: '特别特别长的项目名称会挤占副标题宽度',
    projectStatus: 'active',
    startDate: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

Future<void> _pumpNarrowCard(
  WidgetTester tester,
  Project project,
  Widget child,
) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectByIdProvider(
          project.id,
        ).overrideWith((ref) => Stream.value(project)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
