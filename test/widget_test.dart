import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyouka_notes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('creates and locally persists a note', (tester) async {
    await tester.pumpWidget(const HyoukaNotesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-note-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('note-title-input')),
      'Groceries',
    );
    await tester.enterText(
      find.byKey(const Key('note-body-input')),
      'Milk and bread',
    );
    await tester.tap(find.byKey(const Key('save-note-button')));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('hyouka_notes_v1'), isNotNull);
    expect(
      preferences.getString('hyouka_notes_v1'),
      contains('Milk and bread'),
    );
  });

  testWidgets('search shows an empty state when there are no matches',
      (tester) async {
    await tester.pumpWidget(const HyoukaNotesApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('notes-search-input')),
      'not-found-query',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching notes'), findsOneWidget);
  });
}
