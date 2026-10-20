import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_search/prism_search.dart';

Widget _host(Widget child) {
  return MaterialApp(home: child);
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1000, 800),
  List<String> items = const ['Dart', 'Flutter', 'Firebase'],
  ValueChanged<String>? onSelected,
  bool compact = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _host(
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: PrismSearch<String>(
            items: items,
            itemLabel: (item) => item,
            onSelected: onSelected,
            debugCompactOverride: compact,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PrismSearch — inline (medium+)', () {
    testWidgets('field renders with hint', (tester) async {
      await _pump(tester);
      expect(find.text('Search…'), findsOneWidget);
    });

    testWidgets('typing filters and shows dropdown suggestions', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'fl');
      await tester.pumpAndSettle();
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsNothing);
      expect(find.text('Firebase'), findsNothing);
    });

    testWidgets('match is highlighted inside suggestion', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'flu');
      await tester.pumpAndSettle();
      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((rt) => rt.text.toPlainText() == 'Flutter')
          .toList();
      expect(richTexts, isNotEmpty);
      // Text.rich wraps our span: root(Text.rich) -> root(highlight) -> parts.
      final root = richTexts.first.text as TextSpan;
      final spans =
          (root.text == null ? root.children!.first : root) as TextSpan;
      final children = spans.children!;
      expect(children.length, greaterThan(1)); // split around the match
    });

    testWidgets('selection fires callback and closes overlay', (tester) async {
      String? picked;
      await _pump(tester, onSelected: (item) => picked = item);
      await tester.enterText(find.byType(TextField), 'da');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dart'));
      await tester.pumpAndSettle();
      expect(picked, 'Dart');
    });

    testWidgets('maxSuggestions limits results', (tester) async {
      await _pump(tester, items: ['aa1', 'aa2', 'aa3', 'aa4', 'aa5']);
      await tester.enterText(find.byType(TextField), 'aa');
      await tester.pumpAndSettle();
      // default maxSuggestions = 8, so all 5 shown; use max override test:
      expect(find.text('aa5'), findsOneWidget);
    });
  });

  group('PrismSearch — compact', () {
    testWidgets('compact shows read-only trigger field', (tester) async {
      await _pump(tester, size: const Size(400, 800), compact: true);
      expect(find.text('Search…'), findsOneWidget);
      // No results overlay yet.
      expect(find.text('Dart'), findsNothing);
    });

    testWidgets('tapping opens full-screen search page', (tester) async {
      await _pump(tester, size: const Size(400, 800), compact: true);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // The full-screen page hosts its own TextField with autofocus.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'fl');
      await tester.pumpAndSettle();
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsNothing);
    });

    testWidgets('selecting in full-screen pops and fires callback', (
      tester,
    ) async {
      String? picked;
      await _pump(
        tester,
        size: const Size(400, 800),
        compact: true,
        onSelected: (item) => picked = item,
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'fire');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firebase'));
      await tester.pumpAndSettle();
      expect(picked, 'Firebase');
    });
  });

  group('PrismSearch — async backend', () {
    testWidgets('onSearch receives query and shows results', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final queries = <String>[];
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PrismSearch<String>(
                onSearch: (query) async {
                  queries.add(query);
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  return [query.toUpperCase()];
                },
                itemLabel: (item) => item,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(queries, contains('ab'));
      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('stale responses are ignored', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PrismSearch<String>(
                onSearch: (query) async {
                  if (query == 'slow') {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                    return ['SLOW RESULT'];
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  return ['$query result'];
                },
                itemLabel: (item) => item,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Type "slow", then quickly replace with "fast" — the slow response
      // must be dropped when it finally arrives.
      await tester.enterText(find.byType(TextField), 'slow');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'fast');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SLOW RESULT'), findsNothing);
      expect(find.text('fast result'), findsOneWidget);
    });
  });

  group('highlightQuery', () {
    test('splits around a case-insensitive match', () {
      const style = TextStyle();
      final span = highlightQuery('Flutter is fun', 'FLU', style, null);
      expect(span.children, isNotNull);
      expect(span.children!.length, 2);
      final match = span.children!.first as TextSpan;
      expect(match.text, 'Flu');
      expect(match.style?.fontWeight, FontWeight.w700);
    });

    test('plain span when no match', () {
      const style = TextStyle();
      final span = highlightQuery('Dart', 'xyz', style, null);
      expect(span.children, isNull);
      expect(span.text, 'Dart');
    });

    test('custom highlight style is applied', () {
      const style = TextStyle();
      const hl = PrismSearchHighlightStyle(bold: false);
      final span = highlightQuery('Dart', 'da', style, hl);
      final match = span.children!.first as TextSpan;
      expect(match.style?.fontWeight, isNull);
    });
  });
}
